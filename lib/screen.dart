import 'package:flutter/material.dart';
import 'module.dart';
export 'module.dart';
import 'device/connection.dart';
import 'platform/module.dart';

abstract class ScreenState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver {
  Module get module;

  List<String> _missingPermissions = [];
  List<String> get missingPermissions => _missingPermissions;

  @override
  void initState() {
    super.initState();
    if (module.permissions.isNotEmpty) {
      WidgetsBinding.instance.addObserver(this);
      checkPermissions();
    }
    refresh();
  }

  @override
  void dispose() {
    if (module.permissions.isNotEmpty) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkPermissions();
    }
  }

  Future<void> checkPermissions() async {
    if (module.permissions.isEmpty) return;
    final missing = await PlatformModule.instance.checkPermissions(
      module.permissions,
    );
    if (mounted) {
      setState(() {
        _missingPermissions = missing;
      });
    }
  }

  Widget _buildBannerWidget(List<String> missing) {
    final names = missing
        .map((p) {
          return p[0].toUpperCase() + p.substring(1);
        })
        .join(', ');

    return GestureDetector(
      onTap: () async {
        await PlatformModule.instance.requestPermissions(missing);
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
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Required permissions ($names) are disabled. Tap to enable.',
                style: const TextStyle(
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
    if (!DeviceConnection.connected.value) return;

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
      valueListenable: DeviceConnection.connected,
      builder: (context, connected, _) {
        final child = buildScreen(context, connected);
        final missing = module.permissions
            .where((p) => _missingPermissions.contains(p))
            .toList();

        final Widget contentWithBanner;
        if (missing.isEmpty) {
          contentWithBanner = child;
        } else {
          contentWithBanner = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBannerWidget(missing),
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
