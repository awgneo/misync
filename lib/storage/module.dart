import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:misync/screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'blob.dart';
import 'screen.dart';

class StorageModule extends TabModule with ChangeNotifier {
  @override
  String get name => 'storage';

  @override
  IconData get icon => Icons.storage;

  @override
  late final Screen screen = StorageScreen(this);

  static final StorageModule _module = StorageModule._();
  static StorageModule get module => _module;
  StorageModule._();

  late final SharedPreferences _preferences;
  SharedPreferences get preferences => _preferences;

  final Set<Blob> _blobs = {};

  void register(Blob blob) {
    _blobs.add(blob);
  }

  void unregister(Blob blob) {
    _blobs.remove(blob);
  }

  void reloadAll() {
    for (final blob in _blobs) {
      blob.load();
    }
  }

  void reloadModule(String module) {
    for (final blob in _blobs) {
      if (blob.module == module) {
        blob.load();
      }
    }
  }

  @override
  Future<void> start() async {
    _preferences = await SharedPreferences.getInstance();
  }

  @override
  Future<void> sync() async {}

  List<String> get modules {
    final modules = <String>{};
    for (final key in _preferences.getKeys()) {
      if (key.startsWith('misync.')) {
        final cleanKey = key.replaceFirst('misync.', '');
        final parts = cleanKey.split('.');
        if (parts.isNotEmpty) {
          modules.add(parts.first);
        }
      }
    }
    return modules.toList()..sort();
  }

  Future<void> delete(String module, [String? name]) async {
    if (name != null) {
      final key = 'misync.$module.$name';
      await _preferences.remove(key);
    } else {
      final prefix = 'misync.$module.';
      final keysToRemove = _preferences
          .getKeys()
          .where((k) => k.startsWith(prefix))
          .toList();
      for (final k in keysToRemove) {
        await _preferences.remove(k);
      }
    }
    reloadModule(module);
    notifyListeners();
  }

  Future<void> clearAll() async {
    final keys = _preferences.getKeys();
    for (final key in keys) {
      if (key.startsWith('misync.')) {
        await _preferences.remove(key);
      }
    }
    reloadAll();
    notifyListeners();
  }

  Uint8List backup() {
    final backupData = <String, Map<String, dynamic>>{};
    for (final key in _preferences.getKeys()) {
      if (key.startsWith('misync.')) {
        final data = _preferences.getString(key);
        if (data != null) {
          try {
            final cleanKey = key.replaceFirst('misync.', '');
            final parts = cleanKey.split('.');
            final module = parts.first;
            final name = parts.skip(1).join('.');
            backupData.putIfAbsent(module, () => {})[name] = jsonDecode(data);
          } catch (_) {}
        }
      }
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(backupData)));
  }

  Future<bool> restore(String path) async {
    try {
      final file = File(path);
      final jsonString = await file.readAsString();
      final dynamic data = jsonDecode(jsonString);
      if (data is! Map<String, dynamic>) {
        return false;
      }
      await clearAll();
      for (final moduleEntry in data.entries) {
        final module = moduleEntry.key;
        final blobs = moduleEntry.value;
        if (blobs is Map<String, dynamic>) {
          for (final blobEntry in blobs.entries) {
            final name = blobEntry.key;
            final value = blobEntry.value;
            final cacheKey = 'misync.$module.$name';
            await _preferences.setString(cacheKey, jsonEncode(value));
          }
        }
      }
      reloadAll();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
