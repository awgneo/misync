import '../../storage/blob.dart';

class FiltersBlob extends Blob<Map<String, bool>> {
  static final FiltersBlob _instance = FiltersBlob._();
  static FiltersBlob get instance => _instance;

  FiltersBlob._()
      : super(
          module: 'notifications',
          name: 'filters',
          defaultValue: const {
            'com.whatsapp': true,
            'com.instagram.android': true,
            'com.google.android.apps.messaging': true,
            'com.android.email': false,
          },
        );

  static Map<String, bool> get map => _instance.value;

  static bool get smsEnabled => map['__sms__'] ?? true;
  static set smsEnabled(bool value) {
    _instance[ '__sms__' ] = value;
  }

  bool? operator [](String package) => value[package];
  void operator []=(String package, bool val) {
    final updated = Map<String, bool>.from(value);
    updated[package] = val;
    update(updated);
  }

  void addApp(String package) {
    final updated = Map<String, bool>.from(value);
    updated[package] = true;
    update(updated);
  }

  void removeApp(String package) {
    final updated = Map<String, bool>.from(value);
    updated.remove(package);
    update(updated);
  }

  @override
  Map<String, bool> parse(dynamic json) => Map<String, bool>.from(json ?? {});

  @override
  dynamic serialize(Map<String, bool> value) => value;
}
