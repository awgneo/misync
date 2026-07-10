import '../../storage/blob.dart';

class ContactBlob extends Blob<bool> {
  static final ContactBlob _instance = ContactBlob._();
  static ContactBlob get instance => _instance;

  ContactBlob._()
      : super(
          module: 'notifications',
          name: 'contact',
          defaultValue: true,
        );

  static bool get enabled => _instance.value;
  static set enabled(bool value) {
    _instance.update(value);
  }

  @override
  bool parse(dynamic json) {
    if (json is bool) return json;
    return true;
  }

  @override
  dynamic serialize(bool value) => value;
}
