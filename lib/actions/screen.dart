import 'package:flutter/material.dart' hide Action;
import 'blobs/actions.dart';
import '../screen.dart';
import 'module.dart';
import '../widgets/panel.dart';
import '../widgets/item.dart';
import '../widgets/items.dart';
import '../widgets/button.dart';
import '../widgets/modal.dart';
import '../widgets/picker.dart';

class ActionsScreen extends Screen<ActionsModule> {
  const ActionsScreen(super.module, {super.key});

  @override
  State<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends ScreenState<ActionsScreen> {
  void _testAction(Action action) {
    widget.module.runAction(action);
  }

  Future<void> _addAction() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ActionSetupSheet(),
    );

    if (result != null) {
      widget.module.addAction(
        Action(
          name: result['name'] as String,
          intent: result['intent'] as String,
          package: result['package'] as String,
          uri: result['uri'] as String?,
          extras: result['extras'] as Map<String, String>?,
          icon: result['icon'] as String,
        ),
      );
    }
  }

  Future<void> _editAction(Action action) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ActionSetupSheet(action: action),
    );

    if (result != null) {
      widget.module.editAction(
        action.name,
        Action(
          name: result['name'] as String,
          intent: result['intent'] as String,
          package: result['package'] as String,
          uri: result['uri'] as String?,
          extras: result['extras'] as Map<String, String>?,
          icon: result['icon'] as String,
        ),
      );
    }
  }

  void _deleteAction(String name) async {
    final confirm = await showMiModal<bool>(
      context: context,
      title: 'Delete Shortcut Action?',
      body: 'Are you sure you want to delete the shortcut action "$name"?',
      confirm: 'Delete',
      cancel: 'Cancel',
    );

    if (confirm == true) {
      widget.module.deleteAction(name);
    }
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
                      pressed: _addAction,
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
                      primaryIcon: Text(action.icon, style: const TextStyle(fontSize: 20)),
                      delete: connected ? () => _deleteAction(nameKey) : null,
                      clicked: connected ? () => _editAction(action) : null,
                      order: connected
                          ? InkWell(
                              onTap: () => _testAction(action),
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.play_arrow,
                                  color: Color(0xFF00E5FF),
                                  size: 22,
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

class _ActionSetupSheet extends StatefulWidget {
  final Action? action;
  const _ActionSetupSheet({this.action});

  @override
  State<_ActionSetupSheet> createState() => _ActionSetupSheetState();
}

class _ActionSetupSheetState extends State<_ActionSetupSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _uriController;
  late final TextEditingController _intentController;
  late final TextEditingController _packageController;
  late final TextEditingController _extrasController;
  late final TextEditingController _iconController;

  int _typeSelection =
      0; // 0: Launch App, 1: Deep Link / URL, 2: Custom Intent / Tasker
  String _selectedPackage = '';
  String _selectedAppName = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.action?.name ?? '');
    _nameController.addListener(_onNameChanged);
    _iconController = TextEditingController(text: widget.action?.icon ?? '⚡');
    _iconController.addListener(_onIconChanged);
    _uriController = TextEditingController(text: widget.action?.uri ?? '');
    _intentController = TextEditingController(
      text: widget.action?.intent ?? '',
    );
    _packageController = TextEditingController(
      text: widget.action?.package ?? '',
    );

    final extrasBuf = StringBuffer();
    widget.action?.extras?.forEach((k, v) {
      if (k != 'task_name') {
        extrasBuf.writeln('$k=$v');
      }
    });
    _extrasController = TextEditingController(text: extrasBuf.toString());

    if (widget.action != null) {
      final a = widget.action!;
      if (a.intent == 'android.intent.action.MAIN') {
        _typeSelection = 0;
        _selectedPackage = a.package;
        _selectedAppName = a.package.split('.').last.toUpperCase();
      } else if (a.intent == 'android.intent.action.VIEW') {
        _typeSelection = 1;
      } else {
        _typeSelection = 2;
      }
    }
  }

  void _onNameChanged() {
    setState(() {});
  }

  void _onIconChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _iconController.removeListener(_onIconChanged);
    _iconController.dispose();
    _uriController.dispose();
    _intentController.dispose();
    _packageController.dispose();
    _extrasController.dispose();
    super.dispose();
  }

  void _pickApp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MiPicker(
          registeredFilters: const [],
          onAppSelected: (package) {
            setState(() {
              _selectedPackage = package;
              _selectedAppName = package.split('.').last.toUpperCase();
            });
          },
        );
      },
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    String intent = '';
    String package = '';
    String? uri;
    Map<String, String>? extras;

    if (_typeSelection == 0) {
      if (_selectedPackage.isEmpty) {
        showMiModal<bool>(
          context: context,
          title: 'App Required',
          body: 'Please select an application to launch.',
          confirm: 'OK',
        );
        return;
      }
      intent = 'android.intent.action.MAIN';
      package = _selectedPackage;
    } else if (_typeSelection == 1) {
      intent = 'android.intent.action.VIEW';
      uri = _uriController.text.trim();
      if (uri.isEmpty) return;
    } else {
      intent = _intentController.text.trim();
      package = _packageController.text.trim();
      if (intent.isEmpty) return;

      final lines = _extrasController.text.split('\n');
      final Map<String, String> parsedExtras = {};
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final index = line.indexOf('=');
        if (index != -1) {
          final k = line.substring(0, index).trim();
          final v = line.substring(index + 1).trim();
          if (k.isNotEmpty) {
            parsedExtras[k] = v;
          }
        }
      }
      if (parsedExtras.isNotEmpty) {
        extras = parsedExtras;
      }
    }

    Navigator.of(context).pop({
      'name': name,
      'intent': intent,
      'package': package,
      'uri': uri,
      'extras': extras,
      'icon': _iconController.text.trim().isNotEmpty ? _iconController.text.trim() : '⚡',
    });
  }

  @override
  Widget build(BuildContext context) {
    final previewTitle = _nameController.text.trim().isEmpty
        ? (widget.action != null ? widget.action!.name : 'New Action')
        : _nameController.text.trim();

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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.action != null
                      ? 'Edit Shortcut Action'
                      : 'Add Shortcut Action',
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

            // VISUAL PREVIEW CARD
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF141822),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF26324D)),
              ),
              child: Column(
                children: [
                  Text(
                    _iconController.text.trim().isEmpty ? '⚡' : _iconController.text.trim(),
                    style: const TextStyle(fontSize: 36),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    previewTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _typeSelection == 0
                        ? 'App Launch Trigger'
                        : _typeSelection == 1
                        ? 'Deep Link Trigger'
                        : 'Intent Trigger',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Action Label (e.g. Mute Phone)',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF141822),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF26324D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF26324D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _iconController,
              maxLength: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Emoji Icon (e.g. ⚙️, 📷, 📍)',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF141822),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF26324D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF26324D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter an emoji icon';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Action Trigger Type',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: _typeSelection,
              dropdownColor: const Color(0xFF0F111A),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF141822),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF26324D)),
                ),
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
                  child: Text(
                    'Launch App',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                DropdownMenuItem(
                  value: 1,
                  child: Text(
                    'Open Deep Link / URL',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                DropdownMenuItem(
                  value: 2,
                  child: Text(
                    'Custom Intent / Tasker',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _typeSelection = val;
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            if (_typeSelection == 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141822),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF26324D)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Target Application',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedPackage.isEmpty
                                ? 'None Selected'
                                : _selectedAppName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (_selectedPackage.isNotEmpty)
                            Text(
                              _selectedPackage,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _pickApp,
                      child: const Text('Pick App'),
                    ),
                  ],
                ),
              ),
            ] else if (_typeSelection == 1) ...[
              TextFormField(
                controller: _uriController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Deep Link Link / URL (e.g. spotify:play)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF141822),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF26324D)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF26324D)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
                validator: (val) {
                  if (_typeSelection == 1 &&
                      (val == null || val.trim().isEmpty)) {
                    return 'Please enter a URL / deep link';
                  }
                  return null;
                },
              ),
            ] else ...[
              TextFormField(
                controller: _intentController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText:
                      'Intent Action (e.g. net.dinglisch.android.taskerm.ACTION_TASK)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF141822),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF26324D)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF26324D)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
                validator: (val) {
                  if (_typeSelection == 2 &&
                      (val == null || val.trim().isEmpty)) {
                    return 'Please enter an intent action';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _packageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Target Package Name (Optional)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF141822),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF26324D)),
                  ),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _extrasController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Intent Extras (Key=Value, one per line)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF141822),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF26324D)),
                  ),
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
            ],

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
                    onPressed: _save,
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
      ),
    );
  }
}
