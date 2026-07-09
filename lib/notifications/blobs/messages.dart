import '../../storage/blob.dart';

class MessagesBlob extends Blob<Map<String, bool>> {
  static final MessagesBlob _instance = MessagesBlob._();
  static MessagesBlob get instance => _instance;

  MessagesBlob._()
      : super(
          module: 'notifications',
          name: 'messages',
          defaultValue: const {
            'smsEnabled': true,
            'quickRepliesEnabled': true,
          },
        );

  static Map<String, bool> get settings => _instance.value;

  static bool get smsEnabled => settings['smsEnabled'] ?? true;
  static set smsEnabled(bool value) {
    final updated = Map<String, bool>.from(settings);
    updated['smsEnabled'] = value;
    _instance.update(updated);
  }

  static bool get quickRepliesEnabled => settings['quickRepliesEnabled'] ?? true;
  static set quickRepliesEnabled(bool value) {
    final updated = Map<String, bool>.from(settings);
    updated['quickRepliesEnabled'] = value;
    _instance.update(updated);
  }

  @override
  Map<String, bool> parse(dynamic json) => Map<String, bool>.from(json ?? {});

  @override
  dynamic serialize(Map<String, bool> value) => value;
}
