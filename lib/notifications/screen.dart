import 'package:flutter/material.dart' hide Notification;
import 'dart:typed_data';
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
import '../widgets/modal.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ScreenState<NotificationsScreen> {
  late final TextEditingController _replyController;
  late final TextEditingController _appController;

  final ValueNotifier<Map<String, Map<String, dynamic>>> _installedApps =
      ValueNotifier({});
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
      final apps = await module.getInstalledApps();
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
      backgroundColor: const Color(0xFF0F1219),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _AppPicker(
          installedAppsNotifier: _installedApps,
          isLoadingNotifier: _loadingInstalledApps,
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

    return ValueListenableBuilder<Map<String, Map<String, dynamic>>>(
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
                appInfo?['appName'] as String? ??
                package.split('.').last.toUpperCase();
            final iconBytes = appInfo?['iconBytes'] as List<int>?;

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
                    ? Image.memory(
                        Uint8List.fromList(iconBytes),
                        fit: BoxFit.contain,
                      )
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

class _AppPicker extends StatefulWidget {
  final ValueNotifier<Map<String, Map<String, dynamic>>> installedAppsNotifier;
  final ValueNotifier<bool> isLoadingNotifier;
  final List<String> registeredFilters;
  final ValueChanged<String> onAppSelected;

  const _AppPicker({
    required this.installedAppsNotifier,
    required this.isLoadingNotifier,
    required this.registeredFilters,
    required this.onAppSelected,
  });

  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.installedAppsNotifier,
        widget.isLoadingNotifier,
      ]),
      builder: (context, _) {
        final isLoading = widget.isLoadingNotifier.value;
        final apps = widget.installedAppsNotifier.value.values.toList();

        final filtered = apps.where((app) {
          final name = (app['appName'] as String? ?? '').toLowerCase();
          final pkg = (app['packageName'] as String? ?? '').toLowerCase();
          final query = _searchQuery.toLowerCase();
          return name.contains(query) || pkg.contains(query);
        }).toList();

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  ),
                )
              else ...[
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search apps...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF26324D)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF26324D)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF141822),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'No apps found matching search query.',
                                  style: TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                if (_searchQuery.trim().isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      widget.onAppSelected(_searchQuery.trim());
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: Color(0xFF0F1219),
                                    ),
                                    label: Text(
                                      'Register manually: ${_searchQuery.trim()}',
                                      style: const TextStyle(
                                        color: Color(0xFF0F1219),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00E5FF),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final app = filtered[index];
                            final packageName = app['packageName'] as String;
                            final appName = app['appName'] as String;
                            final iconBytes = app['iconBytes'] as List<int>?;
                            final isAdded = widget.registeredFilters.contains(
                              packageName,
                            );

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141822),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: iconBytes != null
                                    ? Image.memory(
                                        Uint8List.fromList(iconBytes),
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(
                                        Icons.android,
                                        color: Colors.grey,
                                      ),
                              ),
                              title: Text(
                                appName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                packageName,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: isAdded
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF00E5FF),
                                    )
                                  : const Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.grey,
                                    ),
                              onTap: isAdded
                                  ? null
                                  : () {
                                      widget.onAppSelected(packageName);
                                      Navigator.pop(context);
                                    },
                            );
                          },
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
