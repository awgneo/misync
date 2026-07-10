import 'package:flutter/material.dart' hide Action;
import '../debug/logger.dart';
import 'blobs/actions.dart';
import '../screen.dart';
import 'module.dart';
import '../widgets/panel.dart';
import '../widgets/item.dart';
import '../widgets/items.dart';
import '../widgets/button.dart';
import '../widgets/modal.dart';

class ActionsScreen extends StatefulWidget {
  const ActionsScreen({super.key});

  @override
  State<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends ScreenState<ActionsScreen> {
  @override
  Module get module => ActionsModule.instance;

  void _testTriggerAction(Action action) {
    Logger.info(
      'actions',
      'local trigger: Running action "${action.name}" with intent target ${action.intent}',
    );
    ActionsModule.instance.triggerAction(action);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Triggered "${action.name}" successfully!'),
        backgroundColor: const Color(0xFF00E5FF),
      ),
    );
  }

  void _showAddActionDialog() async {
    final name = await showMiTextModal(
      context: context,
      title: 'Add Shortcut Action',
      labelText: 'Shortcut Name (e.g. Open Map)',
    );
    if (name == null || name.isEmpty) return;

    if (!mounted) return;
    final intent = await showMiTextModal(
      context: context,
      title: 'Action Android Intent',
      labelText: 'Intent Action or Package Name',
    );
    if (intent == null || intent.isEmpty) return;

    final updated = Map<String, Action>.from(ActionsBlob.map)
      ..[name] = Action(
        name: name,
        intent: intent,
        package: intent.contains('.')
            ? intent.split('.').first
            : 'custom.action',
      );
    ActionsBlob.instance.update(updated);
  }

  void _deleteAction(String name) {
    final updated = Map<String, Action>.from(ActionsBlob.map)
      ..remove(name);
    ActionsBlob.instance.update(updated);
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return ListenableBuilder(
      listenable: ActionsBlob.instance,
      builder: (context, _) {
        final actions = ActionsBlob.map.entries.toList();

        return MiPanel(
          buttons: connected
              ? MiButtons(
                  children: [
                    MiButton(
                      label: 'Add Action',
                      icon: Icons.add_to_photos,
                      pressed: _showAddActionDialog,
                    ),
                  ],
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (actions.isEmpty)
                Container(
                  height: 150,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141822),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF26324D)),
                  ),
                  child: const Text(
                    'No shortcut actions configured yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                MiItems(
                  children: actions.map((entry) {
                    final nameKey = entry.key;
                    final action = entry.value;

                    return MiItem(
                      title: action.name,
                      subtitle: action.intent,
                      icon: Icons.flash_on,
                      delete: connected ? () => _deleteAction(nameKey) : null,
                      order: connected
                          ? ElevatedButton.icon(
                              onPressed: () => _testTriggerAction(action),
                              icon: const Icon(Icons.play_arrow, size: 14, color: Colors.black),
                              label: const Text(
                                'Test',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E5FF),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            )
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
