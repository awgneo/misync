import 'package:flutter/material.dart';
import '../debug/logger.dart';
import 'blobs/actions.dart';
import '../screen.dart';
import 'module.dart';

class ActionsScreen extends StatefulWidget {
  const ActionsScreen({super.key});

  @override
  State<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends ScreenState<ActionsScreen> {
  final _nameController = TextEditingController();
  final _intentController = TextEditingController();

  @override
  Module get module => ActionsModule.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _intentController.dispose();
    super.dispose();
  }

  void _testTriggerAction(String id, String name, String intent) {
    Logger.info(
      'actions',
      'local trigger: Running action "$name" with intent target $intent',
    );
    ActionsModule.instance.triggerActionById(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Triggered "$name" successfully!'),
        backgroundColor: const Color(0xFF00E5FF),
      ),
    );
  }

  void _showAddActionDialog() {
    _nameController.clear();
    _intentController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141822),
          title: const Text(
            'Add Shortcut Action',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Action Name',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF26324D)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _intentController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Android Intent Action',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF26324D)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                final name = _nameController.text.trim();
                final intent = _intentController.text.trim();
                if (name.isNotEmpty && intent.isNotEmpty) {
                  final updated =
                      List<Map<String, String>>.from(ActionsBlob.list)..add({
                        'id': (ActionsBlob.list.length + 1).toString(),
                        'name': name,
                        'intent': intent,
                        'package': intent.contains('.')
                            ? intent.split('.').first
                            : 'custom.action',
                      });
                  ActionsBlob.instance.update(updated);
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Add',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteAction(Map<String, String> action) {
    final updated = List<Map<String, String>>.from(ActionsBlob.list)
      ..remove(action);
    ActionsBlob.instance.update(updated);
  }

  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return ListenableBuilder(
      listenable: ActionsBlob.instance,
      builder: (context, _) {
        final actions = ActionsBlob.list;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'WATCH ACTIONS SHORTCUTS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_to_photos,
                      color: Color(0xFF00E5FF),
                    ),
                    onPressed: connected ? _showAddActionDialog : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: actions.isEmpty
                    ? const SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        child: Center(
                          heightFactor: 5,
                          child: Text(
                            'No shortcut actions configured yet.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: actions.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.85,
                            ),
                        itemBuilder: (context, index) {
                          final action = actions[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141822),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF26324D),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF00E5FF,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'ID: ${action['id']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF00E5FF),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 18,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: connected
                                          ? () => _deleteAction(action)
                                          : null,
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  action['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (action['intent'] ?? '').split('.').last,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 36,
                                  child: ElevatedButton(
                                    onPressed: () => _testTriggerAction(
                                      action['id'] ?? '',
                                      action['name'] ?? '',
                                      action['intent'] ?? '',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00E5FF),
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Test Run',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
