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
    Logger.info(
      'notifications',
      'method call received from platform',
      {'method': call.method},
    );
    if (call.method == 'notificationReceived') {
      final data = Map<String, dynamic>.from(call.arguments);
      _handlePhoneNotificationReceived(data);
    } else if (call.method == 'notificationRemoved') {
      final data = Map<String, dynamic>.from(call.arguments);
      _handlePhoneNotificationRemoved(data);
    } else if (call.method == 'dndChanged') {
      final bool dnd = call.arguments as bool;
      _handlePhoneDndChange(dnd);
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

    Logger.info(
      'notifications',
      'pushing phone notification to watch',
      {
        'package': package,
        'appName': appName,
        'title': title,
        'body': isCall ? '[CALL]' : body,
        'id': id,
        'key': key,
        'isCall': isCall,
        'isSms': isSms,
      },
    );

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

  void _handlePhoneNotificationRemoved(Map<String, dynamic> data) async {
    if (!DeviceConnection.connected.value) return;

    final String package = data['package'] ?? '';
    final String category = data['category'] ?? '';
    final String key = data['key'] ?? '';
    final int id = data['id'] ?? 0;

    Logger.info(
      'notifications',
      'sending dismiss command to watch',
      {
        'package': package,
        'category': category,
        'key': key,
        'id': id,
      },
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

  void _handlePhoneDndChange(bool dnd) {
    Logger.info('notifications', 'phone DND state updated', {'enabled': dnd});
    _setWatchDnd(dnd);
  }

  Future<void> _setWatchDnd(bool dnd) async {
    if (!DeviceConnection.connected.value) return;
    if (!DndBlob.enabled) return;

    Logger.info('notifications', 'sending DND update to watch', {'enabled': dnd});

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

    Logger.info(
      'notifications',
      'received notification reply from watch',
      {
        'id': reply.unknown1,
        'message': reply.message,
      },
    );

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
        'ignored automatic watch dismiss event',
        {
          'elapsedMs': elapsed.inMilliseconds,
          'count': dismiss.notificationId.length,
        },
      );
      return;
    }

    // 0. Handle Call Dismiss immediately (always decline call, only launch watch messages app if recent <= 5s)
    if (isCallDismiss && target != null) {
      final bool launchWatchApp = elapsed.inSeconds <= 5;
      Logger.info(
        'notifications',
        'watch dismissed call',
        {
          'package': pkg,
          'key': key,
          'elapsedSec': elapsed.inSeconds,
          'launchWatchApp': launchWatchApp,
        },
      );
      PlatformModule.instance.invokeMethod('dismissNotification', {
        'key': target.key,
        'id': target.id,
      });

      if (launchWatchApp) {
        try {
          final uri = 'hap://app/com.misync.messages';
          AppsModule.instance.launch(messagesPackage, uri: uri);
        } catch (e) {
          Logger.error('notifications', 'Failed to launch watch app on call dismiss: $e');
        }
      }
      return;
    }

    // 1. Clear All or multi-dismiss -> dismiss on phone & skip watch app launch
    if (dismiss.notificationId.length > 1) {
      Logger.info(
        'notifications',
        'watch multi-dismissed notifications',
        {
          'count': dismiss.notificationId.length,
          'packages': dismiss.notificationId.map((n) => n.package).toList(),
        },
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
        'watch dismissed notification outside active window',
        {
          'package': pkg,
          'key': key,
          'elapsedSec': elapsed.inSeconds,
        },
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
          'watch swiped chat notification (launching watch replies app)',
          {
            'package': pkg,
            'key': target.key,
          },
        );
        try {
          final uri = 'hap://app/com.misync.messages';
          AppsModule.instance.launch(messagesPackage, uri: uri);
        } catch (e) {
          Logger.error('notifications', 'failed to launch watch app on chat swipe: $e');
        }
      } else {
        Logger.info(
          'notifications',
          'watch swiped non-chat notification (dismissing on phone)',
          {
            'package': pkg,
            'key': target.key,
          },
        );
        PlatformModule.instance.invokeMethod('dismissNotification', {
          'key': target.key,
          'id': target.id,
        });
      }
    }
  }

  Future<void> _handleWatchAppCommand(Command cmd) async {
    if (cmd.subtype == ThirdPartyAppSubtype.sendWearMessage.value) {
      if (cmd.hasThirdPartyApp() && cmd.thirdPartyApp.hasMessage()) {
        final msg = cmd.thirdPartyApp.message;
        if (msg.appInfo.packageName == messagesPackage) {
          try {
            final String text = utf8.decode(msg.content);
            Logger.info(
              'notifications',
              'received message from watch Messages app',
              {'payload': text},
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
      'watch requested quick replies payload',
      repliesPayload,
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
        'received call quick reply from watch',
        {
          'phoneNumber': phoneNumber,
          'message': replyText,
        },
      );

      final success =
          await PlatformModule.instance.invokeMethod<bool>('sendSms', {
            'phoneNumber': phoneNumber,
            'message': replyText,
          }) ??
          false;
      Logger.info(
        'notifications',
        'sms send result',
        {'success': success},
      );
    } else if (_lastMessageKey != null && _lastMessageKey!.isNotEmpty) {
      Logger.info(
        'notifications',
        'received notification quick reply from watch',
        {
          'key': _lastMessageKey,
          'message': replyText,
        },
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
        'received dismiss from watch Messages app',
        {'key': keyToDismiss},
      );

      await PlatformModule.instance.invokeMethod('dismissNotification', {
        'key': keyToDismiss,
      });
    }
  }

  void _handleWatchDndChange(Command cmd) async {
    if (!cmd.system.hasDndStatus()) return;

    final status = cmd.system.dndStatus.status;
    final bool dnd = (status == 1 || status == 2);
    Logger.info(
      'notifications',
      'received DND status update from watch',
      {'status': status, 'dndEnabled': dnd},
    );
    await setPhoneDnd(dnd);
  }

  Future<void> setPhoneDnd(bool dnd) async {
    if (!DndBlob.enabled) return;

    try {
      final currentPhoneDnd = await _getPhoneDnd();
      if (currentPhoneDnd != dnd) {
        await PlatformModule.instance.invokeMethod('setDnd', {'enabled': dnd});
      }
    } catch (e) {
      Logger.error('notifications', 'failed to toggle native phone DND: $e');
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
    try {
      final dnd = await PlatformModule.instance.invokeMethod<bool>('getDnd');
      return dnd ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncContact() async {
    if (ContactBlob.enabled) {
      await AppsModule.instance.enable(messagesPackage);
    } else {
      await AppsModule.instance.disable(messagesPackage);
    }
  }

  Future<Map<String, Map<String, dynamic>>> getInstalledApps() async {
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
      Logger.error('notifications', 'failed to load installed apps: $e');
    }
    return const {};
  }

  Future<void> saveContactEnabled(bool enabled) async {
    ContactBlob.enabled = enabled;
    await _syncContact();
    Logger.info(
      'notifications',
      'contact sync state updated',
      {'enabled': enabled},
    );
  }

  Future<void> saveDndEnabled(bool enabled) async {
    DndBlob.enabled = enabled;
    await _syncDnd();
    Logger.info(
      'notifications',
      'dnd sync state updated',
      {'enabled': enabled},
    );
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
