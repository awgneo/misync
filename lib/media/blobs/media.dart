import '../../storage/blob.dart';

class Media {
  final bool nowPlayingEnabled;
  final bool recordingsEnabled;

  Media({this.nowPlayingEnabled = true, this.recordingsEnabled = false});

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      nowPlayingEnabled: json['mediaEnabled'] as bool? ?? true,
      recordingsEnabled: json['recordingsEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mediaEnabled': nowPlayingEnabled,
      'recordingsEnabled': recordingsEnabled,
    };
  }
}

class MediaBlob extends Blob<Media> {
  static final MediaBlob _instance = MediaBlob._();
  static MediaBlob get instance => _instance;

  MediaBlob._() : super(module: 'media', name: 'media', defaultValue: Media());

  static Media get current => _instance.value;
  static set current(Media val) => _instance.update(val);

  @override
  Media parse(dynamic json) {
    if (json == null) return Media();
    if (json is bool) {
      // Migrate from legacy single boolean enabled state
      return Media(nowPlayingEnabled: json, recordingsEnabled: false);
    }
    return Media.fromJson(Map<String, dynamic>.from(json as Map));
  }

  @override
  dynamic serialize(Media value) => value.toJson();
}
