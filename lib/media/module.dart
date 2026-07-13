import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screen.dart';
import '../device/module.dart';
import '../device/proto/constants.dart';
import '../device/proto/xiaomi.pb.dart';
import '../platform/module.dart';
import 'blobs/media.dart';
import 'screen.dart';

class MediaModule extends TabModule {
  @override
  String get name => 'media';

  @override
  IconData get icon => Icons.play_circle_outline;

  @override
  late final Screen screen = MediaScreen(this);

  static final MediaModule _module = MediaModule._();
  static MediaModule get module => _module;
  MediaModule._();

  // Observable track details
  final ValueNotifier<Map<String, dynamic>> _nowPlaying = ValueNotifier({
    'title': '',
    'artist': '',
    'duration': 0,
    'position': 0,
    'state': 0, // 0 stopped, 1 playing, 2 paused
    'volume': 0, // 0 to 100
  });

  @override
  Future<void> start() async {
    DeviceModule.module.register(this);
    PlatformModule.module.register(_receivePhoneMethod);
    MediaBlob.instance.addListener(_settingsChanged);
    DeviceModule.module.connection.listen(_receiveWatchCommand);
  }

  Future<dynamic> _receivePhoneMethod(MethodCall call) async {
    switch (call.method) {
      case 'mediaChanged':
        final map = Map<String, dynamic>.from(call.arguments as Map);
        _handlePhoneMediaChanged(map);
        return true;
    }
    return null;
  }

  void _handlePhoneMediaChanged(Map<String, dynamic> data) {
    logger.info('mediaChanged: $data');
    _nowPlaying.value = data;
    _syncNowPlaying();
  }

  void _receiveWatchCommand(Command cmd) {
    if (cmd.type == CmdType.music.value) {
      if (cmd.subtype == MusicSubtype.mediaKey.value) {
        _handleWatchMediaKey(cmd);
      }
    }
  }

  void _handleWatchMediaKey(Command cmd) async {
    if (!cmd.hasMusic() || !cmd.music.hasMediaKey()) return;

    final mediaKey = cmd.music.mediaKey;
    final key = mediaKey.key;
    final volume = mediaKey.hasVolume() ? mediaKey.volume : null;
    logger.info(
      'Received media control command from watch: key=$key, volume=$volume',
    );

    if (!MediaBlob.enabled) {
      logger.info('Media sync is disabled, ignoring watch command');
      return;
    }

    try {
      await PlatformModule.module.invokeMethod('media.control', {
        'key': key,
        'volume': volume,
      });
    } catch (e, stackTrace) {
      logger.error('Failed to invoke native media control: $e', {
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      });
    }
  }

  @override
  Future<void> sync() async {
    await _syncNowPlaying();
  }

  void _settingsChanged() {
    _syncNowPlaying();
  }

  Future<void> _syncNowPlaying() async {
    if (!MediaBlob.enabled) return;
    if (!DeviceModule.module.connection.connected.value) return;

    final state = _nowPlaying.value;
    final title = state['title'] as String? ?? '';
    final artist = state['artist'] as String? ?? '';
    final duration = state['duration'] as int? ?? 0;
    final position = state['position'] as int? ?? 0;
    final playbackState = state['state'] as int? ?? 0;
    final volume = state['volume'] as int? ?? 0;

    logger.info(
      'Syncing music state to watch: $title - $artist (state=$playbackState)',
    );

    try {
      await DeviceModule.module.connection.send(
        type: CmdType.music,
        subtype: MusicSubtype.info,
        builder: (cmd) {
          cmd.music = Music()
            ..musicInfo = (MusicInfo()
              ..state = playbackState
              ..volume = volume
              ..track = title
              ..artist = artist
              ..position = position
              ..duration = duration);
        },
      );
    } catch (e, stackTrace) {
      logger.error('Failed to sync music state to watch: $e', {
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      });
    }
  }
}
