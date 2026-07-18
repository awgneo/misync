import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'module.dart';

abstract class Blob<T> extends ChangeNotifier {
  final String module;
  final String name;
  final T defaultValue;

  T? _value;
  bool _hasLoaded = false;

  Blob({required this.module, required this.name, required this.defaultValue}) {
    StorageModule.module.register(this);
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
    final jsonStr = StorageModule.module.preferences.getString(
      'misync.$module.$name',
    );
    if (jsonStr != null) {
      try {
        _value = parse(jsonDecode(jsonStr));
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
    await StorageModule.module.preferences.setString(
      'misync.$module.$name',
      jsonEncode(serialize(newValue)),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    StorageModule.module.unregister(this);
    super.dispose();
  }
}
