import '../../storage/blob.dart';

class AppsBlob extends Blob<Map<String, bool>> {
  static final AppsBlob _instance = AppsBlob._();
  static AppsBlob get instance => _instance;

  AppsBlob._()
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
