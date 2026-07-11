import 'dart:convert';
import 'package:flutter/foundation.dart';

class Logger extends ChangeNotifier {
  static final Logger _global = Logger._internal(null);
  
  final List<String> logs = [];
  final String? _module;

  factory Logger([String? module]) {
    if (module == null) {
      return _global;
    }
    return Logger._internal(module);
  }

  Logger._internal(this._module);

  void info(String message, [Map<String, dynamic>? data]) {
    _global._addLog('INFO', _module ?? 'GLOBAL', message, data);
  }

  void debug(String message, [Map<String, dynamic>? data]) {
    _global._addLog('DEBUG', _module ?? 'GLOBAL', message, data);
  }

  void error(String message, [Map<String, dynamic>? data]) {
    _global._addLog('ERROR', _module ?? 'GLOBAL', message, data);
  }

  void _addLog(String level, String module, String message, [Map<String, dynamic>? data]) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    String dataStr = '';
    if (data != null && data.isNotEmpty) {
      try {
        dataStr = '\n${const JsonEncoder.withIndent('  ').convert(data)}';
      } catch (e) {
        dataStr = '\nData: $data';
      }
    }
    final uppercaseModule = module.toUpperCase();
    final formatted = '[$time] [$level] [$uppercaseModule] $message$dataStr';
    
    _global.logs.add(formatted);
    if (_global.logs.length > 500) {
      _global.logs.removeAt(0);
    }
    Future.microtask(() {
      _global.notifyListeners();
    });
    debugPrint('MiSync: [$level] [$uppercaseModule] $message$dataStr');
  }

  void clear() {
    _global.logs.clear();
    _global.notifyListeners();
  }
}
