import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../module.dart';
import '../device/connection.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/proto/constants.dart';
import 'app.dart';

class PlatformModule extends Module {
  @override
  String get name => 'platform';

  static final PlatformModule _instance = PlatformModule._();
  static PlatformModule get instance => _instance;
  PlatformModule._();

  static const _channel = MethodChannel('com.misync.misync/channels');
  final List<Future<dynamic> Function(MethodCall call)> _handlers = [];
  final ValueNotifier<bool> findingWatch = ValueNotifier<bool>(false);

  Future<void> findWatch(bool start) async {
    findingWatch.value = start;
    if (DeviceConnection.connected.value) {
      await DeviceConnection.send(
        type: CmdType.system,
        subtype: SystemSubtype.findWatch,
        builder: (cmd) => cmd.system = (pb.System()..findDevice = start ? 0 : 1),
      );
    }
    await invokeMethod('updateFindWatchState', start);
  }

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

  Future<List<String>> checkPermissions(List<String> permissions) async {
    try {
      final List<dynamic>? missing = await invokeMethod<List<dynamic>>(
        'checkPermissions',
        {'permissions': permissions},
      );
      return missing?.cast<String>() ?? [];
    } catch (_) {
      return permissions;
    }
  }

  Future<void> requestPermissions(List<String> permissions) async {
    try {
      await invokeMethod('requestPermissions', {'permissions': permissions});
    } catch (_) {}
  }

  Future<Map<String, App>> getApps() async {
    final List<dynamic>? appsList = await invokeMethod<List<dynamic>>('getApps');
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

  @override
  Future<void> sync() async {}
}
