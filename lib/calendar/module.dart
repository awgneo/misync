import 'dart:async';
import 'package:flutter/material.dart';
import 'package:misync/screen.dart';
import '../device/module.dart';
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
  late final Screen screen = CalendarScreen(this);

  static final CalendarModule _module = CalendarModule._();
  static CalendarModule get module => _module;
  CalendarModule._();

  @override
  Future<void> start() async {
    DeviceModule.module.register(this);
  }

  @override
  Future<void> sync() async {
    await _syncCalendar();
  }

  String _sanitizeDescription(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    String text = raw;

    // Truncate Google Calendar / Meet auto-generated footer block
    final delimiterIdx = text.indexOf('-::~:~::');
    if (delimiterIdx != -1) {
      text = text.substring(0, delimiterIdx);
    }

    // Strip HTML tags if any
    text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');

    // Normalize excessive newlines and whitespace
    text = text.replaceAll(RegExp(r'[\r\n]{2,}'), '\n').trim();
    return text;
  }

  Future<void> _syncCalendar() async {
    if (!DeviceModule.module.connection.connected.value) {
      logger.info('skip sync (not connected)');
      return;
    }

    final enabledIds = CalendarsBlob.enabledIds;
    if (enabledIds.isEmpty) {
      logger.info('clearing watch calendar events');
      await DeviceModule.module.connection.send(
        type: CmdType.calendar,
        subtype: CalendarSubtype.setCalendar,
        builder: (cmd) =>
            cmd.calendar = (pb.Calendar()
              ..calendarSync = (pb.CalendarSync()..disabled = true)),
      );
      return;
    }

    List<dynamic>? phoneEvents;
    try {
      phoneEvents = await PlatformModule.module.invokeMethod(
        'calendar.getUpcomingEvents',
        {'calendarIds': enabledIds},
      );
    } catch (e) {
      logger.error('failed to get phone calendar upcoming events: $e');
      return;
    }

    final List<pb.CalendarEvent> events = [];
    if (phoneEvents != null) {
      for (final phoneEvent in phoneEvents) {
        final map = Map<String, dynamic>.from(phoneEvent as Map);
        final startSeconds = (map['start'] as int) ~/ 1000;
        final endSeconds = (map['end'] as int) ~/ 1000;

        events.add(
          pb.CalendarEvent()
            ..title = map['title'] as String? ?? ''
            ..description = _sanitizeDescription(map['description'] as String?)
            ..location = map['location'] as String? ?? ''
            ..start = startSeconds
            ..end = endSeconds
            ..allDay = map['allDay'] as bool? ?? false
            ..notifyMinutesBefore = map['notifyMinutesBefore'] as int? ?? 0,
        );
      }
    }

    logger.info('syncing ${events.length} events');
    await DeviceModule.module.connection.send(
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
    List<dynamic>? raw;
    try {
      raw = await PlatformModule.module.invokeMethod(
        'calendar.getCalendars',
      );
    } catch (e) {
      logger.error('failed to fetch calendar list from phone: $e');
    }
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
