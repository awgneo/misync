import '../../storage/blob.dart';

class Alarm {
  final int hour;
  final int minute;

  const Alarm({
    required this.hour,
    required this.minute,
  });

  String get timeString =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

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

  const WatchAlarm({
    required this.id,
    required super.hour,
    required super.minute,
    required this.enabled,
  });

  WatchAlarm copyWith({
    int? id,
    int? hour,
    int? minute,
    bool? enabled,
  }) {
    return WatchAlarm(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
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
    }).toList();
  }
}
