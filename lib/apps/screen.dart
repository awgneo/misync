import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'module.dart';
import 'blobs/apps.dart';
import '../screen.dart';
import '../widgets/panel.dart';
import '../widgets/item.dart';
import '../widgets/items.dart';
import '../widgets/button.dart';

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends ScreenState<AppsScreen> {
  final _module = AppsModule.instance;

  @override
  Module get module => _module;

  String _getAppName(String package) {
    final lastSegment = package.split('.').last;
    if (lastSegment.isEmpty) return package;
    return '${lastSegment[0].toUpperCase()}${lastSegment.substring(1)}';
  }

  Future<void> _install() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      if (path == null) throw StateError('Picked file path is null');

      final success = await _module.install(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Successfully sideloaded app!'
                : 'Failed to sideload app.',
          ),
          backgroundColor: success ? const Color(0xFF00E5FF) : Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting/installing file: $e'),
          backgroundColor: Colors.redAccent,
        ),
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
                  label: 'Install Custom RPK',
                  icon: Icons.add,
                  pressed: _install,
                ),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!connected)
            _buildStatusCard(
              title: 'Disconnected',
              subtitle: 'Connect to the watch to manage applications.',
              icon: Icons.link_off,
              color: Colors.orangeAccent,
            )
          else
            _buildAppList(connected),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF26324D)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
            final displayName = app.name.isNotEmpty ? app.name : _getAppName(package);

            return MiItem(
              title: displayName,
              subtitle: package,
              icon: app.external ? Icons.apps : Icons.settings_applications,
              delete: app.external ? () => _module.uninstall(package) : null,
              enabled: app.external ? null : app.enabled,
              toggled: app.external
                  ? null
                  : (val) {
                      if (val) {
                        _module.enable(package);
                      } else {
                        _module.disable(package);
                      }
                    },
            );
          }).toList(),
        );
      },
    );
  }
}
