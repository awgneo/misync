import 'package:flutter/material.dart' hide Notification;
import 'dart:typed_data';
import '../debug/logger.dart';
import 'blobs/replies.dart';
import 'blobs/apps.dart';
import 'blobs/messages.dart';
import 'blobs/dnd.dart';
import 'blobs/calls.dart';
import '../screen.dart';
import 'module.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ScreenState<NotificationsScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _replyController;
  late final TextEditingController _appController;
  bool _hasNotificationPermission = true;
  Map<String, Map<String, dynamic>> _installedApps = {};
  bool _isLoadingApps = false;

  @override
  NotificationModule get module => NotificationModule.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _replyController = TextEditingController();
    _appController = TextEditingController();
    _checkPermission();
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    setState(() {
      _isLoadingApps = true;
    });
    try {
      final apps = await module.loadInstalledApps();
      setState(() {
        _installedApps = apps;
      });
    } catch (e) {
      Logger.error('notifications', 'Failed to load installed apps: $e');
    } finally {
      setState(() {
        _isLoadingApps = false;
      });
    }
  }

  void _showAppPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1219),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _AppPickerSheet(
          installedApps: _installedApps.values.toList(),
          registeredFilters: AppsBlob.map.keys.toList(),
          onAppSelected: (packageName) {
            AppsBlob.instance.addApp(packageName);
          },
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _replyController.dispose();
    _appController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final enabled = await module.checkNotificationPermission();
    if (mounted && _hasNotificationPermission != enabled) {
      setState(() {
        _hasNotificationPermission = enabled;
      });
    }
  }

  Future<void> _requestPermission() async {
    await module.requestNotificationPermission();
  }

  void _saveReplies(List<String> repliesList) async {
    await RepliesBlob.instance.update(repliesList);
    await module.sync();
  }

  void _toggleDnd(bool enabled) async {
    DndBlob.enabled = enabled;
    await module.sync();
  }

  void _toggleAppFilter(String package, bool value) {
    AppsBlob.instance[package] = value;
    Logger.info(
      'notifications',
      'notification filter updated for $package: $value',
    );
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1219),
        appBar: const TabBar(
          indicatorColor: Color(0xFF00E5FF),
          labelColor: Color(0xFF00E5FF),
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(icon: Icon(Icons.call), text: 'Calls'),
            Tab(icon: Icon(Icons.message), text: 'Messages'),
            Tab(icon: Icon(Icons.apps), text: 'Apps'),
            Tab(icon: Icon(Icons.reply), text: 'Replies'),
            Tab(icon: Icon(Icons.do_not_disturb), text: 'DND'),
          ],
        ),
        body: TabBarView(
          children: [
            ListenableBuilder(
              listenable: CallsBlob.instance,
              builder: (context, _) => _buildCallsTab(connected),
            ),
            ListenableBuilder(
              listenable: MessagesBlob.instance,
              builder: (context, _) => _buildMessagesTab(connected),
            ),
            ListenableBuilder(
              listenable: AppsBlob.instance,
              builder: (context, _) => _buildAppsTab(connected),
            ),
            ListenableBuilder(
              listenable: RepliesBlob.instance,
              builder: (context, _) => _buildQuickRepliesTab(connected),
            ),
            ListenableBuilder(
              listenable: DndBlob.instance,
              builder: (context, _) => _buildDndTab(connected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallsTab(bool connected) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (!_hasNotificationPermission) ...[
          GestureDetector(
            onTap: _requestPermission,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notification Access is disabled. Tap to enable in system settings.',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const Text(
          'CALLS CONFIGURATION',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 10),
        
        // Calls switch
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141822),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF26324D)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.call_outlined,
                color: Color(0xFF00E5FF),
                size: 28,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Standard Phone Call Mirroring',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Mirror incoming phone calls to the watch',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: CallsBlob.callsEnabled,
                activeThumbColor: const Color(0xFF00E5FF),
                activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                onChanged: (value) async {
                  setState(() {
                    CallsBlob.callsEnabled = value;
                  });
                  await module.sync();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesTab(bool connected) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (!_hasNotificationPermission) ...[
          GestureDetector(
            onTap: _requestPermission,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notification Access is disabled. Tap to enable in system settings.',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const Text(
          'MESSAGES CONFIGURATION',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 10),
        
        // SMS switch
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141822),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF26324D)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.sms_outlined,
                color: Color(0xFF00E5FF),
                size: 28,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Standard SMS Mirroring',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Mirror incoming SMS messages to the watch',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: MessagesBlob.smsEnabled,
                activeThumbColor: const Color(0xFF00E5FF),
                activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                onChanged: (value) async {
                  setState(() {
                    MessagesBlob.smsEnabled = value;
                  });
                  await module.sync();
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),

        // Quick replies fullscreen watch app switch
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141822),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF26324D)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.quickreply_outlined,
                color: Color(0xFF00E5FF),
                size: 28,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Watch Messages App (Quick Replies)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Launch watch Messages app fullscreen for replies',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: MessagesBlob.quickRepliesEnabled,
                activeThumbColor: const Color(0xFF00E5FF),
                activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                onChanged: (value) async {
                  setState(() {
                    MessagesBlob.quickRepliesEnabled = value;
                  });
                  await module.sync();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppsTab(bool connected) {
    final filtersMap = AppsBlob.map;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (!_hasNotificationPermission) ...[
          GestureDetector(
            onTap: _requestPermission,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notification Access is disabled. Tap to enable in system settings.',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        // App picker button
        const Text(
          'APP FILTERS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 10),
        _isLoadingApps
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                ),
              )
            : ElevatedButton.icon(
                onPressed: _showAppPicker,
                icon: const Icon(Icons.add, color: Color(0xFF0F1219)),
                label: const Text(
                  'Add App to Filter',
                  style: TextStyle(
                    color: Color(0xFF0F1219),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
        const SizedBox(height: 24),
        const Text(
          'REGISTERED APP FILTERS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 10),
        if (filtersMap.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: const Text(
              'No apps configured yet. Add apps above to filter notifications.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        else
          Material(
            color: const Color(0xFF141822),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF26324D)),
            ),
            child: Column(
              children: filtersMap.entries.map((entry) {
                final appPackage = entry.key;
                final isEnabled = entry.value;
                final appInfo = _installedApps[appPackage];
                final displayName =
                    appInfo?['appName'] as String? ??
                    appPackage.split('.').last.toUpperCase();
                final iconBytes = appInfo?['iconBytes'] as List<int>?;

                return SwitchListTile(
                  value: isEnabled,
                  onChanged: (val) {
                    _toggleAppFilter(appPackage, val);
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
                    appPackage,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  activeThumbColor: const Color(0xFF00E5FF),
                  secondary: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          AppsBlob.instance.removeApp(appPackage);
                        },
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1219),
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
                                size: 20,
                              ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickRepliesTab(bool connected) {
    final replies = RepliesBlob.list;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add quick reply...',
                    hintStyle: const TextStyle(color: Colors.grey),
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
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: Color(0xFF00E5FF),
                  size: 36,
                ),
                onPressed: () {
                  final reply = _replyController.text.trim();
                  if (reply.isNotEmpty) {
                    final updated = List<String>.from(replies)..add(reply);
                    _saveReplies(updated);
                    _replyController.clear();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Material(
              color: const Color(0xFF141822),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF26324D)),
              ),
              child: ReorderableListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: replies.length,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final updated = List<String>.from(replies);
                  final item = updated.removeAt(oldIndex);
                  updated.insert(newIndex, item);
                  _saveReplies(updated);
                },
                itemBuilder: (context, index) {
                  final reply = replies[index];
                  return Container(
                    key: ValueKey('reply_${reply}_$index'),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: index < replies.length - 1
                            ? const BorderSide(
                                color: Color(0xFF26324D),
                                width: 1,
                              )
                            : BorderSide.none,
                      ),
                    ),
                    child: ListTile(
                      leading: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          final updated = List<String>.from(replies)
                            ..removeAt(index);
                          _saveReplies(updated);
                        },
                      ),
                      title: Text(
                        reply,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(
                          Icons.drag_handle,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDndTab(bool connected) {
    final dndEnabled = DndBlob.enabled;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141822),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF26324D)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Do Not Disturb (DND)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sync phone status with the band',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Switch(
                value: dndEnabled,
                onChanged: _toggleDnd,
                activeThumbColor: const Color(0xFF00E5FF),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> installedApps;
  final List<String> registeredFilters;
  final ValueChanged<String> onAppSelected;

  const _AppPickerSheet({
    required this.installedApps,
    required this.registeredFilters,
    required this.onAppSelected,
  });

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
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
    final filtered = widget.installedApps.where((app) {
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
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
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
                              : const Icon(Icons.android, color: Colors.grey),
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
      ),
    );
  }
}
