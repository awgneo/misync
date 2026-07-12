import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../module.dart';
import '../device/module.dart';
import '../device/connection.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/proto/constants.dart';
import '../platform/module.dart';
import 'blobs/alarms.dart';
import 'blobs/clocks.dart';
import 'screen.dart';

class ClockModule extends TabModule {
  @override
  String get name => 'clock';

  @override
  IconData get icon => Icons.alarm;

  @override
  Widget get screen => const ClockScreen();
  static final ClockModule _instance = ClockModule._();
  static ClockModule get instance => _instance;
  ClockModule._();

  final phoneNextAlarm = ValueNotifier<Alarm?>(null);

  @override
  Future<void> start() async {
    _startNextAlarm();
    DeviceModule.instance.register(this);
    PlatformModule.instance.register(_receivePhoneMethod);
  }

  Future<dynamic> _receivePhoneMethod(MethodCall call) async {
    if (call.method == 'nextAlarmChanged') {
      _handlePhoneNextAlarmChanged(call);
    }
  }

  void _startNextAlarm() async {
    final arguments = await PlatformModule.instance.invokeMethod(
      'clock.getNextAlarm',
    );

    _setNextAlarm(arguments);
  }

  void _setNextAlarm(dynamic arguments) {
    if (arguments != null) {
      final data = Map<String, dynamic>.from(arguments);
      final alarm = Alarm.fromMap(data);
      phoneNextAlarm.value = Alarm.fromMap(data);
      logger.info('phone next alarm updated to ${alarm.hour}:${alarm.minute}');
    } else {
      phoneNextAlarm.value = null;
      logger.info('phone next alarm cleared');
    }
  }

  void _handlePhoneNextAlarmChanged(MethodCall call) async {
    _setNextAlarm(call.arguments);
    await _syncAlarms();
  }

  @override
  Future<void> sync() async {
    if (!DeviceConnection.instance.connected.value) return;
    await _syncTime();
    await _syncAlarms();
    await _syncClocks();
  }

  Future<void> _syncTime() async {
    if (!DeviceConnection.instance.connected.value) return;

    final now = DateTime.now();
    logger.info('syncing time, date, and timezone offset: ${now.timeZoneName}');

    await DeviceConnection.instance.send(
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
    if (!DeviceConnection.instance.connected.value) return;

    // Get the current phone alarm, if any
    final phoneFirstAlarm = phoneNextAlarm.value;
    // Get alarms from the watch
    final response = await DeviceConnection.instance.send(
      type: CmdType.schedule,
      subtype: ScheduleSubtype.getAlarms,
      expectResponse: true,
    );

    if (response == null || !response.schedule.hasAlarms()) {
      logger.error('failed to pull alarms from watch');
      return;
    }

    final watchAlarms = Map<int, pb.Alarm>.fromEntries(
      response.schedule.alarms.alarm.map((a) => MapEntry(a.id, a)),
    );

    final updatedWatchFirstAlarm = pb.AlarmDetails()
      ..enabled = phoneFirstAlarm != null
      ..time = (pb.HourMinute()
        ..hour = phoneFirstAlarm?.hour ?? 0
        ..minute = phoneFirstAlarm?.minute ?? 0)
      ..smart = 2
      ..repeatMode = 0;

    final watchFirstAlarm = watchAlarms[0];

    // Sync the first alarm (phone next alarm)
    if (phoneFirstAlarm == null) {
      if (watchFirstAlarm != null) {
        // No phone next alarm, yes watch first alarm
        await DeviceConnection.instance.send(
          type: CmdType.schedule,
          subtype: ScheduleSubtype.editAlarm,
          expectResponse: true,
          builder: (cmd) =>
              cmd.schedule = (pb.Schedule()
                ..editAlarm = (pb.Alarm()
                  ..id = 0
                  ..alarmDetails = updatedWatchFirstAlarm)),
        );
      } else {
        // No phone next alarm, no watch first alarm
        await DeviceConnection.instance.send(
          type: CmdType.schedule,
          subtype: ScheduleSubtype.createAlarm,
          expectResponse: true,
          builder: (cmd) =>
              cmd.schedule = (pb.Schedule()
                ..createAlarm = updatedWatchFirstAlarm),
        );
      }
    } else {
      if (watchFirstAlarm != null) {
        // Yes phone next alarm, yes watch first alarm
        await DeviceConnection.instance.send(
          type: CmdType.schedule,
          subtype: ScheduleSubtype.editAlarm,
          expectResponse: true,
          builder: (cmd) =>
              cmd.schedule = (pb.Schedule()
                ..editAlarm = (pb.Alarm()
                  ..id = 0
                  ..alarmDetails = updatedWatchFirstAlarm)),
        );
      } else {
        // Yes phone next alarm, no watch first alarm
        await DeviceConnection.instance.send(
          type: CmdType.schedule,
          subtype: ScheduleSubtype.createAlarm,
          expectResponse: true,
          builder: (cmd) =>
              cmd.schedule = (pb.Schedule()
                ..createAlarm = updatedWatchFirstAlarm),
        );
      }
    }

    // Sync the custom watch alarms with the blob
    final updatedWatchAlarms = <WatchAlarm>[];
    for (var entry in watchAlarms.entries) {
      final id = entry.key;
      if (id < 1) continue;

      final alarm = entry.value;
      updatedWatchAlarms.add(
        WatchAlarm(
          id: id,
          hour: alarm.alarmDetails.time.hour,
          minute: alarm.alarmDetails.time.minute,
          enabled: alarm.alarmDetails.enabled,
          repeatMode: alarm.alarmDetails.repeatMode,
          repeatFlags: alarm.alarmDetails.repeatFlags,
          smart: alarm.alarmDetails.smart,
        ),
      );
    }

    // Sort the updated watch alarms by id
    updatedWatchAlarms.sort((a, b) => a.id.compareTo(b.id));
    // Overwrite phone alarms with the custom alarms from watch
    await AlarmsBlob.instance.update(updatedWatchAlarms);
    logger.info('alarms sync complete');
  }

  Future<void> _syncClocks() async {
    if (!DeviceConnection.instance.connected.value) return;

    logger.info('querying world clocks from watch');
    final response = await DeviceConnection.instance.send(
      type: CmdType.schedule,
      subtype: ScheduleSubtype.getWorldClocks,
      expectResponse: true,
    );

    if (response == null || !response.schedule.hasWorldClocks()) {
      logger.error('failed to pull world clocks from watch');
      return;
    }

    final cityIds = response.schedule.worldClocks.worldClock;
    await ClocksBlob.instance.update(List<String>.from(cityIds));
    logger.info('world clocks sync complete: $cityIds');
  }

  Future<void> createAlarm(
    int hour,
    int minute, {
    int repeatMode = 0,
    int repeatFlags = 0,
    int smart = 2,
  }) async {
    if (!DeviceConnection.instance.connected.value) return;

    final alarms = AlarmsBlob.list;
    final id = alarms.length + 1;
    final details = pb.AlarmDetails()
      ..enabled = true
      ..time = (pb.HourMinute()
        ..hour = hour
        ..minute = minute)
      ..smart = smart
      ..repeatMode = repeatMode
      ..repeatFlags = repeatFlags;

    final result = await DeviceConnection.instance.send(
      type: CmdType.schedule,
      subtype: ScheduleSubtype.createAlarm,
      expectResponse: true,
      builder: (cmd) => cmd.schedule = (pb.Schedule()..createAlarm = details),
    );

    if (result != null) {
      AlarmsBlob.instance[id] = WatchAlarm(
        id: id,
        hour: hour,
        minute: minute,
        enabled: true,
        repeatMode: repeatMode,
        repeatFlags: repeatFlags,
        smart: smart,
      );
    }
  }

  Future<void> editAlarm(
    int id,
    int hour,
    int minute, {
    required bool enabled,
    int repeatMode = 0,
    int repeatFlags = 0,
    int smart = 2,
  }) async {
    if (!DeviceConnection.instance.connected.value) return;

    final details = pb.AlarmDetails()
      ..enabled = enabled
      ..time = (pb.HourMinute()
        ..hour = hour
        ..minute = minute)
      ..smart = smart
      ..repeatMode = repeatMode
      ..repeatFlags = repeatFlags;

    final result = await DeviceConnection.instance.send(
      type: CmdType.schedule,
      subtype: ScheduleSubtype.editAlarm,
      expectResponse: true,
      builder: (cmd) => cmd.schedule = (pb.Schedule()
        ..editAlarm = (pb.Alarm()
          ..id = id
          ..alarmDetails = details)),
    );

    if (result != null) {
      AlarmsBlob.instance[id] = WatchAlarm(
        id: id,
        hour: hour,
        minute: minute,
        enabled: enabled,
        repeatMode: repeatMode,
        repeatFlags: repeatFlags,
        smart: smart,
      );
    }
  }

  Future<void> setAlarmEnabled(int id, bool enabled) async {
    final alarm = AlarmsBlob.instance[id];
    if (alarm == null) return;
    await editAlarm(
      id,
      alarm.hour,
      alarm.minute,
      enabled: enabled,
      repeatMode: alarm.repeatMode,
      repeatFlags: alarm.repeatFlags,
      smart: alarm.smart,
    );
  }

  Future<void> deleteAlarm(int id) async {
    if (!DeviceConnection.instance.connected.value) return;

    final result = await DeviceConnection.instance.send(
      type: CmdType.schedule,
      subtype: ScheduleSubtype.deleteAlarm,
      expectResponse: true,
      builder: (cmd) =>
          cmd.schedule = (pb.Schedule()
            ..deleteAlarm = (pb.AlarmDelete()..id.add(id))),
    );

    if (result != null) {
      final alarms = AlarmsBlob.list;
      final updatedAlarms = List<WatchAlarm>.from(alarms)
        ..removeWhere((item) => item.id == id);

      // Re-index remaining custom alarms contiguously
      for (int i = 0; i < updatedAlarms.length; i++) {
        updatedAlarms[i] = updatedAlarms[i].copyWith(id: i + 1);
      }

      // Update the blob with the updated alarms
      await AlarmsBlob.instance.update(updatedAlarms);
    }
  }

  Future<void> addClock(String cityId) async {
    if (!DeviceConnection.instance.connected.value) return;

    final list = List<String>.from(ClocksBlob.list);
    if (list.contains(cityId)) return;
    list.add(cityId);

    logger.info('syncing world clocks list to watch: $list');
    final pClocks = pb.WorldClocks()..worldClock.addAll(list);

    final result = await DeviceConnection.instance.send(
      type: CmdType.schedule,
      subtype: ScheduleSubtype.setWorldClocks,
      expectResponse: true,
      builder: (cmd) => cmd.schedule = (pb.Schedule()..worldClocks = pClocks),
    );

    if (result != null) {
      await ClocksBlob.instance.update(list);
    }
  }

  Future<void> deleteClock(String cityId) async {
    if (!DeviceConnection.instance.connected.value) return;

    logger.info('deleting world clock from watch: $cityId');
    final pClocks = pb.WorldClocks()..worldClock.add(cityId);

    final result = await DeviceConnection.instance.send(
      type: CmdType.schedule,
      subtype: ScheduleSubtype.deleteWorldClock,
      expectResponse: true,
      builder: (cmd) => cmd.schedule = (pb.Schedule()..worldClocks = pClocks),
    );

    if (result != null) {
      final list = List<String>.from(ClocksBlob.list)..remove(cityId);
      await ClocksBlob.instance.update(list);
    }
  }
}
