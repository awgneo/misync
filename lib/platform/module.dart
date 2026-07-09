import 'package:flutter/services.dart';
import '../module.dart';

class PlatformModule implements Module {
  static final PlatformModule _instance = PlatformModule._();
  static PlatformModule get instance => _instance;
  PlatformModule._();

  static const _channel = MethodChannel('com.misync.misync/channels');
  final List<Future<dynamic> Function(MethodCall call)> _handlers = [];

  void register(Future<dynamic> Function(MethodCall call) handler) {
    _handlers.add(handler);
  }

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    return _channel.invokeMethod<T>(method, arguments);
  }

  @override
  Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      for (final handler in _handlers) {
        try {
          await handler(call);
        } catch (_) {}
      }
    });
  }

  @override
  Future<void> sync() async {}
}
