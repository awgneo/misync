import 'package:flutter/material.dart';
import '../screen.dart';
import 'module.dart';
import 'blobs/alarms.dart';
import '../widgets/panel.dart';
import '../widgets/item.dart';
import '../widgets/items.dart';
import '../widgets/button.dart';

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

            return MiPanel(
              buttons: connected
                  ? MiButtons(
                      children: [
                        MiButton(
                          label: 'Add Alarm',
                          icon: Icons.add_alarm,
                          pressed: _createAlarm,
                        ),
                      ],
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MiItems(
                    children: [
                      MiItem(
                        title: 'Phone System Alarm Slot',
                        subtitle: 'Next scheduled: $sysTimeStr',
                        icon: Icons.alarm_on,
                        enabled: systemAlarm != null,
                        toggled: null, // Read-only mirror of phone state
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (customAlarms.isEmpty)
                    Container(
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
                  else
                    MiItems(
                      children: customAlarms.map((alarm) {
                        final hour = alarm.hour;
                        final min = alarm.minute;
                        final enabled = alarm.enabled;
                        final timeStr =
                            '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';

                        return MiItem(
                          title: timeStr,
                          subtitle: 'Watch Alarm ${alarm.id}',
                          delete: () => module.deleteAlarm(alarm.id),
                          enabled: enabled,
                          toggled: connected
                              ? (val) {
                                  ClockModule.instance.toggleAlarm(
                                    alarm.id,
                                    val,
                                  );
                                }
                              : null,
                        );
                      }).toList(),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
