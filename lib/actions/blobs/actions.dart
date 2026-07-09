import '../../storage/blob.dart';

class Action {
  final String name;
  final String intent;
  final String package;

  Action({
    required this.name,
    required this.intent,
    required this.package,
  });

  factory Action.fromJson(Map<String, dynamic> json) {
    return Action(
      name: json['name'] as String? ?? '',
      intent: json['intent'] as String? ?? '',
      package: json['package'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'intent': intent,
    'package': package,
  };
}

class ActionsBlob extends Blob<Map<String, Action>> {
  static final ActionsBlob _instance = ActionsBlob._();
  static ActionsBlob get instance => _instance;

  ActionsBlob._()
      : super(
          module: 'actions',
          name: 'settings',
          defaultValue: {
            'Mute Phone': Action(
              name: 'Mute Phone',
              intent: 'com.llamalab.automate.intent.action.START_FLOW',
              package: 'com.llamalab.automate',
            ),
            'Find My Car': Action(
              name: 'Find My Car',
              intent: 'net.dinglisch.android.taskerm.ACTION_TASK',
              package: 'net.dinglisch.android.taskerm',
            ),
          },
        );

  static Map<String, Action> get map => _instance.value;

  @override
  Map<String, Action> parse(dynamic json) {
    final raw = json as Map<dynamic, dynamic>?;
    if (raw == null) return defaultValue;
    return raw.map(
      (key, val) => MapEntry(
        key.toString(),
        Action.fromJson(Map<String, dynamic>.from(val as Map)),
      ),
    );
  }

  @override
  dynamic serialize(Map<String, Action> value) {
    return value.map((key, val) => MapEntry(key, val.toJson()));
  }
}
