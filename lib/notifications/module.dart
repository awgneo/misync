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
import 'dart:async';
import '../apps/module.dart';
import '../apps/blobs/apps.dart' as app_registry;
import 'blobs/contact.dart';
import 'blobs/apps.dart';
import 'blobs/replies.dart';
import 'blobs/dnd.dart';
import 'screen.dart';

class NotificationModule extends TabModule {
  @override
  String get name => 'notifications';

  @override
  IconData get icon => Icons.notifications;

  @override
  List<String> get permissions => const ['notification', 'sms', 'contacts'];

  DateTime _lastMessageTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastMessageKey;
  DateTime _lastCallTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastCallNumber;

  @override
  Widget get screen => const NotificationsScreen();
  static final NotificationModule _instance = NotificationModule._();
  static NotificationModule get instance => _instance;
  NotificationModule._();

  static const String messagesPackage = 'com.misync.messages';

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
    } else if (call.method == 'onNotificationRemoved') {
      final data = Map<String, dynamic>.from(call.arguments);
      Logger.info('notifications', 'Removed notification arguments: $data');
      _handleNotificationRemoved(data);
    }
  }

  void _handlePhoneNotification(Map<String, dynamic> data) async {
    final String package = data['package'] ?? '';
    final String category = data['category'] ?? '';

    // Ignore dialer/phone notifications if category is not call (missed calls, voicemails, transcriptions)
    final bool isDialerPackage =
        package.contains('dialer') ||
        package.contains('telecom') ||
        package.contains('phone');
    if (isDialerPackage && category != 'call') {
      return;
    }

    String? defaultSmsPkg;
    try {
      defaultSmsPkg = await PlatformModule.instance.invokeMethod<String>(
        'getDefaultSmsPackage',
      );
    } catch (_) {}

    final bool isSms = defaultSmsPkg != null && package == defaultSmsPkg;
    final bool isCall = category == 'call';

    final bool isAllowed = (isCall || isSms)
        ? ContactBlob.enabled
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
      ..body = isCall ? '' : body
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

    // Handled below based on category
    await DeviceConnection.send(
      type: CmdType.notification,
      subtype: NotificationSubtype.push,
      builder: (cmd) =>
          cmd.notification = (Notification()
            ..notification2 = (Notification2()..notification3 = notification3)),
    );

    final bool isChatApp =
        package.contains('whatsapp') ||
        package.contains('tele') ||
        package.contains('msgr') ||
        package.contains('message') ||
        package.contains('messaging') ||
        package.contains('discord') ||
        package.contains('dialer') ||
        package.contains('telecom') ||
        package.contains('phone');

    if (isCall) {
      _lastCallNumber = data['phoneNumber']?.toString() ?? '';
      _lastCallTime = DateTime.now();
    } else if (ContactBlob.enabled && (isSms || isChatApp)) {
      _lastMessageKey = key;
      _lastMessageTime = DateTime.now();
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

      final target = dismiss.notificationId.isNotEmpty
          ? dismiss.notificationId.first
          : null;
      final pkg = target?.package.toLowerCase() ?? '';
      final key = target?.key.toLowerCase() ?? '';
      final bool isCallDismiss =
          pkg.contains('dialer') ||
          pkg.contains('telecom') ||
          pkg.contains('phone') ||
          pkg.contains('contacts') ||
          key.contains('dialer') ||
          key.contains('telecom') ||
          key.contains('phone');

      final lastPushTime = isCallDismiss ? _lastCallTime : _lastMessageTime;
      final elapsed = DateTime.now().difference(lastPushTime);
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

      // 0. Handle Call Dismiss immediately (always decline call, only launch watch messages app if recent <= 5s)
      if (isCallDismiss && target != null) {
        Logger.info(
          'notifications',
          'Call dismiss detected (elapsed: ${elapsed.inSeconds}s). Declining incoming call...',
        );
        PlatformModule.instance.invokeMethod('dismissNotification', {
          'key': target.key,
          'id': target.id,
        });

        if (elapsed.inSeconds <= 5) {
          Logger.info(
            'notifications',
            'Launching watch quick replies app for call...',
          );
          try {
            final uri = 'hap://app/com.misync.messages';
            AppsModule.instance.launch(messagesPackage, uri: uri);
          } catch (e) {
            Logger.error(
              'notifications',
              'failed to launch watch app on call dismiss: $e',
            );
          }
        }
        return;
      }

      // 1. Clear All or multi-dismiss -> dismiss on phone & skip watch app launch
      if (dismiss.notificationId.length > 1) {
        Logger.info(
          'notifications',
          'Multi-dismiss or Clear All detected. Skipping watch app launch.',
        );
        for (var notifId in dismiss.notificationId) {
          PlatformModule.instance.invokeMethod('dismissNotification', {
            'key': notifId.key,
            'id': notifId.id,
          });
        }
        return;
      }

      // 2. Delayed drawer swipe (> 5 seconds) -> dismiss on phone & skip watch app launch
      final bool isRecent = elapsed.inSeconds <= 5;
      if (!isRecent) {
        Logger.info(
          'notifications',
          'Dismiss outside 5s active window (elapsed: ${elapsed.inSeconds}s). Skipping watch app launch.',
        );
        if (dismiss.notificationId.isNotEmpty) {
          final target = dismiss.notificationId.first;
          PlatformModule.instance.invokeMethod('dismissNotification', {
            'key': target.key,
            'id': target.id,
          });
        }
        return;
      }

      // 3. Active popup swipe (<= 5 seconds) -> check package directly
      if (dismiss.notificationId.isNotEmpty) {
        final target = dismiss.notificationId.first;
        final pkg = target.package.toLowerCase();
        final bool isChatApp =
            pkg.contains('whatsapp') ||
            pkg.contains('tele') ||
            pkg.contains('msgr') ||
            pkg.contains('message') ||
            pkg.contains('messaging') ||
            pkg.contains('sms') ||
            pkg.contains('discord') ||
            pkg.contains('dialer') ||
            pkg.contains('telecom') ||
            pkg.contains('phone');

        if (isChatApp) {
          Logger.info(
            'notifications',
            'Wrist dismiss received for chat app ($pkg): launching watch app...',
          );
          try {
            final uri = 'hap://app/com.misync.messages';
            AppsModule.instance.launch(messagesPackage, uri: uri);
          } catch (e) {
            Logger.error('notifications', 'failed to launch on dismiss: $e');
          }
        } else {
          Logger.info(
            'notifications',
            'Sync dismissing non-chat app ($pkg) on phone.',
          );
          PlatformModule.instance.invokeMethod('dismissNotification', {
            'key': target.key,
            'id': target.id,
          });
        }
      }
    }
  }

  Future<void> _handleWatchCommand(Command cmd) async {
    if (cmd.subtype == ThirdPartyAppSubtype.sendWearMessage.value) {
      if (cmd.hasThirdPartyApp() && cmd.thirdPartyApp.hasMessage()) {
        final msg = cmd.thirdPartyApp.message;
        if (msg.appInfo.packageName == messagesPackage) {
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
    final repliesPayload = {
      'response': RepliesBlob.list,
      'sender': '',
      'text': '',
    };
    final jsonPayload = jsonEncode(repliesPayload);
    Logger.info(
      'notifications',
      'Watch requested replies. Sending: $jsonPayload',
    );

    final appInfo = ThirdPartyAppInfo()..packageName = messagesPackage;
    final installed = app_registry.AppsBlob.instance.value[messagesPackage];
    if (installed != null && installed.fingerprint.isNotEmpty) {
      appInfo.fingerprint = installed.fingerprint;
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
    final bool isCallRecent = _lastCallTime.isAfter(_lastMessageTime);

    if (isCallRecent &&
        _lastCallNumber != null &&
        _lastCallNumber!.isNotEmpty) {
      final phoneNumber = _lastCallNumber!;
      Logger.info(
        'notifications',
        'Received reply from watch: "$replyText" for incoming call from: $phoneNumber',
      );

      final success =
          await PlatformModule.instance.invokeMethod<bool>('sendSms', {
            'phoneNumber': phoneNumber,
            'message': replyText,
          }) ??
          false;
      Logger.info('notifications', 'SMS reply status: $success');
    } else if (_lastMessageKey != null && _lastMessageKey!.isNotEmpty) {
      Logger.info(
        'notifications',
        'Received reply from watch: "$replyText" for notification: key=$_lastMessageKey',
      );

      await PlatformModule.instance.invokeMethod('replyToNotification', {
        'key': _lastMessageKey,
        'message': replyText,
      });

      await PlatformModule.instance.invokeMethod('dismissNotification', {
        'key': _lastMessageKey,
      });
    }
  }

  Future<void> _handleWatchDismiss() async {
    final bool isCallRecent = _lastCallTime.isAfter(_lastMessageTime);
    final keyToDismiss = isCallRecent ? null : _lastMessageKey;

    if (keyToDismiss != null && keyToDismiss.isNotEmpty) {
      Logger.info(
        'notifications',
        'Received dismiss from watch Messages app for notification: key=$keyToDismiss',
      );

      await PlatformModule.instance.invokeMethod('dismissNotification', {
        'key': keyToDismiss,
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

      // 2. Orchestrate RPK installation and custom actions if Contact Sync is enabled
      if (ContactBlob.enabled) {
        Logger.info(
          'notifications',
          'Contact Sync enabled: ensuring watch app $messagesPackage...',
        );
        await AppsModule.instance.enable(messagesPackage);
      } else {
        Logger.info(
          'notifications',
          'Contact Sync disabled: ensuring watch app $messagesPackage is disabled...',
        );
        await AppsModule.instance.disable(messagesPackage);
      }

      Logger.info('notifications', 'notification settings sync finished');
    } catch (e) {
      Logger.error('notifications', 'error during notification sync: $e');
    }
  }

  Future<void> enableContact() async {
    ContactBlob.enabled = true;
    await AppsModule.instance.enable(messagesPackage);
    Logger.info('notifications', 'Contact sync enabled from controller');
  }

  Future<void> disableContact() async {
    ContactBlob.enabled = false;
    await AppsModule.instance.disable(messagesPackage);
    Logger.info('notifications', 'Contact sync disabled from controller');
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

  void _handleNotificationRemoved(Map<String, dynamic> data) async {
    if (!DeviceConnection.connected.value) return;

    final String package = data['package'] ?? '';
    final String category = data['category'] ?? '';
    final String key = data['key'] ?? '';
    final int id = data['id'] ?? 0;

    Logger.info(
      'notifications',
      'Phone dismissed notification: pkg=$package, category=$category, key=$key. Sending dismiss to watch...',
    );

    final idProto = NotificationId()
      ..id = id
      ..package = package
      ..key = key;

    await DeviceConnection.send(
      type: CmdType.notification,
      subtype: NotificationSubtype.dismiss, // 1
      builder: (c) =>
          c.notification = (Notification()
            ..notificationDismiss = (NotificationDismiss()
              ..notificationId.add(idProto))),
    );
  }
}
