import 'package:flutter/material.dart';
import '../screen.dart';
import 'module.dart';
import '../widgets/panel.dart';
import '../widgets/items.dart';
import '../widgets/item.dart';
import '../widgets/modal.dart';

class StorageScreen extends Screen<StorageModule> {
  const StorageScreen(super.module, {super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ScreenState<StorageScreen> {
  void _clearAll() async {
    final confirm = await showMiModal<bool>(
      context: context,
      title: 'Wipe All Storage?',
      body:
          'This will reset all app settings, configurations, and cached data. This action is irreversible.',
      confirm: 'Wipe All',
      cancel: 'Cancel',
    );

    if (confirm == true) {
      await widget.module.clearAll();
    }
  }

  void _delete(String m) async {
    final confirm = await showMiModal<bool>(
      context: context,
      title: 'Delete Module Storage?',
      body:
          'This will delete all saved configuration data for the "$m" module.',
      confirm: 'Delete',
      cancel: 'Cancel',
    );

    if (confirm == true) {
      await widget.module.delete(m);
    }
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return MiPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MiItems(
            children: [
              MiItem(
                title: 'All Storage',
                subtitle: 'Resets all active configurations',
                delete: _clearAll,
              ),
            ],
          ),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: widget.module,
            builder: (context, _) {
              final modules = widget.module.modules;
              if (modules.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No active module storage found.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              return MiItems(
                children: modules.map((m) {
                  final displayName = m[0].toUpperCase() + m.substring(1);
                  return MiItem(
                    title: '$displayName Storage',
                    subtitle: 'Stored settings for $m',
                    delete: () => _delete(m),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
