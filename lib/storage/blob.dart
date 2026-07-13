import 'package:flutter/foundation.dart';
import 'module.dart';

abstract class Blob<T> extends ChangeNotifier {
  final String module;
  final String name;
  final T defaultValue;

  T? _value;
  bool _hasLoaded = false;

  Blob({required this.module, required this.name, required this.defaultValue}) {
    StorageModule.module.addListener(_onStorageChanged);
  }

  T parse(dynamic json);
  dynamic serialize(T value);

  T get value {
    if (!_hasLoaded) {
      load();
    }
    return _value ?? defaultValue;
  }

  void load() {
    _hasLoaded = true;
    final json = StorageModule.module.readJson(module, name);
    if (json != null) {
      try {
        _value = parse(json);
      } catch (_) {
        _value = defaultValue;
      }
    } else {
      _value = defaultValue;
    }
    notifyListeners();
  }

  Future<void> update(T newValue) async {
    _value = newValue;
    _hasLoaded = true;
    await StorageModule.module.save(module, name, serialize(newValue));
    notifyListeners();
  }

  void _onStorageChanged() {
    load();
  }

  @override
  void dispose() {
    StorageModule.module.removeListener(_onStorageChanged);
    super.dispose();
  }
}
