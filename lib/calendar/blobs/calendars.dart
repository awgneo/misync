import '../../storage/blob.dart';

class PhoneCalendar {
  final String id;
  final String name;
  final String account;
  final int color;

  const PhoneCalendar({
    required this.id,
    required this.name,
    required this.account,
    required this.color,
  });

  factory PhoneCalendar.fromMap(Map<String, dynamic> map) {
    return PhoneCalendar(
      id: map['id'] as String,
      name: map['name'] as String,
      account: map['account'] as String,
      color: map['color'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'account': account, 'color': color};
  }
}

class CalendarsBlob extends Blob<List<String>> {
  static final CalendarsBlob _instance = CalendarsBlob._();
  static CalendarsBlob get instance => _instance;

  CalendarsBlob._()
    : super(module: 'calendar', name: 'calendars', defaultValue: const []);

  static List<String> get enabledIds => _instance.value;

  void toggle(String id, bool enabled) {
    final updated = List<String>.from(value);
    if (enabled) {
      if (!updated.contains(id)) {
        updated.add(id);
      }
    } else {
      updated.remove(id);
    }
    update(updated);
  }

  bool getEnabled(String calendarId) {
    return value.contains(calendarId);
  }

  @override
  List<String> parse(dynamic json) {
    final raw = json as List<dynamic>?;
    if (raw == null) return [];
    return raw.map((item) => item.toString()).toList();
  }

  @override
  dynamic serialize(List<String> value) {
    return value;
  }
}
