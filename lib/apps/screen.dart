import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'module.dart';
import 'blobs/apps.dart';
import '../screen.dart';

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
    return Container(
      color: const Color(0xFF0F111A),
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'APP MANAGEMENT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                if (!connected) ...[
                  _buildStatusCard(
                    title: 'Disconnected',
                    subtitle: 'Connect to the watch to manage applications.',
                    icon: Icons.link_off,
                    color: Colors.orangeAccent,
                  ),
                ] else ...[
                  _buildAppList(connected),
                ],
              ],
            ),
          ),
          if (connected)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: _install,
                backgroundColor: const Color(0xFF00E5FF),
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text(
                  'Install Custom RPK',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
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

  Widget _buildAppItem(String package, App app) {
    final displayName = app.name.isNotEmpty ? app.name : _getAppName(package);

    if (app.external) {
      return ListTile(
        leading: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _module.uninstall(package),
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          package,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      );
    } else {
      return SwitchListTile(
        value: app.enabled,
        onChanged: (val) {
          if (val) {
            _module.enable(package);
          } else {
            _module.disable(package);
          }
        },
        title: Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          package,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        activeThumbColor: const Color(0xFF00E5FF),
        activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
      );
    }
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

        return Material(
          color: const Color(0xFF141822),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF26324D)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < apps.length; i++) ...[
                if (i > 0) const Divider(color: Color(0xFF26324D), height: 1),
                _buildAppItem(apps[i].key, apps[i].value),
              ],
            ],
          ),
        );
      },
    );
  }
}
