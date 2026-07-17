import 'package:flutter/material.dart';
import 'module.dart';
import 'blobs/health.dart';
import '../screen.dart';
import '../widgets/panel.dart';
import '../widgets/items.dart';
import '../widgets/item.dart';
import '../widgets/popup.dart';

class HealthScreen extends Screen<HealthModule> {
  const HealthScreen(super.module, {super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ScreenState<HealthScreen> {
  Future<void> _selectBirthday(
    BuildContext context,
    Health currentSettings,
  ) async {
    final birthYear =
        int.tryParse(currentSettings.birthday.substring(0, 4)) ?? 1995;
    final birthMonth =
        int.tryParse(currentSettings.birthday.substring(4, 6)) ?? 1;
    final birthDay =
        int.tryParse(currentSettings.birthday.substring(6, 8)) ?? 1;

    final initialDate = DateTime(birthYear, birthMonth, birthDay);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00E5FF),
              onPrimary: Colors.black,
              surface: Color(0xFF141822),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final y = pickedDate.year.toString();
      final m = pickedDate.month.toString().padLeft(2, '0');
      final d = pickedDate.day.toString().padLeft(2, '0');
      final newBirthday = '$y$m$d';

      final newSettings = currentSettings.copyWith(birthday: newBirthday);
      await widget.module.saveHealth(newSettings);
    }
  }

  Future<void> _editGoalDialog({
    required String title,
    required int initialValue,
    required String suffix,
    required ValueChanged<int> onSave,
  }) async {
    final result = await MiPopup.show<int>(
      context,
      title: 'Edit $title',
      child: _GoalSetupSheet(
        title: title,
        initialValue: initialValue,
        suffix: suffix,
      ),
    );

    if (result != null) {
      onSave(result);
    }
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return ListenableBuilder(
      listenable: HealthBlob.instance,
      builder: (context, _) {
        final currentSettings = HealthBlob.settings;
        final isEnabled = currentSettings.enabled;

        final String heightStr;
        final String weightStr;

        if (currentSettings.height > 0) {
          if (currentSettings.imperial) {
            final totalInches = currentSettings.height / 2.54;
            final feet = totalInches ~/ 12;
            final inches = (totalInches % 12).round();
            heightStr = '$feet\' $inches"';
          } else {
            heightStr = '${currentSettings.height.toStringAsFixed(1)} cm';
          }
        } else {
          heightStr = '--';
        }

        if (currentSettings.weight > 0) {
          if (currentSettings.imperial) {
            final weightLbs = currentSettings.weight * 2.20462;
            weightStr = '${weightLbs.toStringAsFixed(1)} lbs';
          } else {
            weightStr = '${currentSettings.weight.toStringAsFixed(1)} kg';
          }
        } else {
          weightStr = '--';
        }

        return MiPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MiItems(
                children: [
                  MiItem(
                    title: 'Health Sync',
                    subtitle: 'Sync watch health data to Health Connect',
                    primaryIcon: Icons.favorite,
                    enabled: isEnabled,
                    toggled: (value) async {
                      final newSettings = currentSettings.copyWith(
                        enabled: value,
                      );
                      await widget.module.saveHealth(newSettings);
                    },
                  ),
                  MiItem(
                    title: 'Imperial Units',
                    subtitle: 'Display weight in lbs and height in feet/inches',
                    primaryIcon: Icons.straighten,
                    enabled: currentSettings.imperial,
                    toggled: (value) async {
                      final newSettings = currentSettings.copyWith(
                        imperial: value,
                      );
                      await widget.module.saveHealth(newSettings);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              MiItems(
                children: [
                  // Height (Read-only from Health Connect)
                  MiItem(
                    title: 'Height',
                    subtitle: '$heightStr (from Health Connect)',
                    primaryIcon: Icons.height,
                  ),

                  // Weight (Read-only from Health Connect)
                  MiItem(
                    title: 'Weight',
                    subtitle: '$weightStr (from Health Connect)',
                    primaryIcon: Icons.monitor_weight,
                  ),

                  // Birthday Picker
                  MiItem(
                    title: 'Date of Birth',
                    subtitle: _formatBirthday(currentSettings.birthday),
                    primaryIcon: Icons.cake,
                    clicked: () => _selectBirthday(context, currentSettings),
                  ),

                  // Gender Selector
                  MiItem(
                    title: 'Gender',
                    subtitle: currentSettings.gender == 1 ? 'Male' : 'Female',
                    primaryIcon: Icons.wc,
                    clicked: () async {
                      final nextGender = currentSettings.gender == 1 ? 2 : 1;
                      final newSettings = currentSettings.copyWith(
                        gender: nextGender,
                      );
                      await widget.module.saveHealth(newSettings);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              MiItems(
                children: [
                  MiItem(
                    title: 'Steps Goal',
                    subtitle: '${currentSettings.goals.steps} steps',
                    primaryIcon: Icons.directions_walk,
                    clicked: () => _editGoalDialog(
                      title: 'Steps Goal',
                      initialValue: currentSettings.goals.steps,
                      suffix: 'steps',
                      onSave: (val) async {
                        final newGoals = currentSettings.goals.copyWith(
                          steps: val,
                        );
                        await widget.module.saveHealth(
                          currentSettings.copyWith(goals: newGoals),
                        );
                      },
                    ),
                  ),
                  MiItem(
                    title: 'Active Calories Goal',
                    subtitle: '${currentSettings.goals.calories} kcal',
                    primaryIcon: Icons.local_fire_department,
                    clicked: () => _editGoalDialog(
                      title: 'Active Calories Goal',
                      initialValue: currentSettings.goals.calories,
                      suffix: 'kcal',
                      onSave: (val) async {
                        final newGoals = currentSettings.goals.copyWith(
                          calories: val,
                        );
                        await widget.module.saveHealth(
                          currentSettings.copyWith(goals: newGoals),
                        );
                      },
                    ),
                  ),
                  MiItem(
                    title: 'Standing Goal',
                    subtitle: '${currentSettings.goals.standing} hours',
                    primaryIcon: Icons.accessibility_new,
                    clicked: () => _editGoalDialog(
                      title: 'Standing Goal',
                      initialValue: currentSettings.goals.standing,
                      suffix: 'hours',
                      onSave: (val) async {
                        final newGoals = currentSettings.goals.copyWith(
                          standing: val,
                        );
                        await widget.module.saveHealth(
                          currentSettings.copyWith(goals: newGoals),
                        );
                      },
                    ),
                  ),
                  MiItem(
                    title: 'Active Time Goal',
                    subtitle: '${currentSettings.goals.moving} minutes',
                    primaryIcon: Icons.timer,
                    clicked: () => _editGoalDialog(
                      title: 'Active Time Goal',
                      initialValue: currentSettings.goals.moving,
                      suffix: 'min',
                      onSave: (val) async {
                        final newGoals = currentSettings.goals.copyWith(
                          moving: val,
                        );
                        await widget.module.saveHealth(
                          currentSettings.copyWith(goals: newGoals),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatBirthday(String birthday) {
    if (birthday.length != 8) return birthday;
    final year = birthday.substring(0, 4);
    final month = birthday.substring(4, 6);
    final day = birthday.substring(6, 8);

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final mIdx = int.tryParse(month);
    final mString = (mIdx != null && mIdx >= 1 && mIdx <= 12)
        ? months[mIdx - 1]
        : month;

    return '$mString $day, $year';
  }
}

class _GoalSetupSheet extends StatefulWidget {
  final String title;
  final int initialValue;
  final String suffix;

  const _GoalSetupSheet({
    required this.title,
    required this.initialValue,
    required this.suffix,
  });

  @override
  State<_GoalSetupSheet> createState() => _GoalSetupSheetState();
}

class _GoalSetupSheetState extends State<_GoalSetupSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            suffixText: ' ${widget.suffix}',
            suffixStyle: const TextStyle(color: Colors.grey),
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
        ),
        const SizedBox(height: 24),
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
                  final parsed = int.tryParse(_controller.text);
                  if (parsed != null && parsed > 0) {
                    Navigator.of(context).pop(parsed);
                  } else {
                    Navigator.of(context).pop();
                  }
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
    );
  }
}
