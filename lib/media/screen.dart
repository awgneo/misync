import 'package:flutter/material.dart';
import '../screen.dart';
import '../widgets/panel.dart';
import '../widgets/items.dart';
import '../widgets/item.dart';
import 'module.dart';
import 'blobs/media.dart';

class MediaScreen extends Screen<MediaModule> {
  const MediaScreen(super.module, {super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends ScreenState<MediaScreen> {
  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return ListenableBuilder(
      listenable: MediaBlob.instance,
      builder: (context, _) {
        final currentMedia = MediaBlob.current;

        return MiPanel(
          child: MiItems(
            children: [
              MiItem(
                title: 'Sync Now Playing',
                subtitle: 'Control phone media and sync metadata to watch',
                primaryIcon: Icons.audiotrack,
                enabled: currentMedia.nowPlayingEnabled,
                toggled: (value) {
                  MediaBlob.current = Media(
                    nowPlayingEnabled: value,
                    recordingsEnabled: currentMedia.recordingsEnabled,
                  );
                },
              ),
              MiItem(
                title: 'Sync Voice Recordings',
                subtitle: 'Automatically download new recordings from watch',
                primaryIcon: Icons.mic,
                enabled: currentMedia.recordingsEnabled,
                toggled: (value) {
                  MediaBlob.current = Media(
                    nowPlayingEnabled: currentMedia.nowPlayingEnabled,
                    recordingsEnabled: value,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
