import '../../storage/blob.dart';

class Alarm {
  final int hour;
  final int minute;

  const Alarm({
    required this.hour,
    required this.minute,
  });

  String get timeString {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMin = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMin $period';
  }

  factory Alarm.fromMap(Map<String, dynamic> map) {
    return Alarm(
      hour: map['hour'] as int,
      minute: map['minute'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hour': hour,
      'minute': minute,
    };
  }
}

class WatchAlarm extends Alarm {
  final int id;      // Watch Alarm ID (e.g. 1 to 9)
  final bool enabled;
  final int repeatMode;
  final int repeatFlags;
  final int smart;   // 1: Smart Wake, 2: Normal

  const WatchAlarm({
    required this.id,
    required super.hour,
    required super.minute,
    required this.enabled,
    this.repeatMode = 0,
    this.repeatFlags = 0,
    this.smart = 2,
  });

  String get repeatString {
    if (repeatMode == 0) return 'Once';
    if (repeatMode == 1) return 'Daily';
    if (repeatMode == 5) {
      if (repeatFlags == 31) return 'Weekdays';
      if (repeatFlags == 96) return 'Weekends';
      if (repeatFlags == 127) return 'Daily';
      final days = <String>[];
      if (repeatFlags & 1 != 0) days.add('Mon');
      if (repeatFlags & 2 != 0) days.add('Tue');
      if (repeatFlags & 4 != 0) days.add('Wed');
      if (repeatFlags & 8 != 0) days.add('Thu');
      if (repeatFlags & 16 != 0) days.add('Fri');
      if (repeatFlags & 32 != 0) days.add('Sat');
      if (repeatFlags & 64 != 0) days.add('Sun');
      return days.isEmpty ? 'Once' : days.join(', ');
    }
    return 'Once';
  }

  WatchAlarm copyWith({
    int? id,
    int? hour,
    int? minute,
    bool? enabled,
    int? repeatMode,
    int? repeatFlags,
    int? smart,
  }) {
    return WatchAlarm(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
      repeatMode: repeatMode ?? this.repeatMode,
      repeatFlags: repeatFlags ?? this.repeatFlags,
      smart: smart ?? this.smart,
    );
  }
}

class AlarmsBlob extends Blob<List<WatchAlarm>> {
  static final AlarmsBlob _instance = AlarmsBlob._();
  static AlarmsBlob get instance => _instance;

  AlarmsBlob._()
      : super(
          module: 'clock',
          name: 'alarms',
          defaultValue: const [
            WatchAlarm(id: 1, hour: 8, minute: 30, enabled: false),
          ],
        );

  static List<WatchAlarm> get list => _instance.value;

  WatchAlarm? operator [](int slotId) {
    try {
      return value.firstWhere((a) => a.id == slotId);
    } catch (_) {
      return null;
    }
  }

  void operator []=(int slotId, WatchAlarm val) {
    final updated = List<WatchAlarm>.from(value);
    final index = updated.indexWhere((a) => a.id == slotId);
    if (index != -1) {
      updated[index] = val;
    } else {
      updated.add(val);
    }
    update(updated);
  }

  @override
  List<WatchAlarm> parse(dynamic json) {
    final raw = json as List<dynamic>?;
    if (raw == null) return [];
    return raw.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return WatchAlarm(
        id: map['id'] as int,
        hour: map['hour'] as int,
        minute: map['minute'] as int,
        enabled: map['enabled'] as bool,
        repeatMode: map['repeatMode'] as int? ?? 0,
        repeatFlags: map['repeatFlags'] as int? ?? 0,
        smart: map['smart'] as int? ?? 2,
      );
    }).toList();
  }

  @override
  dynamic serialize(List<WatchAlarm> value) {
    return value.map((a) => {
      'id': a.id,
      'hour': a.hour,
      'minute': a.minute,
      'enabled': a.enabled,
      'repeatMode': a.repeatMode,
      'repeatFlags': a.repeatFlags,
      'smart': a.smart,
    }).toList();
  }
}
