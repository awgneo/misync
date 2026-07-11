import 'package:flutter/material.dart';
import '../screen.dart';
import 'module.dart';
import 'blobs/alarms.dart';
import '../widgets/panel.dart';
import '../widgets/item.dart';
import '../widgets/items.dart';
import '../widgets/button.dart';
import '../platform/module.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends ScreenState<ClockScreen> {
  @override
  ClockModule get module => ClockModule.instance;

  Future<void> _createAlarm() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AlarmSetupSheet(),
    );

    if (result != null) {
      final hour = result['hour'] as int;
      final minute = result['minute'] as int;
      final repeatMode = result['repeatMode'] as int;
      final repeatFlags = result['repeatFlags'] as int;
      final smart = result['smart'] as int;

      module.createAlarm(
        hour,
        minute,
        repeatMode: repeatMode,
        repeatFlags: repeatFlags,
        smart: smart,
      );
    }
  }

  Future<void> _editAlarm(WatchAlarm alarm) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AlarmSetupSheet(alarm: alarm),
    );

    if (result != null) {
      final hour = result['hour'] as int;
      final minute = result['minute'] as int;
      final repeatMode = result['repeatMode'] as int;
      final repeatFlags = result['repeatFlags'] as int;
      final smart = result['smart'] as int;

      module.editAlarm(
        alarm.id,
        hour,
        minute,
        enabled: alarm.enabled,
        repeatMode: repeatMode,
        repeatFlags: repeatFlags,
        smart: smart,
      );
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
                        title: 'Next Phone Alarm',
                        subtitle: 'Next scheduled: $phoneNextAlarmString',
                        primaryIcon: Icons.alarm_on,
                        enabled: phoneNextAlarm != null,
                        toggled: null, // Read-only mirror of phone state
                        clicked: () {
                          PlatformModule.instance.invokeMethod('launchAction', {
                            'intent': 'android.intent.action.SHOW_ALARMS',
                          });
                        },
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
                      subtitle: alarm.repeatString,
                      delete: () => module.deleteAlarm(alarm.id),
                      enabled: alarm.enabled,
                      toggled: connected
                          ? (enabled) {
                              module.setAlarmEnabled(alarm.id, enabled);
                            }
                          : null,
                      clicked: connected ? () => _editAlarm(alarm) : null,
                      secondaryIcon: alarm.smart == 1 ? Icons.psychology : null,
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

class _AlarmSetupSheet extends StatefulWidget {
  final WatchAlarm? alarm;
  const _AlarmSetupSheet({super.key, this.alarm});

  @override
  State<_AlarmSetupSheet> createState() => _AlarmSetupSheetState();
}

class _AlarmSetupSheetState extends State<_AlarmSetupSheet> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  int _repeatOption =
      0; // 0: Once, 1: Daily, 2: Weekdays, 3: Weekends, 4: Custom
  int _customFlags = 0; // Bitmask for custom days
  bool _smartWake = false;

  final List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    if (widget.alarm != null) {
      final a = widget.alarm!;
      _selectedTime = TimeOfDay(hour: a.hour, minute: a.minute);
      _smartWake = a.smart == 1;
      if (a.repeatMode == 0) {
        _repeatOption = 0;
      } else if (a.repeatMode == 1) {
        _repeatOption = 1;
      } else if (a.repeatMode == 5) {
        if (a.repeatFlags == 31) {
          _repeatOption = 2;
        } else if (a.repeatFlags == 96) {
          _repeatOption = 3;
        } else if (a.repeatFlags == 127) {
          _repeatOption = 1;
        } else {
          _repeatOption = 4;
          _customFlags = a.repeatFlags;
        }
      }
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int finalRepeatMode = 0;
    int finalRepeatFlags = 0;

    if (_repeatOption == 0) {
      finalRepeatMode = 0;
      finalRepeatFlags = 0;
    } else if (_repeatOption == 1) {
      finalRepeatMode = 1;
      finalRepeatFlags = 0;
    } else if (_repeatOption == 2) {
      finalRepeatMode = 5;
      finalRepeatFlags = 31; // Mon-Fri
    } else if (_repeatOption == 3) {
      finalRepeatMode = 5;
      finalRepeatFlags = 96; // Sat-Sun
    } else if (_repeatOption == 4) {
      finalRepeatMode = 5;
      finalRepeatFlags = _customFlags;
    }

    final period = _selectedTime.hour >= 12 ? 'PM' : 'AM';
    final displayHour = _selectedTime.hour == 0
        ? 12
        : (_selectedTime.hour > 12
              ? _selectedTime.hour - 12
              : _selectedTime.hour);
    final displayMin = _selectedTime.minute.toString().padLeft(2, '0');
    final formattedTime = '$displayHour:$displayMin $period';

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F111A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.alarm != null ? 'Edit Watch Alarm' : 'Add Watch Alarm',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF141822),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF26324D)),
              ),
              child: Column(
                children: [
                  Text(
                    formattedTime,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to change time',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Repeat Mode',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _repeatOption,
            dropdownColor: const Color(0xFF0F111A),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF141822),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF26324D)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00E5FF)),
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 0,
                child: Text('Once', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 1,
                child: Text('Daily', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 2,
                child: Text(
                  'Weekdays (Mon - Fri)',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              DropdownMenuItem(
                value: 3,
                child: Text(
                  'Weekends (Sat - Sun)',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              DropdownMenuItem(
                value: 4,
                child: Text(
                  'Custom Days...',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _repeatOption = val;
                });
              }
            },
          ),
          if (_repeatOption == 4) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final flagVal = 1 << index;
                final active = (_customFlags & flagVal) != 0;
                return _DayToggle(
                  label: _dayLabels[index],
                  active: active,
                  onTap: () {
                    setState(() {
                      _customFlags ^= flagVal;
                    });
                  },
                );
              }),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Wake',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Wakes you up during light sleep',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              Switch(
                value: _smartWake,
                onChanged: (val) {
                  setState(() {
                    _smartWake = val;
                  });
                },
                activeThumbColor: const Color(0xFF00E5FF),
                activeTrackColor: const Color(
                  0xFF00E5FF,
                ).withValues(alpha: 0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF141822),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF26324D)),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF00E5FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop({
                      'hour': _selectedTime.hour,
                      'minute': _selectedTime.minute,
                      'repeatMode': finalRepeatMode,
                      'repeatFlags': finalRepeatFlags,
                      'smart': _smartWake ? 1 : 2,
                    });
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DayToggle({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? const Color(0xFF00E5FF) : Colors.transparent,
          border: Border.all(
            color: active ? const Color(0xFF00E5FF) : const Color(0xFF26324D),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
