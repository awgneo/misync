import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../module.dart';
import '../debug/logger.dart';

class StorageModule extends ChangeNotifier implements Module {
  @override
  String get name => 'storage';

  @override
  late final Logger logger = Logger(name);

  static final StorageModule _instance = StorageModule._();
  static StorageModule get instance => _instance;
  StorageModule._();

  late final SharedPreferences _prefs;
  final Map<String, dynamic> _cache = {};

  @override
  Future<void> start() async {
    _prefs = await SharedPreferences.getInstance();
    for (final key in _prefs.getKeys()) {
      if (key.startsWith('blob.')) {
        final data = _prefs.getString(key);
        if (data != null) {
          try {
            final cleanKey = key.replaceFirst('blob.', '');
            _cache[cleanKey] = jsonDecode(data);
          } catch (_) {}
        }
      }
    }
  }

  @override
  Future<void> sync() async {}

  @override
  List<String> get permissions => const [];

  Future<void> save(String module, String name, dynamic jsonValue) async {
    final cacheKey = '$module.$name';
    _cache[cacheKey] = jsonValue;
    await _prefs.setString('blob.$cacheKey', jsonEncode(jsonValue));
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
      await _prefs.remove('blob.$cacheKey');
    } else {
      final prefix = '$module.';
      final keysToRemove = _cache.keys
          .where((k) => k.startsWith(prefix))
          .toList();
      for (final k in keysToRemove) {
        _cache.remove(k);
        await _prefs.remove('blob.$k');
      }
    }
    notifyListeners();
  }

  Future<void> clearAll() async {
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('blob.')) {
        await _prefs.remove(key);
      }
    }
    _cache.clear();
    notifyListeners();
  }
}
