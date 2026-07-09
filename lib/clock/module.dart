import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../module.dart';
import '../device/module.dart';
import '../debug/logger.dart';
import '../device/connection.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/proto/constants.dart';
import '../platform/module.dart';
import 'blobs/alarms.dart';
import 'screen.dart';

class ClockModule implements TabModule {
  @override
  String get name => 'clock';

  @override
  IconData get icon => Icons.alarm;

  @override
  Widget get screen => const ClockScreen();
  static final ClockModule _instance = ClockModule._();
  static ClockModule get instance => _instance;
  ClockModule._();

  // Reactive state holding the next system alarm details (hour, minute)
  static final nextSystemAlarm = ValueNotifier<Map<String, int>?>(null);

  @override
  Future<void> start() async {
    DeviceModule.instance.register(this);
    PlatformModule.instance.register(_handleMethodCall);
  }

  @override
  Future<void> sync() async {
    if (!DeviceConnection.connected.value) return;
    await _syncTime();
    await _syncAlarms();
  }

  Future<void> _syncTime() async {
    final now = DateTime.now();
    Logger.info(
      'clock',
      'syncing time, date, and timezone offset: ${now.timeZoneName}',
    );

    await DeviceConnection.send(
      type: CmdType.system,
      subtype: SystemSubtype.clockSync,
      builder: (cmd) => cmd.system = (pb.System()
        ..clock = (pb.Clock()
          ..date = (pb.Date()
            ..year = now.year
            ..month = now.month
            ..day = now.day)
          ..time = (pb.Time()
            ..hour = now.hour
            ..minute = now.minute
            ..second = now.second)
          ..timezone = (pb.TimeZone()
            ..zoneOffset = now.timeZoneOffset.inMinutes ~/ 15
            ..dstOffset = 0
            ..name = now.timeZoneName))),
    );
  }

  Future<void> _syncAlarms() async {
    Logger.info(
      'clock',
      'syncing alarms: system alarm push + custom alarms pull',
    );

    // 1. Fetch next system alarm from phone
    Map<String, int>? sysAlarm;
    try {
      final res = await PlatformModule.instance.invokeMethod('getNextAlarm');
      if (res != null) {
        final data = Map<String, dynamic>.from(res);
        final hour = data['hour'] as int;
        final minute = data['minute'] as int;
        sysAlarm = {'hour': hour, 'minute': minute};
        nextSystemAlarm.value = sysAlarm;
      } else {
        nextSystemAlarm.value = null;
      }
    } catch (e) {
      Logger.error('clock', 'error fetching next system alarm before sync: $e');
    }

    // 2. Query current watch alarms (CMD_ALARMS_GET)
    Logger.info('clock', 'querying current watch alarms (CMD_ALARMS_GET)');
    final response = await DeviceConnection.send(
      type: CmdType.schedule,
      subtype: ScheduleSubtype.getAlarms,
      expectResponse: true,
    );
    if (response == null || !response.schedule.hasAlarms()) {
      Logger.error('clock', 'failed to pull alarms from watch');
      return;
    }

    final alarms = response.schedule.alarms;
    final Set<int> existingWatchAlarmIds = alarms.alarm
        .map((a) => a.id)
        .toSet();

    // 3. System Alarm (Slot 1 / Watch ID 0) Push
    final existsOnWatch = existingWatchAlarmIds.contains(0);
    final desiredSysAlarm = pb.AlarmDetails()
      ..enabled = sysAlarm != null
      ..time = (pb.HourMinute()
        ..hour = sysAlarm?['hour'] ?? 0
        ..minute = sysAlarm?['minute'] ?? 0)
      ..smart =
          2 // ALARM_NORMAL
      ..repeatMode = 0;

    if (sysAlarm == null) {
      if (existsOnWatch) {
        final wSysAlarm = alarms.alarm.cast<pb.Alarm?>().firstWhere(
          (a) => a?.id == 0,
          orElse: () => null,
        );
        if (wSysAlarm?.alarmDetails.enabled == true) {
          Logger.info(
            'clock',
            'disabling watch system alarm ID=1 (Watch ID 0)',
          );
          await DeviceConnection.send(
            type: CmdType.schedule,
            subtype: ScheduleSubtype.editAlarm,
            expectResponse: true,
            builder: (cmd) =>
                cmd.schedule = (pb.Schedule()
                  ..editAlarm = (pb.Alarm()
                    ..id = 0
                    ..alarmDetails = desiredSysAlarm)),
          );
        }
      } else {
        Logger.info(
          'clock',
          'creating disabled watch system alarm ID=1 (Watch ID 0)',
        );
        await DeviceConnection.send(
          type: CmdType.schedule,
          subtype: ScheduleSubtype.createAlarm,
          expectResponse: true,
          builder: (cmd) =>
              cmd.schedule = (pb.Schedule()..createAlarm = desiredSysAlarm),
        );
      }
    } else {
      if (existsOnWatch) {
        final wSysAlarm = alarms.alarm.cast<pb.Alarm?>().firstWhere(
          (a) => a?.id == 0,
          orElse: () => null,
        );
        final wEnabled = wSysAlarm?.alarmDetails.enabled ?? false;
        final wHour = wSysAlarm?.alarmDetails.time.hour ?? 0;
        final wMinute = wSysAlarm?.alarmDetails.time.minute ?? 0;

        if (wEnabled != true ||
            wHour != sysAlarm['hour'] ||
            wMinute != sysAlarm['minute']) {
          Logger.info(
            'clock',
            'editing watch system alarm ID=1 (Watch ID 0) to ${sysAlarm['hour']}:${sysAlarm['minute']}',
          );
          await DeviceConnection.send(
            type: CmdType.schedule,
            subtype: ScheduleSubtype.editAlarm,
            expectResponse: true,
            builder: (cmd) =>
                cmd.schedule = (pb.Schedule()
                  ..editAlarm = (pb.Alarm()
                    ..id = 0
                    ..alarmDetails = desiredSysAlarm)),
          );
        }
      } else {
        Logger.info(
          'clock',
          'creating watch system alarm ID=1 (Watch ID 0) at ${sysAlarm['hour']}:${sysAlarm['minute']}',
        );
        await DeviceConnection.send(
          type: CmdType.schedule,
          subtype: ScheduleSubtype.createAlarm,
          expectResponse: true,
          builder: (cmd) =>
              cmd.schedule = (pb.Schedule()..createAlarm = desiredSysAlarm),
        );
      }
    }

    // 4. Custom Alarms (Slots 2-10 / Watch IDs 1-9) Pull
    final watchAlarms = <Alarm>[];
    for (var alarm in alarms.alarm) {
      if (alarm.id >= 1) {
        final localId = alarm.id + 1;
        watchAlarms.add(
          Alarm(
            id: localId,
            hour: alarm.alarmDetails.time.hour,
            minute: alarm.alarmDetails.time.minute,
            enabled: alarm.alarmDetails.enabled,
          ),
        );
      }
    }

    // Sort contiguously by localId
    watchAlarms.sort((a, b) => a.id.compareTo(b.id));

    // Overwrite phone alarms with the custom alarms from watch
    await AlarmsBlob.instance.update(watchAlarms);
    Logger.info(
      'clock',
      'Sync: Overwrote phone alarms list with watch custom alarms',
    );
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onNextAlarmChanged') {
      if (call.arguments != null) {
        final data = Map<String, dynamic>.from(call.arguments);
        final hour = data['hour'] as int;
        final minute = data['minute'] as int;
        nextSystemAlarm.value = {'hour': hour, 'minute': minute};
        Logger.info(
          'clock',
          'phone next alarm changed to $hour:$minute, mirroring to watch',
        );
      } else {
        nextSystemAlarm.value = null;
        Logger.info(
          'clock',
          'phone next alarm cleared, disabling watch slot 1',
        );
      }
      if (!DeviceConnection.connected.value) return;
      await _syncAlarms();
    }
  }

  Future<void> createAlarm(int hour, int minute) async {
    if (!DeviceConnection.connected.value) return;

    final list = AlarmsBlob.list;
    final localId = list.length + 2; // Slot 2-10

    final details = pb.AlarmDetails()
      ..enabled = true
      ..time = (pb.HourMinute()
        ..hour = hour
        ..minute = minute)
      ..smart = 2
      ..repeatMode = 0;

    final res = await DeviceConnection.send(
      type: CmdType.schedule,
      subtype: ScheduleSubtype.createAlarm,
      expectResponse: true,
      builder: (cmd) => cmd.schedule = (pb.Schedule()..createAlarm = details),
    );

    if (res != null) {
      AlarmsBlob.instance[localId] = Alarm(
        id: localId,
        hour: hour,
        minute: minute,
        enabled: true,
      );
    }
  }

  Future<void> toggleAlarm(int localId, bool enabled) async {
    if (!DeviceConnection.connected.value) return;

    final alarm = AlarmsBlob.instance[localId];
    if (alarm == null) return;
    final watchId = localId - 1;

    final details = pb.AlarmDetails()
      ..enabled = enabled
      ..time = (pb.HourMinute()
        ..hour = alarm.hour
        ..minute = alarm.minute)
      ..smart = 2
      ..repeatMode = 0;

    final res = await DeviceConnection.send(
      type: CmdType.schedule,
      subtype: ScheduleSubtype.editAlarm,
      expectResponse: true,
      builder: (cmd) => cmd.schedule = (pb.Schedule()
        ..editAlarm = (pb.Alarm()
          ..id = watchId
          ..alarmDetails = details)),
    );

    if (res != null) {
      AlarmsBlob.instance[localId] = alarm.copyWith(enabled: enabled);
    }
  }

  Future<void> deleteAlarm(int localId) async {
    if (!DeviceConnection.connected.value) return;

    final watchId = localId - 1;
    final res = await DeviceConnection.send(
      type: CmdType.schedule,
      subtype: ScheduleSubtype.deleteAlarm,
      expectResponse: true,
      builder: (cmd) =>
          cmd.schedule = (pb.Schedule()
            ..deleteAlarm = (pb.AlarmDelete()..id.add(watchId))),
    );

    if (res != null) {
      final list = AlarmsBlob.list;
      final updated = List<Alarm>.from(list)
        ..removeWhere((item) => item.id == localId);

      // Re-index remaining custom alarms contiguously
      for (int i = 0; i < updated.length; i++) {
        updated[i] = updated[i].copyWith(id: i + 2);
      }
      await AlarmsBlob.instance.update(updated);
    }
  }
}
