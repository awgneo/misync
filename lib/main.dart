import 'package:flutter/material.dart';
import 'device/connection.dart';
import 'device/module.dart';
import 'notifications/module.dart';
import 'faces/module.dart';
import 'health/module.dart';
import 'actions/module.dart';
import 'debug/module.dart';
import 'storage/module.dart';
import 'platform/module.dart';
import 'clock/module.dart';
import 'apps/module.dart';
import 'module.dart';

final List<Module> modules = [
  StorageModule.instance,
  PlatformModule.instance,
  DeviceModule.instance,
  ClockModule.instance,
  AppsModule.instance,
  NotificationModule.instance,
  FacesModule.instance,
  HealthModule.instance,
  ActionsModule.instance,
  DebugModule.instance,
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start all module lifecycles in a loop sequentially
  for (final module in modules) {
    await module.start();
  }

  runApp(const MiSyncApp());
}

class MiSyncApp extends StatelessWidget {
  const MiSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1219),
        primaryColor: const Color(0xFF00E5FF),
      ),
      home: const MainContainerScreen(),
    );
  }
}

class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  int _currentIndex = 0;

  final List<TabModule> _tabModules = modules.whereType<TabModule>().toList();

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = _tabModules.map((m) => m.screen).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MiSync',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF00E5FF),
          ),
        ),
        backgroundColor: const Color(0xFF0F1219),
        elevation: 0,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: DeviceConnection.connected,
            builder: (context, connected, _) {
              return IconButton(
                icon: Icon(
                  connected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: connected ? const Color(0xFF00E5FF) : Colors.grey,
                ),
                onPressed: () {},
              );
            },
          ),
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF141822),
        selectedItemColor: const Color(0xFF00E5FF),
        unselectedItemColor: Colors.grey,
        items: _tabModules.map((m) {
          final capitalized = m.name[0].toUpperCase() + m.name.substring(1);
          return BottomNavigationBarItem(
            icon: Icon(m.icon),
            label: capitalized,
          );
        }).toList(),
      ),
    );
  }
}
