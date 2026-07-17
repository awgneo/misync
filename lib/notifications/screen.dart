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
import '../widgets/app.dart';
import '../widgets/popup.dart';
import '../platform/app.dart' as phone;

class NotificationsScreen extends Screen<NotificationModule> {
  const NotificationsScreen(super.module, {super.key});

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

  static const Map<int, String> _vibrationCategories = {
    1: 'Incoming Calls',
    2: 'Event Reminders',
    3: 'Alarms',
    4: 'App Notifications',
    5: 'Standing Reminder',
    6: 'SMS',
    7: 'Goal Reached',
    8: 'Schedule/Todo',
  };

  static const Map<int, IconData> _vibrationCategoryIcons = {
    1: Icons.phone_in_talk,
    2: Icons.event,
    3: Icons.alarm,
    4: Icons.notifications,
    5: Icons.accessibility_new,
    6: Icons.sms,
    7: Icons.emoji_events,
    8: Icons.today,
  };

  static const Map<int, String> _vibrationPresets = {
    0: 'Default',
    240: 'Chime',
    241: 'Raindrops',
    242: 'Gradual Wakeup',
    243: 'Reverse Pulse',
    244: 'Pulse',
    245: 'Spark',
    246: 'Coin',
    247: 'Award',
    248: 'Guitar',
    249: 'Tambourine',
    250: 'Heartbeat',
    251: 'Step-by-Step',
    252: 'Toy House',
    253: 'Iced Latte',
    254: 'Rhythm',
    255: 'Light Dance',
  };

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
      final apps = await PlatformModule.module.getApps();
      if (!mounted) return;
      _installedApps.value = apps;
    } catch (e) {
      widget.module.logger.error(
        'failed to load installed apps in background: $e',
      );
    } finally {
      if (mounted) {
        _loadingInstalledApps.value = false;
      }
    }
  }

  void _addApp() {
    MiPopup.show(
      context,
      title: 'Select App',
      child: MiApp(
        removed: AppsBlob.map.keys.toList(),
        selected: (packageName) {
          widget.module.addApp(packageName);
        },
      ),
    );
  }

  Future<void> _addReply() async {
    final reply = await MiPopup.show<String>(
      context,
      title: 'Add Reply',
      child: _ReplySetupSheet(module: widget.module),
    );
    if (reply != null && reply.trim().isNotEmpty) {
      final replies = List<String>.from(RepliesBlob.list)..add(reply.trim());
      widget.module.saveReplies(replies);
    }
  }

  Future<void> _editReply(int index, String currentReply) async {
    final reply = await MiPopup.show<String>(
      context,
      title: 'Edit Reply',
      child: _ReplySetupSheet(module: widget.module, reply: currentReply),
    );
    if (reply != null && reply.trim().isNotEmpty) {
      final replies = List<String>.from(RepliesBlob.list);
      replies[index] = reply.trim();
      widget.module.saveReplies(replies);
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
        MiTab(
          label: 'Vibrate',
          child: MiPanel(
            child: ListenableBuilder(
              listenable: widget.module.vibrations,
              builder: (context, _) => _buildVibrateTab(connected),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactTab(bool connected) {
    final contact = ContactBlob.contact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MiItems(
          children: [
            MiItem(
              title: 'Call Sync',
              subtitle: 'Mirror incoming phone calls to the watch',
              primaryIcon: Icons.call,
              enabled: contact.callEnabled,
              toggled: (val) => widget.module.saveContact(callEnabled: val),
            ),
            MiItem(
              title: 'Text Sync',
              subtitle: 'Mirror incoming text messages to the watch',
              primaryIcon: Icons.sms,
              enabled: contact.textEnabled,
              toggled: (val) => widget.module.saveContact(textEnabled: val),
            ),
            MiItem(
              title: 'Email Sync',
              subtitle: 'Mirror incoming emails to the watch',
              primaryIcon: Icons.email,
              enabled: contact.emailEnabled,
              toggled: (val) => widget.module.saveContact(emailEnabled: val),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppsTab(bool connected) {
    final appsMap = AppsBlob.map;

    return ValueListenableBuilder<Map<String, phone.App>>(
      valueListenable: _installedApps,
      builder: (context, installedApps, _) {
        if (appsMap.isEmpty) {
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

        final sortedEntries = appsMap.entries.toList()
          ..sort((a, b) {
            final appA = installedApps[a.key];
            final appB = installedApps[b.key];
            final nameA = appA?.name ?? a.key.split('.').last.toUpperCase();
            final nameB = appB?.name ?? b.key.split('.').last.toUpperCase();
            return nameA.toLowerCase().compareTo(nameB.toLowerCase());
          });

        return MiItems(
          children: sortedEntries.map((entry) {
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
                widget.module.removeApp(package);
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
                widget.module.saveAppEnabled(package, enabled);
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
          'No replies configured yet.',
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
          widget.module.saveReplies(updated);
        },
        itemBuilder: (context, index) {
          final reply = replies[index];
          return MiItem(
            key: ValueKey('reply_${reply}_$index'),
            title: reply,
            clicked: () => _editReply(index, reply),
            delete: () {
              final updated = List<String>.from(replies)..removeAt(index);
              widget.module.saveReplies(updated);
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
              title: 'Do Not Disturb Sync',
              subtitle: 'Mirror DND status with the watch',
              primaryIcon: Icons.do_not_disturb,
              enabled: dndEnabled,
              toggled: widget.module.saveDndEnabled,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVibrateTab(bool connected) {
    final currentVibrations = widget.module.vibrations.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MiItems(
          children: _vibrationCategories.entries.map((entry) {
            final categoryId = entry.key;
            final categoryName = entry.value;
            final categoryIcon =
                _vibrationCategoryIcons[categoryId] ?? Icons.vibration;
            final currentPreset = currentVibrations[categoryId] ?? 0;

            final optionsMap = Map<int, String>.from(_vibrationPresets);
            if (!optionsMap.containsKey(currentPreset)) {
              optionsMap[currentPreset] = 'Custom ($currentPreset)';
            }

            return MiItem(
              title: categoryName,
              primaryIcon: categoryIcon,
              options: optionsMap,
              value: currentPreset,
              selected: (preset) {
                widget.module.setWatchVibration(categoryId, preset as int);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ReplySetupSheet extends StatefulWidget {
  final String? reply;
  final NotificationModule module;

  const _ReplySetupSheet({
    required this.module,
    this.reply,
  });

  @override
  State<_ReplySetupSheet> createState() => _ReplySetupSheetState();
}

class _ReplySetupSheetState extends State<_ReplySetupSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.reply ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final remainingHeight = screenHeight - keyboardHeight;
    const estimatedHeight = 250.0;

    widget.module.logger.debug(
      'Reply sheet height check: screenHeight=$screenHeight, keyboardHeight=$keyboardHeight, remainingHeight=$remainingHeight',
    );
    if (remainingHeight < estimatedHeight) {
      widget.module.logger.error(
        'Potential bottom overflow in Reply sheet: remaining height ($remainingHeight) < estimated height ($estimatedHeight)',
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Reply text (e.g., Yes, I will be late)',
            labelStyle: const TextStyle(color: Colors.grey),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF26324D)),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF00E5FF)),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final text = _controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(context).pop(text);
              }
            },
            child: Text(
              widget.reply == null ? 'Add' : 'Save',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
