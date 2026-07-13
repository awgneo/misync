import '../../storage/blob.dart';

class Action {
  final String name;
  final String intent;
  final String package;
  final String? uri;
  final Map<String, String>? extras;
  final String icon;

  Action({
    required this.name,
    required this.intent,
    required this.package,
    this.uri,
    this.extras,
    required this.icon,
  });

  factory Action.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? rawExtras =
        json['extras'] as Map<String, dynamic>?;
    final Map<String, String>? extrasMap = rawExtras?.map(
      (k, v) => MapEntry(k, v.toString()),
    );

    return Action(
      name: json['name'] as String? ?? '',
      intent: json['intent'] as String? ?? '',
      package: json['package'] as String? ?? '',
      uri: json['uri'] as String?,
      extras: extrasMap,
      icon: json['icon'] as String? ?? '⚡',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'intent': intent,
    'package': package,
    if (uri != null) 'uri': uri,
    if (extras != null) 'extras': extras,
    'icon': icon,
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
          'Settings': Action(
            name: 'Settings',
            intent: 'android.settings.SETTINGS',
            package: 'com.android.settings',
            icon: '⚙️',
          ),
          'Camera': Action(
            name: 'Camera',
            intent: 'android.media.action.STILL_IMAGE_CAMERA',
            package: '',
            icon: '📷',
          ),
          'Maps': Action(
            name: 'Maps',
            intent: 'android.intent.action.VIEW',
            package: 'com.google.android.apps.maps',
            uri: 'geo:0,0?q=',
            icon: '📍',
          ),
          'Music': Action(
            name: 'Music',
            intent: 'android.intent.action.MUSIC_PLAYER',
            package: '',
            icon: '🎵',
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
