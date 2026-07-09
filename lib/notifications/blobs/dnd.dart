import '../../storage/blob.dart';

class DndBlob extends Blob<bool> {
  static final DndBlob _instance = DndBlob._();
  static DndBlob get instance => _instance;

  DndBlob._()
      : super(
          module: 'notifications',
          name: 'dnd',
          defaultValue: false,
        );

  static bool get enabled => _instance.value;
  static set enabled(bool val) => _instance.update(val);

  @override
  bool parse(dynamic json) => json as bool? ?? false;

  @override
  dynamic serialize(bool value) => value;
}
