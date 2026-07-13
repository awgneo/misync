import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:misync/device/module.dart';
import '../module.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/proto/constants.dart';
import 'app.dart';

class PlatformModule extends Module {
  @override
  String get name => 'platform';

  static final PlatformModule _module = PlatformModule._();
  static PlatformModule get module => _module;
  PlatformModule._();

  static const _channel = MethodChannel('com.misync/channels');

  final List<Future<dynamic> Function(MethodCall call)> _handlers = [];
  final ValueNotifier<bool> findingWatch = ValueNotifier<bool>(false);

  void register(Future<dynamic> Function(MethodCall call) handler) {
    _handlers.add(handler);
  }

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    return _channel.invokeMethod<T>(method, arguments);
  }

  @override
  Future<void> start() async {
    register(_receiveTileCall);
    _channel.setMethodCallHandler((call) async {
      for (final handler in _handlers) {
        try {
          await handler(call);
        } catch (_) {}
      }
    });
  }

  Future<dynamic> _receiveTileCall(MethodCall call) async {
    if (call.method == 'findWatchFromTile') {
      final enabled = call.arguments as bool? ?? false;
      await findWatch(enabled);
    }
  }

  Future<bool> checkModulePermissions(String moduleName) async {
    try {
      return await invokeMethod<bool>('$moduleName.checkPermissions') ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> requestModulePermissions(String moduleName) async {
    try {
      await invokeMethod('$moduleName.requestPermissions');
    } catch (_) {}
  }

  @override
  Future<void> sync() async {}

  Future<Map<String, App>> getApps() async {
    final List<dynamic>? appsList = await invokeMethod<List<dynamic>>(
      'notifications.getApps',
    );
    if (appsList != null) {
      final Map<String, App> map = {};
      for (final item in appsList) {
        final appMap = Map<String, dynamic>.from(item as Map);
        final app = App.fromJson(appMap);
        map[app.package] = app;
      }
      return map;
    }
    return const {};
  }

  Future<void> findWatch(bool start) async {
    findingWatch.value = start;
    if (DeviceModule.module.connection.connected.value) {
      await DeviceModule.module.connection.send(
        type: CmdType.system,
        subtype: SystemSubtype.findWatch,
        builder: (cmd) =>
            cmd.system = (pb.System()..findDevice = start ? 0 : 1),
      );
    }
    await invokeMethod('device.updateFindWatchState', start);
  }
}
