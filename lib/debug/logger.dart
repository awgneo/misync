import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'blobs/debug.dart';

class Logger extends ChangeNotifier {
  static final Logger _global = Logger._internal('GLOBAL');
  static final Map<String, Logger> _instances = {};

  static final List<LoggerRecord> _globalLogs = [];
  List<LoggerRecord> get logs => _globalLogs;

  final String _module;

  factory Logger(String module) {
    return _instances.putIfAbsent(module, () => Logger._internal(module));
  }

  static Logger get global => _global;

  Logger._internal(this._module);

  void info(String message, [Map<String, dynamic>? data]) {
    _global._log('INFO', _module, message, data);
  }

  void debug(String message, [Map<String, dynamic>? data]) {
    _global._log('DEBUG', _module, message, data);
  }

  void error(String message, [Map<String, dynamic>? data]) {
    _global._log('ERROR', _module, message, data);
  }

  void _log(
    String level,
    String module,
    String message, [
    Map<String, dynamic>? data,
  ]) {
    if (!DebugBlob.enabled) {
      return;
    }

    final time = DateTime.now().toIso8601String().substring(11, 19);
    final record = LoggerRecord(
      time: time,
      level: level,
      module: module,
      message: message,
      data: data,
    );

    _globalLogs.add(record);
    if (_globalLogs.length > 500) {
      _globalLogs.removeAt(0);
    }
    Future.microtask(() {
      _global.notifyListeners();
    });

    debugPrint('MiSync: $record');
  }

  void clear() {
    _globalLogs.clear();
    _global.notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    if (this == _global) {
      super.addListener(listener);
    } else {
      _global.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    if (this == _global) {
      super.removeListener(listener);
    } else {
      _global.removeListener(listener);
    }
  }
}

class LoggerRecord {
  final String time;
  final String level;
  final String module;
  final String message;
  final Map<String, dynamic>? data;

  LoggerRecord({
    required this.time,
    required this.level,
    required this.module,
    required this.message,
    this.data,
  });

  @override
  String toString() {
    String dataStr = '';
    final localData = data;
    if (localData != null && localData.isNotEmpty) {
      try {
        dataStr = '\n${const JsonEncoder.withIndent('  ').convert(localData)}';
      } catch (_) {
        dataStr = '\nData: $data';
      }
    }
    final uppercaseModule = module.toUpperCase();
    return '[$time] [$level] [$uppercaseModule] $message$dataStr';
  }
}
