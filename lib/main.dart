import 'package:flutter/material.dart';
import 'device/module.dart';
import 'notifications/module.dart';
import 'faces/module.dart';
import 'health/module.dart';
import 'actions/module.dart';
import 'finance/module.dart';
import 'debug/module.dart';
import 'storage/module.dart';
import 'platform/module.dart';
import 'clock/module.dart';
import 'apps/module.dart';
import 'calendar/module.dart';
import 'weather/module.dart';
import 'media/module.dart';
import 'wallet/module.dart';
import 'module.dart';

final List<Module> modules = [
  StorageModule.module,
  PlatformModule.module,
  DeviceModule.module,
  ClockModule.module,
  AppsModule.module,
  CalendarModule.module,
  WeatherModule.module,
  MediaModule.module,
  NotificationModule.module,
  FacesModule.module,
  HealthModule.module,
  ActionsModule.module,
  FinanceModule.module,
  WalletModule.module,
  DebugModule.module,
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
  void initState() {
    super.initState();
    final deviceIndex = _tabModules.indexWhere((m) => m.name == 'device');
    if (deviceIndex != -1) {
      _currentIndex = deviceIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = _tabModules.map((m) => m.screen).toList();
    final activeModule = _tabModules[_currentIndex];
    final activeModuleName =
        activeModule.name[0].toUpperCase() + activeModule.name.substring(1);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF00E5FF)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        title: Row(
          children: [
            const Text(
              'MiSync',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5FF),
              ),
            ),
            const Text(' • ', style: TextStyle(color: Colors.grey)),
            Text(
              activeModuleName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F1219),
        elevation: 0,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: DeviceModule.module.connection.connected,
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
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F111A),
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _tabModules.length,
            itemBuilder: (context, index) {
              final m = _tabModules[index];
              final capitalized = m.name[0].toUpperCase() + m.name.substring(1);
              final isSelected = index == _currentIndex;
              return ListTile(
                leading: Icon(
                  m.icon,
                  color: isSelected ? const Color(0xFF00E5FF) : Colors.grey,
                ),
                title: Text(
                  capitalized,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedTileColor: const Color(
                  0xFF00E5FF,
                ).withValues(alpha: 0.1),
                onTap: () {
                  setState(() {
                    _currentIndex = index;
                  });
                  Navigator.pop(context); // Close the drawer
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
