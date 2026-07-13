import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:misync/screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final Map<String, dynamic> _cache = {};

  @override
  Future<void> start() async {
    _preferences = await SharedPreferences.getInstance();
    _startCache();
  }

  void _startCache() {
    for (final key in _preferences.getKeys()) {
      if (key.startsWith('misync.')) {
        final data = _preferences.getString(key);
        if (data != null) {
          try {
            final cleanKey = key.replaceFirst('misync.', '');
            _cache[cleanKey] = jsonDecode(data);
          } catch (_) {}
        }
      }
    }
  }

  @override
  Future<void> sync() async {}

  List<String> get modules {
    final modules = <String>{};
    for (final key in _cache.keys) {
      final parts = key.split('.');
      if (parts.isNotEmpty) {
        modules.add(parts.first);
      }
    }
    return modules.toList()..sort();
  }

  Future<void> save(String module, String name, dynamic json) async {
    final cacheKey = '$module.$name';
    _cache[cacheKey] = json;
    await _preferences.setString('misync.$cacheKey', jsonEncode(json));
    notifyListeners();
  }

  dynamic readJson(String module, String name) {
    final cacheKey = '$module.$name';
    return _cache[cacheKey];
  }

  T? read<T>(String module, String name, T Function(dynamic json) fromJson) {
    final jsonVal = readJson(module, name);
    if (jsonVal == null) return null;
    return fromJson(jsonVal);
  }

  bool has(String module, String name) {
    final cacheKey = '$module.$name';
    return _cache.containsKey(cacheKey);
  }

  Future<void> delete(String module, [String? name]) async {
    if (name != null) {
      final cacheKey = '$module.$name';
      _cache.remove(cacheKey);
      await _preferences.remove('misync.$cacheKey');
    } else {
      final prefix = '$module.';
      final keysToRemove = _cache.keys
          .where((k) => k.startsWith(prefix))
          .toList();
      for (final k in keysToRemove) {
        _cache.remove(k);
        await _preferences.remove('misync.$k');
      }
    }
    notifyListeners();
  }

  Future<void> clearAll() async {
    final keys = _preferences.getKeys();
    for (final key in keys) {
      if (key.startsWith('misync.')) {
        await _preferences.remove(key);
      }
    }
    _cache.clear();
    notifyListeners();
  }

  Uint8List backup() {
    final backupData = <String, Map<String, dynamic>>{};
    for (final entry in _cache.entries) {
      final parts = entry.key.split('.');
      final module = parts.first;
      final name = parts.skip(1).join('.');
      backupData.putIfAbsent(module, () => {})[name] = entry.value;
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
            await save(module, name, value);
          }
        }
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
