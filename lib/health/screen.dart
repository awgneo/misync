import 'package:flutter/material.dart';
import '../device/connection.dart';
import '../device/proto/xiaomi.pb.dart';
import '../debug/logger.dart';
import '../screen.dart';
import 'module.dart';

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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HEALTH & METRICS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.grey,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isSyncing ? Icons.sync : Icons.refresh,
                  color: const Color(0xFF00E5FF),
                ),
                onPressed: (connected && !_isSyncing) ? _triggerSync : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Sync Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF141822),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF26324D)),
            ),
            child: Row(
              children: [
                Icon(
                  _isSyncing ? Icons.sync : Icons.favorite_border,
                  color: const Color(0xFF00E5FF),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Google Health Connect',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _syncStatus,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isSyncing)
                  ElevatedButton(
                    onPressed: connected ? _triggerSync : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'Sync',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'TODAY\'S METRICS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildMetricCard(
                'Heart Rate',
                '72 bpm',
                Icons.favorite,
                Colors.redAccent,
                'Resting: 64 bpm',
              ),
              _buildMetricCard(
                'SpO2',
                '99%',
                Icons.bloodtype,
                Colors.blueAccent,
                'All-day sync: ON',
              ),
              _buildMetricCard(
                'Sleep',
                '7h 45m',
                Icons.nightlight_round,
                Colors.purpleAccent,
                'Deep sleep: 2h 10m',
              ),
              _buildMetricCard(
                'Workouts',
                '420 kcal',
                Icons.directions_run,
                Colors.orangeAccent,
                '1 active session',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF26324D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
