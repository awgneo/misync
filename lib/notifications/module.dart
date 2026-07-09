import 'dart:convert';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import '../module.dart';
import '../platform/module.dart';
import '../device/connection.dart';
import '../device/module.dart';
import '../device/proto/xiaomi.pb.dart';
import '../device/proto/constants.dart';
import '../debug/logger.dart';
import '../actions/module.dart';
import 'dart:async';
import '../apps/module.dart';
import 'blobs/messages.dart';
import 'blobs/apps.dart';
import 'blobs/replies.dart';
import 'blobs/dnd.dart';
import 'screen.dart';

class NotificationModule implements TabModule {
  @override
  String get name => 'notifications';

  @override
  IconData get icon => Icons.notifications;

  DateTime _lastPushTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Widget get screen => const NotificationsScreen();
  static final NotificationModule _instance = NotificationModule._();
  static NotificationModule get instance => _instance;
  NotificationModule._();

  static const String companionAppId = 'com.misync.messages';

  @override
  Future<void> start() async {
    DeviceModule.instance.register(this);
    PlatformModule.instance.register(_handleMethodCall);
    DeviceConnection.listen(_handleCommand);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    Logger.info(
      'notifications',
      'Method call received in Dart: ${call.method}',
    );
    if (call.method == 'onNotificationReceived') {
      final data = Map<String, dynamic>.from(call.arguments);
      Logger.info('notifications', 'Incoming notification arguments: $data');
      _handlePhoneNotification(data);
    }
  }

  void _handlePhoneNotification(Map<String, dynamic> data) async {
    final String package = data['package'] ?? '';

    String? defaultSmsPkg;
    try {
      defaultSmsPkg = await PlatformModule.instance.invokeMethod<String>(
        'getDefaultSmsPackage',
      );
    } catch (_) {}

    final bool isSms = defaultSmsPkg != null && package == defaultSmsPkg;
    final bool isAllowed = isSms
        ? MessagesBlob.smsEnabled
        : (AppsBlob.map[package] == true);

    if (!isAllowed) {
      return; // Filtered out
    }

    if (!DeviceConnection.connected.value) {
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

    final notification3 = Notification3()
      ..package = package
      ..appName = appName
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

    _lastPushTime = DateTime.now();
    await DeviceConnection.send(
      type: CmdType.notification,
      subtype: NotificationSubtype.push,
      builder: (cmd) =>
          cmd.notification = (Notification()
            ..notification2 = (Notification2()..notification3 = notification3)),
    );

    // If SMS mirroring/Quick replies is active, check if we should trigger the fullscreen watch Messages app
    final bool isChatApp =
        package.contains('whatsapp') ||
        package.contains('tele') ||
        package.contains('msgr') ||
        package.contains('message') ||
        package.contains('messaging') ||
        package.contains('discord');

    if (MessagesBlob.quickRepliesEnabled && (isSms || isChatApp)) {
      // Store notification data in ActionsModule for wrist reply matching and launch streaming
      ActionsModule.activeNotification = {
        'id': id,
        'key': key,
        'package': package,
        'title': title,
        'body': body,
      };
    }
  }

  Future<void> _handleCommand(Command cmd) async {
    if (cmd.type == CmdType.notification.value) {
      await _handleNotificationCommand(cmd);
    } else if (cmd.type == CmdType.thirdPartyApp.value) {
      await _handleWatchCommand(cmd);
    }
  }

  Future<void> _handleNotificationCommand(Command cmd) async {
    if (cmd.subtype == NotificationSubtype.replySend.value) {
      _handleNotificationReply(cmd);
    } else if (cmd.subtype == NotificationSubtype.dismiss.value) {
      await _handleNotificationDismiss(cmd);
    }
  }

  void _handleNotificationReply(Command cmd) {
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
  }

  Future<void> _handleNotificationDismiss(Command cmd) async {
    if (cmd.hasNotification() && cmd.notification.hasNotificationDismiss()) {
      final dismiss = cmd.notification.notificationDismiss;

      final elapsed = DateTime.now().difference(_lastPushTime);
      if (elapsed.inMilliseconds < 1200) {
        Logger.info(
          'notifications',
          'Ignoring automatic firmware dismiss event (elapsed: ${elapsed.inMilliseconds}ms) for ID(s) ${dismiss.notificationId}',
        );
        return;
      }

      Logger.info(
        'notifications',
        'Wrist native dismiss event received on notification ID(s) ${dismiss.notificationId}. CONSOLE COMMAND: native wrist dismiss',
      );

      final active = ActionsModule.activeNotification;
      if (active != null) {
        final activePkg = active['package'] as String? ?? '';
        final activeTitle = active['title'] as String? ?? '';
        final activeBody = active['body'] as String? ?? '';
        final activeKey = active['key'];
        final activeId = active['id'];

        final bool isChatApp =
            activePkg.contains('whatsapp') ||
            activePkg.contains('tele') ||
            activePkg.contains('msgr') ||
            activePkg.contains('message') ||
            activePkg.contains('messaging') ||
            activePkg.contains('sms') ||
            activePkg.contains('discord');

        if (isChatApp) {
          Logger.info(
            'notifications',
            'Wrist dismiss received for chat app ($activePkg): launching watch app immediately...',
          );
          try {
            // Launch the watch Messages app with URI query parameters
            final uri =
                'hap://app/com.misync.messages?sender=${Uri.encodeComponent(activeTitle)}&text=${Uri.encodeComponent(activeBody)}';
            await AppsModule.instance.launch(companionAppId, uri: uri);
          } catch (e) {
            Logger.error('notifications', 'failed to launch on dismiss: $e');
          }
        } else {
          // Dismiss the notification on the phone as well (sync dismiss)
          Logger.info(
            'notifications',
            'Auto dismissing active notification on phone: key=$activeKey, id=$activeId',
          );
          PlatformModule.instance.invokeMethod('dismissNotification', {
            'key': activeKey,
            'id': activeId,
          });
        }
      }
    }
  }

  Future<void> _handleWatchCommand(Command cmd) async {
    if (cmd.subtype == ThirdPartyAppSubtype.sendWearMessage.value) {
      if (cmd.hasThirdPartyApp() && cmd.thirdPartyApp.hasMessage()) {
        final msg = cmd.thirdPartyApp.message;
        if (msg.appInfo.packageName == companionAppId) {
          try {
            final String text = utf8.decode(msg.content);
            Logger.info(
              'notifications',
              'Received message from watch Messages app: $text',
            );
            final data = jsonDecode(text) as Map<String, dynamic>;
            final command = data['command']?.toString();

            if (command == 'getReplies') {
              await _handleWatchGetReplies();
            } else if (command == 'reply') {
              final replyText = data['text']?.toString() ?? '';
              await _handleWatchReply(replyText);
            } else if (command == 'dismiss') {
              await _handleWatchDismiss();
            }
          } catch (e) {
            Logger.error(
              'notifications',
              'Failed to decode or handle watch message: $e',
            );
          }
        }
      }
    }
  }

  Future<void> _handleWatchGetReplies() async {
    final active = ActionsModule.activeNotification;
    final repliesPayload = {
      'response': RepliesBlob.list,
      'sender': active?['title']?.toString() ?? '',
      'text': active?['body']?.toString() ?? '',
    };
    final jsonPayload = jsonEncode(repliesPayload);
    Logger.info(
      'notifications',
      'Watch requested replies. Sending: $jsonPayload',
    );

    final appInfo = ThirdPartyAppInfo()..packageName = companionAppId;
    final installed = AppsModule.instance.installedApps.value.firstWhere(
      (app) => app.id == companionAppId,
      orElse: () => RpkInfoList(),
    );
    if (installed.id.isNotEmpty && installed.sha.isNotEmpty) {
      appInfo.fingerprint = installed.sha;
    }

    final appMsg = ThirdPartyAppMessage()
      ..appInfo = appInfo
      ..content = Uint8List.fromList(utf8.encode(jsonPayload));

    await DeviceConnection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.sendPhoneMessage,
      builder: (replyCmd) =>
          replyCmd.thirdPartyApp = (ThirdPartyApp()..message = appMsg),
    );
  }

  Future<void> _handleWatchReply(String replyText) async {
    final active = ActionsModule.activeNotification;
    if (active != null) {
      final activeId = active['id'];
      final activeKey = active['key']?.toString() ?? '';
      Logger.info(
        'notifications',
        'Received reply from watch: "$replyText" for notification: key=$activeKey, id=$activeId',
      );

      await PlatformModule.instance.invokeMethod('replyToNotification', {
        'key': activeKey,
        'id': activeId,
        'message': replyText,
      });

      await PlatformModule.instance.invokeMethod('dismissNotification', {
        'key': activeKey,
        'id': activeId,
      });
    }
  }

  Future<void> _handleWatchDismiss() async {
    final active = ActionsModule.activeNotification;
    if (active != null) {
      final activeId = active['id'];
      final activeKey = active['key']?.toString() ?? '';
      Logger.info(
        'notifications',
        'Received dismiss from watch Messages app for notification: key=$activeKey, id=$activeId',
      );

      await PlatformModule.instance.invokeMethod('dismissNotification', {
        'key': activeKey,
        'id': activeId,
      });
    }
  }

  @override
  Future<void> sync() async {
    if (!DeviceConnection.connected.value) return;

    Logger.info(
      'notifications',
      'syncing notification settings (replies, DND, alarms) to watch',
    );

    try {
      // 1. Sync DND Status
      final dndEnabled = DndBlob.enabled;
      await DeviceConnection.send(
        type: CmdType.system,
        subtype: SystemSubtype.dnd,
        builder: (cmd) =>
            cmd.system = (System()
              ..dndStatus = (DoNotDisturb()..status = dndEnabled ? 1 : 0)),
      );

      // 2. Orchestrate RPK installation and custom actions if SMS or Quick Replies enabled
      if (MessagesBlob.smsEnabled || MessagesBlob.quickRepliesEnabled) {
        Logger.info(
          'notifications',
          'SMS or Quick Replies enabled: ensuring watch app $companionAppId...',
        );

        // Idempotent watch Messages companion app installation check
        await AppsModule.instance.install(companionAppId);
      }

      Logger.info('notifications', 'notification settings sync finished');
    } catch (e) {
      Logger.error('notifications', 'error during notification sync: $e');
    }
  }

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
}
