import '../../storage/blob.dart';

class Alarm {
  final int id;      // Slot ID (e.g. 2 to 10)
  final int hour;
  final int minute;
  final bool enabled;

  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.enabled,
  });

  Alarm copyWith({
    int? id,
    int? hour,
    int? minute,
    bool? enabled,
  }) {
    return Alarm(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
    );
  }
}

class AlarmsBlob extends Blob<List<Alarm>> {
  static final AlarmsBlob _instance = AlarmsBlob._();
  static AlarmsBlob get instance => _instance;

  AlarmsBlob._()
      : super(
          module: 'clock',
          name: 'alarms',
          defaultValue: const [
            Alarm(id: 2, hour: 8, minute: 30, enabled: false),
          ],
        );

  static List<Alarm> get list => _instance.value;

  Alarm? operator [](int slotId) {
    try {
      return value.firstWhere((a) => a.id == slotId);
    } catch (_) {
      return null;
    }
  }

  void operator []=(int slotId, Alarm val) {
    final updated = List<Alarm>.from(value);
    final index = updated.indexWhere((a) => a.id == slotId);
    if (index != -1) {
      updated[index] = val;
    } else {
      updated.add(val);
    }
    update(updated);
  }

  @override
  List<Alarm> parse(dynamic json) {
    final raw = json as List<dynamic>?;
    if (raw == null) return [];
    return raw.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return Alarm(
        id: map['id'] as int,
        hour: map['hour'] as int,
        minute: map['minute'] as int,
        enabled: map['enabled'] as bool,
      );
    }).toList();
  }

  @override
  dynamic serialize(List<Alarm> value) {
    return value.map((a) => {
      'id': a.id,
      'hour': a.hour,
      'minute': a.minute,
      'enabled': a.enabled,
    }).toList();
  }
}
