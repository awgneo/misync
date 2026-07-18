import 'package:flutter/material.dart' hide Action;
import 'blobs/actions.dart';
import '../screen.dart';
import 'module.dart';
import '../widgets/panel.dart';
import '../widgets/item.dart';
import '../widgets/items.dart';
import '../widgets/button.dart';
import '../widgets/modal.dart';
import '../widgets/app.dart';
import '../widgets/symbol.dart';
import '../widgets/popup.dart';

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
    final result = await MiPopup.show<Map<String, dynamic>>(
      context,
      title: 'Add Action',
      child: const _ActionSetupSheet(),
    );

    if (result != null) {
      widget.module.addAction(
        Action(
          name: result['name'] as String,
          intent: result['intent'] as String,
          package: result['package'] as String,
          uri: result['uri'] as String?,
          extras: result['extras'] as Map<String, String>?,
          symbol: result['symbol'] as String,
        ),
      );
    }
  }

  Future<void> _editAction(Action action) async {
    final result = await MiPopup.show<Map<String, dynamic>>(
      context,
      title: 'Edit Action',
      child: _ActionSetupSheet(action: action),
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
          symbol: result['symbol'] as String,
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
                      primaryIcon: Text(
                        action.symbol,
                        style: const TextStyle(
                          fontFamily: 'Material',
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      ),
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

class _ExtraRow {
  final TextEditingController keyController;
  final TextEditingController valueController;

  _ExtraRow({String key = '', String value = ''})
      : keyController = TextEditingController(text: key),
        valueController = TextEditingController(text: value);

  void dispose() {
    keyController.dispose();
    valueController.dispose();
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
  final List<_ExtraRow> _extraRows = [];
  late final TextEditingController _symbolController;

  int _typeSelection =
      0; // 0: Launch App, 1: Deep Link / URL, 2: Custom Intent / Tasker
  String _selectedPackage = '';
  String _selectedAppName = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.action?.name ?? '');
    _nameController.addListener(_onNameChanged);
    _symbolController = TextEditingController(
      text: widget.action?.symbol ?? 'bolt',
    );
    _symbolController.addListener(_onSymbolChanged);
    _uriController = TextEditingController(text: widget.action?.uri ?? '');
    _intentController = TextEditingController(
      text: widget.action?.intent ?? '',
    );
    _packageController = TextEditingController(
      text: widget.action?.package ?? '',
    );

    widget.action?.extras?.forEach((k, v) {
      if (k != 'task_name') {
        _extraRows.add(_ExtraRow(key: k, value: v));
      }
    });

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

  void _onSymbolChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _symbolController.removeListener(_onSymbolChanged);
    _symbolController.dispose();
    _uriController.dispose();
    _intentController.dispose();
    _packageController.dispose();
    for (final row in _extraRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _pickApp() {
    MiPopup.show(
      context,
      title: 'Select App',
      child: MiApp(
        removed: _selectedPackage.isNotEmpty ? [_selectedPackage] : const [],
        selected: (package) {
          setState(() {
            _selectedPackage = package;
            _selectedAppName = package.split('.').last.toUpperCase();
          });
        },
      ),
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

      final Map<String, String> parsedExtras = {};
      for (final row in _extraRows) {
        final k = row.keyController.text.trim();
        final v = row.valueController.text.trim();
        if (k.isNotEmpty) {
          parsedExtras[k] = v;
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
      'symbol': _symbolController.text.trim().isNotEmpty
          ? _symbolController.text.trim()
          : 'bolt',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF141822),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF26324D),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF26324D),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  MiSymbol(
                    currentSymbol: _symbolController.text,
                    onSymbolChanged: (newSymbol) {
                      setState(() {
                        _symbolController.text = newSymbol;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Trigger',
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
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Launch Application')),
                DropdownMenuItem(value: 1, child: Text('Open URI / Link')),
                DropdownMenuItem(value: 2, child: Text('Send Intent (Advanced)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _typeSelection = val;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            if (_typeSelection == 0) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Application',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedPackage.isEmpty
                              ? 'None'
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
                    child: const Text('Select'),
                  ),
                ],
              ),
            ] else if (_typeSelection == 1) ...[
              TextFormField(
                controller: _uriController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Link',
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
                  labelText: 'Action',
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _packageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Package (Optional)',
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Extras (Optional)',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _extraRows.add(_ExtraRow());
                      });
                    },
                    icon: const Icon(Icons.add, size: 16, color: Color(0xFF00E5FF)),
                    label: const Text(
                      'Add',
                      style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ..._extraRows.asMap().entries.map((entry) {
                final idx = entry.key;
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: row.keyController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Key',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF141822),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF26324D)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF26324D)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: row.valueController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Value',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF141822),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF26324D)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF26324D)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                        onPressed: () {
                          setState(() {
                            row.dispose();
                            _extraRows.removeAt(idx);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 32),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF00E5FF),
                minimumSize: const Size.fromHeight(50),
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
          ],
        ),
      ),
    );
  }
}
