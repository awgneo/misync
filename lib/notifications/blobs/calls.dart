import '../../storage/blob.dart';

class CallsBlob extends Blob<Map<String, bool>> {
  static final CallsBlob _instance = CallsBlob._();
  static CallsBlob get instance => _instance;

  CallsBlob._()
      : super(
          module: 'notifications',
          name: 'calls',
          defaultValue: const {
            'callsEnabled': true,
          },
        );

  static Map<String, bool> get settings => _instance.value;

  static bool get callsEnabled => settings['callsEnabled'] ?? true;
  static set callsEnabled(bool value) {
    final updated = Map<String, bool>.from(settings);
    updated['callsEnabled'] = value;
    _instance.update(updated);
  }

  @override
  Map<String, bool> parse(dynamic json) => Map<String, bool>.from(json ?? {});

  @override
  dynamic serialize(Map<String, bool> value) => value;
}
