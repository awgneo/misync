import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:misync/screen.dart';
import 'module.dart';
import '../widgets/panel.dart';
import '../widgets/items.dart';
import '../widgets/item.dart';
import '../widgets/modal.dart';
import '../widgets/button.dart';
import '../device/proto/xiaomi.pb.dart';

class FacesScreen extends Screen<FacesModule> {
  const FacesScreen(super.module, {super.key});

  @override
  State<FacesScreen> createState() => _FacesScreenState();
}

class _FacesScreenState extends ScreenState<FacesScreen> {
  void _pickAndInstallFace() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      if (!mounted) return;
      // Show install confirmation modal
      final confirm = await showMiModal<bool>(
        context: context,
        title: 'Install Watch Face',
        body: 'Do you want to install "${file.name}" on the band?',
        confirm: 'Install',
        cancel: 'Cancel',
      );

      if (confirm != true) return;

      // Perform installation
      final success = await widget.module.installFace(file.name, bytes);

      if (!mounted) return;
      if (success) {
        await showMiModal<bool>(
          context: context,
          title: 'Installation Complete',
          body: 'Watch face has been installed and set active.',
          confirm: 'OK',
        );
      } else {
        await showMiModal<bool>(
          context: context,
          title: 'Installation Failed',
          body:
              'Failed to install watch face. Please verify connection and retry.',
          confirm: 'OK',
        );
      }
    } catch (e) {
      widget.module.logger.error('error picking/installing face: $e');
    }
  }

  void _deleteFace(String id, String name) async {
    final confirm = await showMiModal<bool>(
      context: context,
      title: 'Delete Watch Face',
      body: 'Do you want to delete watch face "$name" from the band?',
      confirm: 'Delete',
      cancel: 'Cancel',
    );

    if (confirm == true) {
      await widget.module.deleteFace(id);
    }
  }

  void _setFace(String id) async {
    await widget.module.setFace(id);
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return ValueListenableBuilder<List<WatchfaceInfo>>(
      valueListenable: widget.module.faces,
      builder: (context, faces, _) {
        return MiPanel(
          scrollable: true,
          buttons: connected
              ? MiButtons(
                  children: [
                    MiButton(
                      label: 'Install Face',
                      icon: Icons.upload_file,
                      pressed: _pickAndInstallFace,
                    ),
                  ],
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (faces.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No watch faces found. Refresh or connect device.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              else
                MiItems(
                  children: faces.map((face) {
                    final isCurrent = face.active;
                    final displayName = face.name.isNotEmpty
                        ? face.name
                        : 'Custom Face';
                    return MiItem(
                      title: displayName,
                      subtitle: 'ID: ${face.id}',
                      primaryIcon: Icons.watch_outlined,
                      secondaryIcon: isCurrent
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF00E5FF),
                            )
                          : null,
                      delete: face.canDelete
                          ? () => _deleteFace(face.id, displayName)
                          : null,
                      clicked: isCurrent ? null : () => _setFace(face.id),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}
