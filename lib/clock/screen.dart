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
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (time != null) {
      module.createAlarm(time.hour, time.minute);
    }
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return ListenableBuilder(
      listenable: AlarmsBlob.instance,
      builder: (context, _) {
        final customAlarms = AlarmsBlob.list;
        final bool canAdd = customAlarms.length < 9;

        return MiPanel(
          buttons: connected
              ? MiButtons(
                  children: [
                    MiButton(
                      label: 'Add Alarm',
                      icon: Icons.add_alarm,
                      pressed: canAdd ? _createAlarm : () {},
                      color: canAdd ? null : Colors.grey,
                    ),
                  ],
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<Alarm?>(
                valueListenable: ClockModule.phoneNextAlarm,
                builder: (context, phoneNextAlarm, _) {
                  final String phoneNextAlarmString = phoneNextAlarm != null
                      ? phoneNextAlarm.timeString
                      : 'None Scheduled';

                  return MiItems(
                    children: [
                      MiItem(
                        title: 'Phone System Alarm Slot',
                        subtitle: 'Next scheduled: $phoneNextAlarmString',
                        icon: Icons.alarm_on,
                        enabled: phoneNextAlarm != null,
                        toggled: null, // Read-only mirror of phone state
                      ),
                    ],
                  );
                },
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
                    return MiItem(
                      title: alarm.timeString,
                      subtitle: 'Watch Alarm ${alarm.id}',
                      delete: () => module.deleteAlarm(alarm.id),
                      enabled: alarm.enabled,
                      toggled: connected
                          ? (enabled) {
                              module.setAlarmEnabled(alarm.id, enabled);
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
  }
}
