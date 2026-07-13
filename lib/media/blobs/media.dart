import '../../storage/blob.dart';

class MediaBlob extends Blob<bool> {
  static final MediaBlob _instance = MediaBlob._();
  static MediaBlob get instance => _instance;

  MediaBlob._()
    : super(
        module: 'media',
        name: 'media',
        defaultValue: true,
      );

  static bool get enabled => _instance.value;
  static set enabled(bool val) => _instance.update(val);

  @override
  bool parse(dynamic json) => json as bool? ?? true;

  @override
  dynamic serialize(bool value) => value;
}
