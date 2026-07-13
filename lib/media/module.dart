import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screen.dart';
import '../device/module.dart';
import '../device/proto/constants.dart';
import '../device/proto/xiaomi.pb.dart';
import '../platform/module.dart';
import '../crc32.dart';
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

  ValueNotifier<Map<String, dynamic>> get nowPlaying => _nowPlaying;

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
      } else if (cmd.subtype == MusicSubtype.getRecordingsListResponse.value) {
        _handleWatchRecordingsListResponse(cmd);
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

    if (!MediaBlob.current.nowPlayingEnabled) {
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

  Future<void> _handleWatchRecordingsListResponse(Command cmd) async {
    if (!cmd.hasMusic() || !cmd.music.hasRecordList()) {
      logger.info('No recordings list returned in watch response');
      return;
    }

    final records = cmd.music.recordList.records;
    if (records.isEmpty) {
      logger.info('Watch recordings list is empty');
      return;
    }

    logger.info('Found ${records.length} recordings on watch. Syncing...');

    try {
      // Ensure recordings directory exists on the phone
      final dir = Directory('/storage/emulated/0/Recordings');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      for (final record in records) {
        final id = record.info.id;
        logger.info('Downloading recording memo: $id');

        final requestCmd = Command()
          ..type = CmdType.music.value
          ..subtype = MusicSubtype.downloadRecordings.value
          ..music = (Music()
            ..recordIdList = (SoundRecordIdList()..ids.add(record.info)));

        final fileBytes = await DeviceModule.module.connection.downloadData(
          cmd: requestCmd,
        );
        if (fileBytes == null || fileBytes.isEmpty) {
          logger.error('Failed to download memo: $id (empty bytes payload)');
          continue;
        }

        // 1. Verify CRC32 checksum
        final dataBytes = fileBytes.sublist(0, fileBytes.length - 4);
        final expectedCrc = Crc32.calculate(dataBytes);
        final receivedCrc = ByteData.sublistView(
          fileBytes,
          fileBytes.length - 4,
        ).getUint32(0, Endian.little);
        if (expectedCrc != receivedCrc) {
          logger.error(
            'CRC32 checksum mismatch for memo $id: expected $expectedCrc, received $receivedCrc',
          );
          continue;
        }

        // 2. Parse file segments
        final idLength = dataBytes[0];
        final idString = utf8.decode(dataBytes.sublist(1, 1 + idLength));
        final audioBytes = dataBytes.sublist(1 + idLength + 5);

        // 3. Save to phone's public Recordings directory
        final filename = idString.split('/').last;
        final file = File('/storage/emulated/0/Recordings/$filename');
        await file.writeAsBytes(audioBytes);
        logger.info('Successfully saved synced memo to: ${file.path}');

        // 4. Send acknowledgment back to watch (clears it from watch memory)
        final confirmCmd = Command()
          ..type = CmdType.music.value
          ..subtype = MusicSubtype.confirmRecordingReceived.value
          ..music = (Music()
            ..recordId = (SoundRecordId()
              ..id = idString
              ..synced = false));
        await DeviceModule.module.connection.send(cmd: confirmCmd);
        logger.info('Sent sync confirmation for memo: $idString');
      }
    } catch (e, stackTrace) {
      logger.error('Error during watch recordings download: $e\n$stackTrace');
    }
  }

  @override
  Future<void> sync() async {
    final mediaSettings = MediaBlob.current;

    if (mediaSettings.nowPlayingEnabled) {
      await _syncNowPlaying();
    }

    if (mediaSettings.recordingsEnabled) {
      await _syncWatchRecordings();
    }
  }

  void _settingsChanged() {
    _syncNowPlaying();
  }

  Future<void> _syncNowPlaying() async {
    if (!MediaBlob.current.nowPlayingEnabled) return;
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

  Future<void> _syncWatchRecordings() async {
    if (!DeviceModule.module.connection.connected.value) return;

    try {
      logger.info('Querying watch recordings list (type=18, subtype=15)');
      await DeviceModule.module.connection.send(
        type: CmdType.music,
        subtype: MusicSubtype.getRecordingsList,
      );
    } catch (e, stackTrace) {
      logger.error('Error querying watch recordings: $e\n$stackTrace');
    }
  }
}
