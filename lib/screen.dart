import 'package:flutter/material.dart';
import 'module.dart';
export 'module.dart';
import 'device/connection.dart';
import 'platform/module.dart';

abstract class ScreenState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver {
  Module get module;

  bool _hasPermissions = true;
  bool get hasPermissions => _hasPermissions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    checkPermissions();
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkPermissions();
    }
  }

  Future<void> checkPermissions() async {
    final hasPerms = await PlatformModule.instance.checkModulePermissions(
      module.name,
    );
    if (mounted) {
      setState(() {
        _hasPermissions = hasPerms;
      });
    }
  }

  Widget _buildBannerWidget() {
    return GestureDetector(
      onTap: () async {
        await PlatformModule.instance.requestModulePermissions(module.name);
        await checkPermissions();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Required permissions are disabled. Tap to enable.',
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
    );
  }

  Future<void> refresh() async {
    if (!DeviceConnection.instance.connected.value) return;

    try {
      await module.sync();
    } catch (e) {
      debugPrint(
        'ScreenState: Sync failed for module ${module.runtimeType}: $e',
      );
    }
  }

  Widget buildScreen(BuildContext context, bool connected);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DeviceConnection.instance.connected,
      builder: (context, connected, _) {
        final child = buildScreen(context, connected);

        final Widget contentWithBanner;
        if (_hasPermissions) {
          contentWithBanner = child;
        } else {
          contentWithBanner = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBannerWidget(),
              Expanded(child: child),
            ],
          );
        }

        if (!connected) return contentWithBanner;
        return RefreshIndicator(
          onRefresh: refresh,
          color: const Color(0xFF00E5FF),
          backgroundColor: const Color(0xFF141822),
          notificationPredicate: (ScrollNotification notification) {
            return notification.metrics.axis == Axis.vertical;
          },
          child: contentWithBanner,
        );
      },
    );
  }
}
