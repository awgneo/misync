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
        final enabled = MediaBlob.enabled;

        return MiPanel(
          child: MiItems(
            children: [
              MiItem(
                title: 'Sync Media Controls',
                subtitle: 'Control phone media and sync metadata to watch',
                primaryIcon: Icons.audiotrack,
                enabled: enabled,
                toggled: (value) {
                  MediaBlob.enabled = value;
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
