import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'module.dart';
import 'blobs/apps.dart';
import '../screen.dart';
import '../widgets/panel.dart';
import '../widgets/item.dart';
import '../widgets/items.dart';
import '../widgets/button.dart';

import '../widgets/modal.dart';

class AppsScreen extends Screen<AppsModule> {
  const AppsScreen(super.module, {super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends ScreenState<AppsScreen> {
  Future<void> _installApp() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;

    final path = result.files.first.path;
    if (path == null) throw StateError('Picked file path is null');

    final success = await widget.module.install(path);
    if (!success) {
      if (!mounted) return;
      await showMiModal<bool>(
        context: context,
        title: 'Sideload Failed',
        body: 'Failed to sideload the app.',
        confirm: 'OK',
      );
    }
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return MiPanel(
      buttons: connected
          ? MiButtons(
              children: [
                MiButton(
                  label: 'Install App',
                  icon: Icons.add,
                  pressed: _installApp,
                ),
              ],
            )
          : null,
      child: _buildAppList(connected),
    );
  }

  Widget _buildAppList(bool connected) {
    return ListenableBuilder(
      listenable: AppsBlob.instance,
      builder: (context, _) {
        final registry = AppsBlob.instance.value;
        final apps = registry.entries.toList();

        if (apps.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No applications loaded.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          );
        }

        return MiItems(
          children: apps.map((entry) {
            final package = entry.key;
            final app = entry.value;
            final displayName = app.name;

            return MiItem(
              title: displayName,
              subtitle: package,
              primaryIcon: app.external
                  ? Icons.apps
                  : Icons.settings_applications,
              delete: app.external
                  ? () => widget.module.uninstall(package)
                  : null,
              enabled: app.external ? null : app.enabled,
              toggled: app.external
                  ? null
                  : (enabled) {
                      if (enabled) {
                        widget.module.enableApp(package);
                      } else {
                        widget.module.disableApp(package);
                      }
                    },
            );
          }).toList(),
        );
      },
    );
  }
}
