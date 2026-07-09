import '../../storage/blob.dart';

class RepliesBlob extends Blob<List<String>> {
  static final RepliesBlob _instance = RepliesBlob._();
  static RepliesBlob get instance => _instance;

  RepliesBlob._()
      : super(
          module: 'notifications',
          name: 'replies',
          defaultValue: const [
            'OK',
            'Yes, on my way!',
            'Can\'t talk right now.',
            'Busy, call you later.',
          ],
        );

  static List<String> get list => _instance.value;

  String operator [](int index) => value[index];
  void operator []=(int index, String val) {
    final updated = List<String>.from(value);
    updated[index] = val;
    update(updated);
  }

  @override
  List<String> parse(dynamic json) => List<String>.from(json ?? []);

  @override
  dynamic serialize(List<String> value) => value;
}
