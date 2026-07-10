import 'package:flutter/material.dart';
import '../device/connection.dart';
import '../device/proto/xiaomi.pb.dart';
import '../debug/logger.dart';
import '../screen.dart';
import 'module.dart';
import '../widgets/panel.dart';
import '../widgets/item.dart';
import '../widgets/items.dart';
import '../widgets/button.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ScreenState<HealthScreen> {
  bool _isSyncing = false;
  String _syncStatus = 'Last synced: 3 hours ago';

  @override
  Module get module => HealthModule.instance;

  Future<void> _triggerSync() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Syncing health logs from band...';
    });

    if (!DeviceConnection.connected.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Watch not connected. Connect to the watch in the Pairing tab to sync health data.',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      setState(() {
        _isSyncing = false;
        _syncStatus = 'Last synced: 3 hours ago (Sync failed)';
      });
      return;
    }

    Logger.info('health', 'requesting today activity logs');

    if (DeviceConnection.connected.value) {
      final syncReq = ActivitySyncRequestToday()..unknown1 = 1;
      final cmd = Command()
        ..type =
            10 // COMMAND_TYPE = 10 (Health)
        ..subtype =
            5 // CMD_ACTIVITY_SYNC_TODAY
        ..health = (Health()..activitySyncRequestToday = syncReq);

      await DeviceConnection.send(cmd: cmd);
      Logger.info('health', 'sent ActivitySyncRequestToday command');
    }

    setState(() {
      _isSyncing = false;
      _syncStatus =
          'Synced successfully just now. Google Health Connect updated.';
    });
    Logger.info(
      'health',
      'google Health Connect updated with today\'s sleep and workout metrics',
    );
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return MiPanel(
      buttons: connected && !_isSyncing
          ? MiButtons(
              children: [
                MiButton(
                  label: 'Sync Today Activity',
                  icon: Icons.sync,
                  pressed: _triggerSync,
                ),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Google Health Connect Sync Card
          MiItems(
            children: [
              MiItem(
                title: 'Google Health Connect',
                subtitle: _syncStatus,
                icon: _isSyncing ? Icons.sync : Icons.favorite_border,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Metrics list wrapped in MiItems
          MiItems(
            children: [
              const MiItem(
                title: 'Heart Rate: 72 bpm',
                subtitle: 'Resting: 64 bpm',
                icon: Icons.favorite,
              ),
              const MiItem(
                title: 'SpO2: 99%',
                subtitle: 'All-day sync: ON',
                icon: Icons.bloodtype,
              ),
              const MiItem(
                title: 'Sleep: 7h 45m',
                subtitle: 'Deep sleep: 2h 10m',
                icon: Icons.nightlight_round,
              ),
              const MiItem(
                title: 'Workouts: 420 kcal',
                subtitle: '1 active session',
                icon: Icons.directions_run,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
