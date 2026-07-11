import 'dart:convert';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import '../module.dart';
import '../platform/module.dart';
import '../device/connection.dart';
import '../device/module.dart';
import '../device/proto/xiaomi.pb.dart';
import '../device/proto/constants.dart';
import 'dart:async';
import '../apps/module.dart';
import '../apps/blobs/apps.dart' as app_registry;
import '../platform/app.dart';
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
  List<String> get permissions => const [
    'notification',
    'sms',
    'contacts',
    'dnd',
  ];

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
    PlatformModule.instance.register(_receivePhoneMethod);
    DeviceConnection.listen(_receiveWatchCommand);
  }

  Future<dynamic> _receivePhoneMethod(MethodCall call) async {
    if (call.method == 'notificationReceived') {
      final data = Map<String, dynamic>.from(call.arguments);
      _handlePhoneNotificationReceived(data);
    } else if (call.method == 'notificationRemoved') {
      final data = Map<String, dynamic>.from(call.arguments);
      _handlePhoneNotificationRemoved(data);
    } else if (call.method == 'dndChanged') {
      final bool dnd = call.arguments as bool;
      _handlePhoneDndChanged(dnd);
    }
  }

  void _handlePhoneNotificationReceived(Map<String, dynamic> data) async {
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

    final String? defaultSmsPkg = await PlatformModule.instance
        .invokeMethod<String>('getDefaultSmsPackage');
    final bool sms = defaultSmsPkg != null && package == defaultSmsPkg;
    final bool call = category == 'call';

    final bool allowed = (call || sms)
        ? ContactBlob.enabled
        : (AppsBlob.map[package] == true);

    if (!allowed) {
      return; // Filtered out
    }

    final String title = data['title'] ?? '';
    final String body = data['body'] ?? '';
    final int id = data['id'] ?? 0;
    final String key = data['key'] ?? '';
    final String appName =
        data['appName'] != null && (data['appName'] as String).isNotEmpty
        ? data['appName']
        : package.split('.').last;

    final notification = Notification3()
      ..package = package
      ..appName = appName
      ..title = title
      ..body = call ? '' : body
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

    logger.info('pushing phone notification to watch', {
      'package': package,
      'appName': appName,
      'title': title,
      'body': call ? '[CALL]' : body,
      'id': id,
      'key': key,
      'isCall': call,
      'isSms': sms,
    });

    // Handled below based on category
    await DeviceConnection.send(
      type: CmdType.notification,
      subtype: NotificationSubtype.push,
      builder: (cmd) =>
          cmd.notification = (Notification()
            ..notification2 = (Notification2()..notification3 = notification)),
    );

    final bool chat =
        package.contains('whatsapp') ||
        package.contains('tele') ||
        package.contains('msgr') ||
        package.contains('message') ||
        package.contains('messaging') ||
        package.contains('discord') ||
        package.contains('dialer') ||
        package.contains('telecom') ||
        package.contains('phone');

    if (call) {
      _lastCallNumber = data['phoneNumber']?.toString() ?? '';
      _lastCallTime = DateTime.now();
    } else if (ContactBlob.enabled && (sms || chat)) {
      _lastMessageKey = key;
      _lastMessageTime = DateTime.now();
    }
  }

  void _handlePhoneNotificationRemoved(Map<String, dynamic> data) async {
    final String package = data['package'] ?? '';
    final String category = data['category'] ?? '';
    final String key = data['key'] ?? '';
    final int id = data['id'] ?? 0;

    logger.info('sending dismiss command to watch', {
      'package': package,
      'category': category,
      'key': key,
      'id': id,
    });

    final idProto = NotificationId()
      ..id = id
      ..package = package
      ..key = key;

    await DeviceConnection.send(
      type: CmdType.notification,
      subtype: NotificationSubtype.dismiss,
      builder: (c) =>
          c.notification = (Notification()
            ..notificationDismiss = (NotificationDismiss()
              ..notificationId.add(idProto))),
    );
  }

  void _handlePhoneDndChanged(bool dnd) {
    logger.info('phone DND state updated', {'enabled': dnd});
    _setWatchDnd(dnd);
  }

  Future<void> _setWatchDnd(bool dnd) async {
    if (!DndBlob.enabled) return;

    logger.info('sending DND update to watch', {'enabled': dnd});

    await DeviceConnection.send(
      type: CmdType.system,
      subtype: SystemSubtype.dnd,
      builder: (cmd) =>
          cmd.system = (System()
            ..dndStatus = (DoNotDisturb()..status = dnd ? 1 : 0)),
    );
  }

  Future<void> _receiveWatchCommand(Command cmd) async {
    if (cmd.type == CmdType.notification.value) {
      if (cmd.subtype == NotificationSubtype.replySend.value) {
        _handleWatchNotificationReply(cmd);
      } else if (cmd.subtype == NotificationSubtype.dismiss.value) {
        await _handleWatchNotificationDismiss(cmd);
      }
    } else if (cmd.type == CmdType.thirdPartyApp.value) {
      await _handleWatchAppCommand(cmd);
    } else if (cmd.type == CmdType.system.value) {
      if (cmd.subtype == SystemSubtype.dnd.value) {
        _handleWatchDndChange(cmd);
      }
    }
  }

  void _handleWatchNotificationReply(Command cmd) {
    if (!cmd.hasNotification() || !cmd.notification.hasNotificationReply()) {
      return;
    }

    final reply = cmd.notification.notificationReply;

    logger.info('received notification reply from watch', {
      'id': reply.unknown1,
      'message': reply.message,
    });

    PlatformModule.instance.invokeMethod('replyToNotification', {
      'id': reply.unknown1,
      'message': reply.message,
    });
  }

  Future<void> _handleWatchNotificationDismiss(Command cmd) async {
    if (!cmd.hasNotification() || !cmd.notification.hasNotificationDismiss()) {
      return;
    }

    final dismiss = cmd.notification.notificationDismiss;
    final target = dismiss.notificationId.isNotEmpty
        ? dismiss.notificationId.first
        : null;
    final package = target?.package.toLowerCase() ?? '';
    final key = target?.key.toLowerCase() ?? '';
    final int id = target?.id ?? 0;

    final bool call =
        package.contains('dialer') ||
        package.contains('telecom') ||
        package.contains('phone') ||
        package.contains('contacts') ||
        key.contains('dialer') ||
        key.contains('telecom') ||
        key.contains('phone');

    final bool chat =
        package.contains('whatsapp') ||
        package.contains('tele') ||
        package.contains('msgr') ||
        package.contains('message') ||
        package.contains('messaging') ||
        package.contains('sms') ||
        package.contains('discord') ||
        package.contains('dialer') ||
        package.contains('telecom') ||
        package.contains('phone');

    final lastContactTime = call ? _lastCallTime : _lastMessageTime;
    final elapsed = DateTime.now().difference(lastContactTime);

    if (elapsed.inMilliseconds < 1200) {
      logger.info('ignored automatic watch dismiss event', {
        'elapsedMs': elapsed.inMilliseconds,
        'count': dismiss.notificationId.length,
      });
      return;
    }

    // 0. Handle Call Dismiss immediately (always decline call, only launch watch messages app if recent <= 5s)
    if (call && target != null) {
      final bool launch = elapsed.inSeconds <= 5;

      logger.info('watch dismissed call', {
        'package': package,
        'key': key,
        'elapsedSeconds': elapsed.inSeconds,
        'launch': launch,
      });

      PlatformModule.instance.invokeMethod('dismissNotification', {
        'key': key,
        'id': id,
      });

      if (launch) {
        AppsModule.instance.launchApp(messagesPackage);
      }

      return;
    }

    // 1. Clear All or multi-dismiss -> dismiss on phone & skip watch app launch
    if (dismiss.notificationId.length > 1) {
      logger.info('watch multi-dismissed notifications', {
        'count': dismiss.notificationId.length,
        'packages': dismiss.notificationId.map((n) => n.package).toList(),
      });

      for (var notifId in dismiss.notificationId) {
        PlatformModule.instance.invokeMethod('dismissNotification', {
          'key': notifId.key,
          'id': notifId.id,
        });
      }

      return;
    }

    // 2. Delayed drawer swipe (> 5 seconds) -> dismiss on phone & skip watch app launch
    final bool recent = elapsed.inSeconds <= 5;
    if (!recent) {
      logger.info('watch dismissed notification outside active window', {
        'package': package,
        'key': key,
        'elapsedSec': elapsed.inSeconds,
      });

      if (dismiss.notificationId.isNotEmpty) {
        PlatformModule.instance.invokeMethod('dismissNotification', {
          'key': key,
          'id': id,
        });
      }

      return;
    }

    // 3. Active popup swipe (<= 5 seconds) -> check package directly
    if (dismiss.notificationId.isNotEmpty) {
      if (chat) {
        logger.info(
          'watch swiped chat notification (launching watch replies app)',
          {'package': package, 'key': key},
        );

        AppsModule.instance.launchApp(messagesPackage);
      } else {
        logger.info(
          'watch swiped non-chat notification (dismissing on phone)',
          {'package': package, 'key': key},
        );

        PlatformModule.instance.invokeMethod('dismissNotification', {
          'key': key,
          'id': id,
        });
      }
    }
  }

  Future<void> _handleWatchAppCommand(Command cmd) async {
    if (cmd.subtype != ThirdPartyAppSubtype.sendWearMessage.value ||
        !cmd.hasThirdPartyApp() ||
        !cmd.thirdPartyApp.hasMessage()) {
      return;
    }

    final msg = cmd.thirdPartyApp.message;
    if (msg.appInfo.packageName != messagesPackage) {
      return;
    }

    final String text = utf8.decode(msg.content);
    final data = jsonDecode(text) as Map<String, dynamic>;
    final command = data['command']?.toString();

    logger.info('received message from watch Messages app', {'payload': data});

    if (command == 'getReplies') {
      await _handleWatchGetReplies();
    } else if (command == 'reply') {
      final replyText = data['text']?.toString() ?? '';
      await _handleWatchReply(replyText);
    } else if (command == 'dismiss') {
      await _handleWatchDismiss();
    }
  }

  Future<void> _handleWatchGetReplies() async {
    final repliesPayload = {
      'response': RepliesBlob.list,
      'sender': '',
      'text': '',
    };

    final jsonPayload = jsonEncode(repliesPayload);
    final appInfo = ThirdPartyAppInfo()..packageName = messagesPackage;
    final installed = app_registry.AppsBlob.instance.value[messagesPackage];
    if (installed != null && installed.fingerprint.isNotEmpty) {
      appInfo.fingerprint = installed.fingerprint;
    }

    final appMessage = ThirdPartyAppMessage()
      ..appInfo = appInfo
      ..content = Uint8List.fromList(utf8.encode(jsonPayload));

    logger.info('sending quick replies to watch', repliesPayload);

    await DeviceConnection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.sendPhoneMessage,
      builder: (replyCmd) =>
          replyCmd.thirdPartyApp = (ThirdPartyApp()..message = appMessage),
    );
  }

  Future<void> _handleWatchReply(String text) async {
    final bool recentCall = _lastCallTime.isAfter(_lastMessageTime);

    if (recentCall && _lastCallNumber != null && _lastCallNumber!.isNotEmpty) {
      final phoneNumber = _lastCallNumber!;

      logger.info('received call quick reply from watch', {
        'phoneNumber': phoneNumber,
        'message': text,
      });

      await PlatformModule.instance.invokeMethod<bool>('sendSms', {
        'phoneNumber': phoneNumber,
        'message': text,
      });
    } else if (_lastMessageKey != null && _lastMessageKey!.isNotEmpty) {
      logger.info('received notification quick reply from watch', {
        'key': _lastMessageKey,
        'message': text,
      });

      await PlatformModule.instance.invokeMethod('replyToNotification', {
        'key': _lastMessageKey,
        'message': text,
      });

      await PlatformModule.instance.invokeMethod('dismissNotification', {
        'key': _lastMessageKey,
      });
    }
  }

  Future<void> _handleWatchDismiss() async {
    final bool callRecent = _lastCallTime.isAfter(_lastMessageTime);
    final key = callRecent ? null : _lastMessageKey;

    if (key != null && key.isNotEmpty) {
      logger.info('received dismiss from watch Messages app', {'key': key});
      await PlatformModule.instance.invokeMethod('dismissNotification', {
        'key': key,
      });
    }
  }

  void _handleWatchDndChange(Command cmd) async {
    if (!cmd.system.hasDndStatus()) return;

    final status = cmd.system.dndStatus.status;
    final bool dnd = (status == 1 || status == 2);
    logger.info('received DND status update from watch', {
      'status': status,
      'dndEnabled': dnd,
    });

    await setPhoneDnd(dnd);
  }

  Future<void> setPhoneDnd(bool dnd) async {
    if (!DndBlob.enabled) return;

    final currentPhoneDnd = await _getPhoneDnd();
    if (currentPhoneDnd != dnd) {
      await PlatformModule.instance.invokeMethod('setDnd', {'enabled': dnd});
    }
  }

  @override
  Future<void> sync() async {
    if (!DeviceConnection.connected.value) return;
    await _syncDnd();
    await _syncContact();
  }

  Future<void> _syncDnd() async {
    if (!DndBlob.enabled) return;

    final dnd = await _getPhoneDnd();
    await _setWatchDnd(dnd);
  }

  Future<bool> _getPhoneDnd() async {
    final dnd = await PlatformModule.instance.invokeMethod<bool>('getDnd');
    return dnd ?? false;
  }

  Future<void> _syncContact() async {
    if (ContactBlob.enabled) {
      await AppsModule.instance.enableApp(messagesPackage);
    } else {
      await AppsModule.instance.disableApp(messagesPackage);
    }
  }

  Future<void> saveContactEnabled(bool enabled) async {
    ContactBlob.enabled = enabled;
    await _syncContact();
    logger.info('contact sync state updated', {'enabled': enabled});
  }

  Future<void> saveDndEnabled(bool enabled) async {
    DndBlob.enabled = enabled;
    await _syncDnd();
    logger.info('dnd sync state updated', {'enabled': enabled});
  }

  void saveReplies(List<String> replies) {
    RepliesBlob.instance.update(replies);
  }

  void saveAppEnabled(String package, bool enabled) {
    AppsBlob.instance[package] = enabled;
  }

  void addApp(String package) {
    AppsBlob.instance.addApp(package);
  }

  void removeApp(String package) {
    AppsBlob.instance.removeApp(package);
  }
}
