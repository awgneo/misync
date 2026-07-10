import 'package:flutter/material.dart';
import '../screen.dart';
import 'module.dart';
import 'blobs/alarms.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends ScreenState<ClockScreen> {
  @override
  ClockModule get module => ClockModule.instance;

  Future<void> _createAlarm() async {
    final customAlarms = AlarmsBlob.list;
    if (customAlarms.length >= 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum watch alarm slots (Slots 2-10) reached.'),
        ),
      );
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (time != null) {
      ClockModule.instance.createAlarm(time.hour, time.minute);
    }
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return ValueListenableBuilder<Map<String, int>?>(
      valueListenable: ClockModule.nextSystemAlarm,
      builder: (context, systemAlarm, _) {
        final String sysTimeStr = systemAlarm != null
            ? '${systemAlarm['hour'].toString().padLeft(2, '0')}:${systemAlarm['minute'].toString().padLeft(2, '0')}'
            : 'None Scheduled';

        return ListenableBuilder(
          listenable: AlarmsBlob.instance,
          builder: (context, _) {
            final customAlarms = AlarmsBlob.list;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                // 1. System Alarm Section
                const Text(
                  'PHONE ALARM MIRRORING',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
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
                        Icons.alarm_on,
                        color: Color(0xFF00E5FF),
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Phone System Alarm Slot',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Next scheduled: $sysTimeStr',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // System Alarm (Slot 1) toggle status
                      Switch(
                        value: systemAlarm != null,
                        activeThumbColor: const Color(0xFF00E5FF),
                        activeTrackColor: const Color(
                          0xFF00E5FF,
                        ).withValues(alpha: 0.3),
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                        onChanged: null, // read-only mirror of phone state
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Custom Watch Alarms Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CUSTOM WATCH ALARMS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.grey,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_alarm,
                        color: Color(0xFF00E5FF),
                      ),
                      onPressed: _createAlarm,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Alarm list container
                customAlarms.isEmpty
                    ? Container(
                        height: 150,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141822),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF26324D)),
                        ),
                        child: const Text(
                          'No custom alarms on watch yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : Material(
                        color: const Color(0xFF141822),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF26324D)),
                        ),
                        child: Column(
                          children: customAlarms.asMap().entries.map((entry) {
                            final index = entry.key;
                            final alarm = entry.value;
                            final hour = alarm.hour;
                            final min = alarm.minute;
                            final enabled = alarm.enabled;
                            final timeStr =
                                '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';

                            final item = SwitchListTile(
                              value: enabled,
                              onChanged: connected
                                  ? (val) {
                                      ClockModule.instance.toggleAlarm(
                                        alarm.id,
                                        val,
                                      );
                                    }
                                  : null,
                              title: Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                'Watch Alarm ${alarm.id}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              activeThumbColor: const Color(0xFF00E5FF),
                              activeTrackColor: const Color(
                                0xFF00E5FF,
                              ).withValues(alpha: 0.3),
                              inactiveThumbColor: Colors.grey,
                              inactiveTrackColor: Colors.grey.withValues(
                                alpha: 0.3,
                              ),
                              secondary: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => module.deleteAlarm(alarm.id),
                              ),
                            );

                            if (index < customAlarms.length - 1) {
                              return Column(
                                children: [
                                  item,
                                  const Divider(
                                    color: Color(0xFF26324D),
                                    height: 1,
                                  ),
                                ],
                              );
                            }
                            return item;
                          }).toList(),
                        ),
                      ),
              ],
            );
          },
        );
      },
    );
  }
}
