import '../../storage/blob.dart';

class DebugBlob extends Blob<bool> {
  static final DebugBlob _instance = DebugBlob._();
  static DebugBlob get instance => _instance;

  DebugBlob._() : super(module: 'debug', name: 'enabled', defaultValue: true);

  static bool get enabled => _instance.value;
  static set enabled(bool val) => _instance.update(val);

  @override
  bool parse(dynamic json) {
    if (json is bool) return json;
    return true;
  }

  @override
  dynamic serialize(bool value) => value;
}
