import 'package:flutter/material.dart' hide Notification;
import 'package:misync/platform/module.dart';
import 'blobs/replies.dart';
import 'blobs/apps.dart';
import 'blobs/contact.dart';
import 'blobs/dnd.dart';
import '../screen.dart';
import 'module.dart';
import '../widgets/panel.dart';
import '../widgets/item.dart';
import '../widgets/items.dart';
import '../widgets/button.dart';
import '../widgets/tabs.dart';
import '../widgets/picker.dart';
import '../widgets/modal.dart';
import '../platform/app.dart' as phone;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ScreenState<NotificationsScreen> {
  late final TextEditingController _replyController;
  late final TextEditingController _appController;

  final ValueNotifier<Map<String, phone.App>> _installedApps = ValueNotifier(
    {},
  );
  final ValueNotifier<bool> _loadingInstalledApps = ValueNotifier(false);

  @override
  NotificationModule get module => NotificationModule.instance;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController();
    _appController = TextEditingController();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _appController.dispose();
    _installedApps.dispose();
    _loadingInstalledApps.dispose();
    super.dispose();
  }

  @override
  Future<void> refresh() async {
    // Trigger standard DND/alarm sync
    super.refresh();
    // Trigger async background load of installed apps
    _refreshInstalledApps();
  }

  Future<void> _refreshInstalledApps() async {
    _loadingInstalledApps.value = true;
    try {
      final apps = await PlatformModule.instance.getApps();
      if (!mounted) return;
      _installedApps.value = apps;
    } catch (e) {
      module.logger.error('failed to load installed apps in background: $e');
    } finally {
      if (mounted) {
        _loadingInstalledApps.value = false;
      }
    }
  }

  void _addApp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MiPicker(
          registeredFilters: AppsBlob.map.keys.toList(),
          onAppSelected: (packageName) {
            module.addApp(packageName);
          },
        );
      },
    );
  }

  void _addReply() async {
    final reply = await showMiModal<String>(
      context: context,
      title: 'Add Quick Reply',
      label: 'Reply text (e.g., Yes, I will be late)',
      confirm: 'Add',
    );
    if (reply != null && reply.trim().isNotEmpty) {
      final replies = List<String>.from(RepliesBlob.list)..add(reply.trim());
      module.saveReplies(replies);
    }
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return MiTabs(
      tabs: [
        MiTab(
          label: 'Contact',
          child: MiPanel(
            child: ListenableBuilder(
              listenable: ContactBlob.instance,
              builder: (context, _) => _buildContactTab(connected),
            ),
          ),
        ),
        MiTab(
          label: 'Apps',
          child: MiPanel(
            buttons: connected
                ? MiButtons(
                    children: [
                      MiButton(
                        label: 'Add App',
                        icon: Icons.add,
                        pressed: _addApp,
                      ),
                    ],
                  )
                : null,
            child: ListenableBuilder(
              listenable: AppsBlob.instance,
              builder: (context, _) => _buildAppsTab(connected),
            ),
          ),
        ),
        MiTab(
          label: 'Replies',
          child: MiPanel(
            buttons: connected
                ? MiButtons(
                    children: [
                      MiButton(
                        label: 'Add Reply',
                        icon: Icons.add_comment,
                        pressed: _addReply,
                      ),
                    ],
                  )
                : null,
            child: ListenableBuilder(
              listenable: RepliesBlob.instance,
              builder: (context, _) => _buildRepliesTab(connected),
            ),
          ),
        ),
        MiTab(
          label: 'DND',
          child: MiPanel(
            child: ListenableBuilder(
              listenable: DndBlob.instance,
              builder: (context, _) => _buildDndTab(connected),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactTab(bool connected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MiItems(
          children: [
            MiItem(
              title: 'Calls & Messages Mirroring',
              subtitle:
                  'Mirror incoming phone calls and text messages to the watch',
              primaryIcon: Icons.contact_phone_outlined,
              enabled: ContactBlob.enabled,
              toggled: module.saveContactEnabled,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppsTab(bool connected) {
    final filtersMap = AppsBlob.map;

    return ValueListenableBuilder<Map<String, phone.App>>(
      valueListenable: _installedApps,
      builder: (context, installedApps, _) {
        if (filtersMap.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: const Text(
              'No apps configured yet. Add apps with the button below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          );
        }

        return MiItems(
          children: filtersMap.entries.map((entry) {
            final package = entry.key;
            final isEnabled = entry.value;
            final appInfo = installedApps[package];
            final displayName =
                appInfo?.name ?? package.split('.').last.toUpperCase();
            final iconBytes = appInfo?.icon;

            return MiItem(
              title: displayName,
              subtitle: package,
              delete: () {
                module.removeApp(package);
              },
              primaryIcon: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1219),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: iconBytes != null
                    ? Image.memory(iconBytes, fit: BoxFit.contain)
                    : const Icon(Icons.android, color: Colors.grey, size: 16),
              ),
              enabled: isEnabled,
              toggled: (enabled) {
                module.saveAppEnabled(package, enabled);
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRepliesTab(bool connected) {
    final replies = RepliesBlob.list;

    if (replies.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF141822),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF26324D)),
        ),
        child: const Text(
          'No quick replies configured yet.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141822),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF26324D)),
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: replies.length,
        // ignore: deprecated_member_use
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final updated = List<String>.from(replies);
          final item = updated.removeAt(oldIndex);
          updated.insert(newIndex, item);
          module.saveReplies(updated);
        },
        itemBuilder: (context, index) {
          final reply = replies[index];
          return MiItem(
            key: ValueKey('reply_${reply}_$index'),
            title: reply,
            delete: () {
              final updated = List<String>.from(replies)..removeAt(index);
              module.saveReplies(updated);
            },
            order: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDndTab(bool connected) {
    final dndEnabled = DndBlob.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MiItems(
          children: [
            MiItem(
              title: 'Do Not Disturb (DND)',
              subtitle: 'Sync phone status with the band',
              primaryIcon: Icons.do_not_disturb,
              enabled: dndEnabled,
              toggled: module.saveDndEnabled,
            ),
          ],
        ),
      ],
    );
  }
}
