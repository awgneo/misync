import 'dart:async';
import 'package:flutter/material.dart';
import '../module.dart';
import '../device/module.dart';
import '../device/connection.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/proto/constants.dart';
import '../platform/module.dart';
import 'blobs/calendars.dart';
import 'screen.dart';

class CalendarModule extends TabModule {
  @override
  String get name => 'calendar';

  @override
  IconData get icon => Icons.calendar_today;

  @override
  Widget get screen => const CalendarScreen();

  static final CalendarModule _instance = CalendarModule._();
  static CalendarModule get instance => _instance;
  CalendarModule._();

  @override
  Future<void> start() async {
    DeviceModule.instance.register(this);
  }

  @override
  Future<void> sync() async {
    await _syncCalendar();
  }

  Future<void> _syncCalendar() async {
    if (!DeviceConnection.instance.connected.value) {
      logger.info('skip sync (not connected)');
      return;
    }

    final enabledIds = CalendarsBlob.enabledIds;
    if (enabledIds.isEmpty) {
      logger.info('clearing watch calendar events');
      await DeviceConnection.instance.send(
        type: CmdType.calendar,
        subtype: CalendarSubtype.setCalendar,
        builder: (cmd) =>
            cmd.calendar = (pb.Calendar()
              ..calendarSync = (pb.CalendarSync()..disabled = true)),
      );
      return;
    }

    logger.info('syncing ${enabledIds.length} calendars');
    final List<dynamic>? phoneEvents = await PlatformModule.instance
        .invokeMethod('calendar.getUpcomingEvents', {
          'calendarIds': enabledIds,
        });

    final List<pb.CalendarEvent> events = [];
    if (phoneEvents != null) {
      for (final phoneEvent in phoneEvents) {
        final map = Map<String, dynamic>.from(phoneEvent as Map);
        final startSeconds = (map['start'] as int) ~/ 1000;
        final endSeconds = (map['end'] as int) ~/ 1000;

        events.add(
          pb.CalendarEvent()
            ..title = map['title'] as String? ?? ''
            ..description = map['description'] as String? ?? ''
            ..location = map['location'] as String? ?? ''
            ..start = startSeconds
            ..end = endSeconds
            ..allDay = map['allDay'] as bool? ?? false
            ..notifyMinutesBefore = map['notifyMinutesBefore'] as int? ?? 0,
        );
      }
    }

    logger.info('syncing ${events.length} events');
    await DeviceConnection.instance.send(
      type: CmdType.calendar,
      subtype: CalendarSubtype.setCalendar,
      builder: (cmd) =>
          cmd.calendar = (pb.Calendar()
            ..calendarSync = (pb.CalendarSync()
              ..event.addAll(events)
              ..disabled = false)),
    );
  }

  Future<List<PhoneCalendar>> getCalendars() async {
    final List<dynamic>? raw = await PlatformModule.instance.invokeMethod(
      'calendar.getCalendars',
    );
    if (raw == null) return [];
    return raw
        .map(
          (item) =>
              PhoneCalendar.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> setCalendarEnabled(String id, bool enabled) async {
    CalendarsBlob.instance.toggle(id, enabled);
    await _syncCalendar();
  }
}
