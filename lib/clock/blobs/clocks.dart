import '../../storage/blob.dart';

class ClocksBlob extends Blob<List<String>> {
  static final ClocksBlob _instance = ClocksBlob._();
  static ClocksBlob get instance => _instance;

  ClocksBlob._() : super(module: 'clock', name: 'clocks', defaultValue: []);

  static List<String> get list => _instance.value;

  @override
  List<String> parse(dynamic json) {
    if (json == null) return [];
    return List<String>.from(json as List);
  }

  @override
  dynamic serialize(List<String> value) {
    return value;
  }
}
