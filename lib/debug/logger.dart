import 'package:flutter/foundation.dart';

class Logger extends ChangeNotifier {
  // Singleton pattern
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  final List<String> logs = [];

  // Leveled static entry points
  static void info(String module, String message) {
    _instance._addLog('INFO', module, message);
  }

  static void debug(String module, String message) {
    _instance._addLog('DEBUG', module, message);
  }

  static void error(String module, String message) {
    _instance._addLog('ERROR', module, message);
  }

  void _addLog(String level, String module, String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    final formatted = '[$time] [$level] [$module] $message';
    logs.add(formatted);
    if (logs.length > 500) {
      logs.removeAt(0);
    }
    Future.microtask(() {
      notifyListeners();
    });
    debugPrint('MiSync: [$level] [$module] $message');
  }

  void clear() {
    logs.clear();
    notifyListeners();
  }
}
