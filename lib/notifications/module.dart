import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import '../module.dart';
import '../platform/module.dart';
import '../device/connection.dart';
import '../device/module.dart';
import '../device/proto/xiaomi.pb.dart';
import '../device/proto/constants.dart';
import '../debug/logger.dart';
import 'blobs/filters.dart';
import 'blobs/replies.dart';
import 'blobs/dnd.dart';
import 'screen.dart';

class NotificationModule implements TabModule {
  @override
  String get name => 'notifications';

  @override
  IconData get icon => Icons.notifications;

  @override
  Widget get screen => const NotificationsScreen();
  static final NotificationModule _instance = NotificationModule._();
  static NotificationModule get instance => _instance;
  NotificationModule._();

  Future<Map<String, Map<String, dynamic>>> loadInstalledApps() async {
    try {
      final List<dynamic>? apps = await PlatformModule.instance
          .invokeMethod<List<dynamic>>('getInstalledApps');
      if (apps != null) {
        final Map<String, Map<String, dynamic>> map = {};
        for (final app in apps) {
          final appMap = Map<String, dynamic>.from(app);
          final pkg = appMap['packageName'] as String;
          map[pkg] = appMap;
        }
        return map;
      }
    } catch (e) {
      Logger.error('notifications', 'Failed to load installed apps: $e');
    }
    return const {};
  }

  Future<bool> checkNotificationPermission() async {
    try {
      return await PlatformModule.instance.invokeMethod<bool>(
            'checkNotificationPermission',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestNotificationPermission() async {
    try {
      await PlatformModule.instance.invokeMethod(
        'requestNotificationPermission',
      );
    } catch (_) {}
  }

  @override
  Future<void> start() async {
    DeviceModule.instance.register(this);
    PlatformModule.instance.register(_handleMethodCall);
    DeviceConnection.listen((cmd) {
      if (cmd.hasNotification() && cmd.notification.hasNotificationReply()) {
        final reply = cmd.notification.notificationReply;
        Logger.info(
          'notifications',
          'Received notification reply from watch: id=${reply.unknown1}, message=${reply.message}',
        );
        PlatformModule.instance.invokeMethod('replyToNotification', {
          'id': reply.unknown1,
          'message': reply.message,
        });
      }
    });
  }

  @override
  Future<void> sync() async {
    if (!DeviceConnection.connected.value) return;

    Logger.info(
      'notifications',
      'syncing notification settings (replies, DND, alarms) to watch',
    );

    try {
      // 1. Sync Call Rejection/SMS Quick Replies (types 0 to 3)
      final repliesList = RepliesBlob.list;
      for (int t = 0; t <= 3; t++) {
        final cannedMessagesCall = CannedMessages()
          ..type = t
          ..maxReplies = 10;
        cannedMessagesCall.reply.addAll(repliesList);

        await DeviceConnection.send(
          type: CmdType.notification,
          subtype: NotificationSubtype.replies,
          expectResponse: false,
          builder: (cmd) =>
              cmd.notification = (Notification()
                ..cannedMessages = cannedMessagesCall),
        );

        // Give the watch a moment to process the write
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Give the watch flash memory time to write and settle
      await Future.delayed(const Duration(milliseconds: 500));

      // 2. Sync DND Status
      final dndEnabled = DndBlob.enabled;
      await DeviceConnection.send(
        type: CmdType.system,
        subtype: SystemSubtype.dnd,
        builder: (cmd) =>
            cmd.system = (System()
              ..dndStatus = (DoNotDisturb()..status = dndEnabled ? 1 : 0)),
      );

      Logger.info('notifications', 'notification settings sync finished');
    } catch (e) {
      Logger.error('notifications', 'error during notification sync: $e');
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    Logger.info(
      'notifications',
      'Method call received in Dart: ${call.method}',
    );
    if (call.method == 'onNotificationReceived') {
      final data = Map<String, dynamic>.from(call.arguments);
      Logger.info('notifications', 'Incoming notification arguments: $data');
      _handleIncomingNotification(data);
    }
  }

  void _handleIncomingNotification(Map<String, dynamic> data) async {
    final String package = data['package'] ?? '';

    String? defaultSmsPkg;
    try {
      defaultSmsPkg = await PlatformModule.instance.invokeMethod<String>(
        'getDefaultSmsPackage',
      );
    } catch (_) {}

    final bool isSms = defaultSmsPkg != null && package == defaultSmsPkg;
    final bool isAllowed = isSms
        ? FiltersBlob.smsEnabled
        : (FiltersBlob.map[package] == true);

    Logger.info(
      'notifications',
      'Filter evaluation for $package (isSms=$isSms): allowed=$isAllowed',
    );

    if (!isAllowed) {
      return; // Filtered out
    }

    if (!DeviceConnection.connected.value) {
      Logger.info(
        'notifications',
        'Device not connected, skipping notification push',
      );
      return;
    }

    final String title = data['title'] ?? '';
    final String body = data['body'] ?? '';
    final int id = data['id'] ?? 0;
    final String key = data['key'] ?? '';
    final String appName =
        data['appName'] != null && (data['appName'] as String).isNotEmpty
        ? data['appName']
        : package.split('.').last;

    Logger.info(
      'notifications',
      'Pushing notification to watch: $title - $body (app: $appName)',
    );

    final notification3 = Notification3()
      ..package = isSms ? 'com.whatsapp' : package
      ..appName = isSms ? 'WhatsApp' : appName
      ..title = title
      ..body = body
      ..id = id
      ..key = key
      ..unknown4 = ''
      ..timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll('-', '')
          .replaceAll(':', '')
          .split('.')
          .first
      ..repliesAllowed = true
      ..openOnPhone = true;

    await DeviceConnection.send(
      type: CmdType.notification,
      subtype: NotificationSubtype.push,
      builder: (cmd) =>
          cmd.notification = (Notification()
            ..notification2 = (Notification2()..notification3 = notification3)),
    );
  }
}
