import 'package:flutter/material.dart';
import 'module.dart';
export 'module.dart';
import 'device/connection.dart';

abstract class ScreenState<T extends StatefulWidget> extends State<T> {
  Module get module;

  @override
  void initState() {
    super.initState();
    triggerSync();
  }

  Future<void> triggerSync() async {
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
        if (!connected) return child;
        return RefreshIndicator(
          onRefresh: triggerSync,
          color: const Color(0xFF00E5FF),
          backgroundColor: const Color(0xFF141822),
          child: child,
        );
      },
    );
  }
}
