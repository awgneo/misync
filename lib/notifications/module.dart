import 'dart:convert';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import 'package:misync/screen.dart';
import '../platform/module.dart';
import '../device/module.dart';
import '../device/proto/xiaomi.pb.dart';
import '../device/proto/constants.dart';
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

  DateTime _lastContactTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastContactKey;
  int _lastPhoneDndChange = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final Map<String, String> _lastNotification = {};
  final ValueNotifier<Map<int, int>> vibrations = ValueNotifier({});

  @override
  late final Screen screen = NotificationsScreen(this);
  static final NotificationModule _module = NotificationModule._();
  static NotificationModule get module => _module;
  NotificationModule._();

  static const String messagesPackage = 'com.misync.messages';

  @override
  Future<void> start() async {
    DeviceModule.module.register(this);
    PlatformModule.module.register(_receivePhoneMethod);
    DeviceModule.module.connection.listen(_receiveWatchCommand);
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

    final String? defaultSmsPkg = await PlatformModule.module
        .invokeMethod<String>('notifications.getDefaultSmsPackage');
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

    // Prevent duplicate alerts on status updates / sibling dismissals
    if (_lastNotification[key] == body) {
      return;
    }

    _lastNotification[key] = body;

    final String appName =
        data['appName'] != null && (data['appName'] as String).isNotEmpty
        ? data['appName']
        : package.split('.').last;

    final notification = Notification3()
      ..package = package
      ..appName = appName
      ..title = title
      ..body = call ? '' : body
      ..id = id & 0xFFFFFFFF
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
    await DeviceModule.module.connection.send(
      type: CmdType.notification,
      subtype: NotificationSubtype.push,
      builder: (cmd) =>
          cmd.notification = (Notification()
            ..notification2 = (Notification2()..notification3 = notification)),
    );

    if (data['replyable'] == true) {
      _lastContactTime = DateTime.now();
      _lastContactKey = key;
    }
  }

  void _handlePhoneNotificationRemoved(Map<String, dynamic> data) async {
    final String package = data['package'] ?? '';
    final String category = data['category'] ?? '';
    final String key = data['key'] ?? '';
    final int id = data['id'] ?? 0;

    _lastNotification.remove(key);

    logger.info('sending dismiss command to watch', {
      'package': package,
      'category': category,
      'key': key,
      'id': id,
    });

    final idProto = NotificationId()
      ..id = id & 0xFFFFFFFF
      ..package = package
      ..key = key;

    await DeviceModule.module.connection.send(
      type: CmdType.notification,
      subtype: NotificationSubtype.dismiss,
      builder: (c) =>
          c.notification = (Notification()
            ..notificationDismiss = (NotificationDismiss()
              ..notificationId.add(idProto))),
    );
  }

  Future<void> _handlePhoneDndChanged(bool dnd) async {
    _lastPhoneDndChange = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    logger.info('phone DND state updated', {
      'dnd': dnd,
      'timestamp': _lastPhoneDndChange,
    });
    // Get watch dnd rules
    final rules = await _getWatchDndRules();
    _setWatchDnd(dnd, rules, _lastPhoneDndChange);
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

    PlatformModule.module.invokeMethod('notifications.replyToNotification', {
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

    final bool replyable = _lastContactKey == key;
    final elapsed = DateTime.now().difference(_lastContactTime);

    if (elapsed.inMilliseconds < 1200) {
      logger.info('ignored automatic watch dismiss event', {
        'elapsedMs': elapsed.inMilliseconds,
        'count': dismiss.notificationId.length,
      });
      return;
    }

    // 1. Clear All or multi-dismiss -> dismiss on phone & skip watch app launch
    if (dismiss.notificationId.length > 1) {
      logger.info('watch multi-dismissed notifications', {
        'count': dismiss.notificationId.length,
        'packages': dismiss.notificationId.map((n) => n.package).toList(),
      });

      for (var notifId in dismiss.notificationId) {
        PlatformModule.module.invokeMethod(
          'notifications.dismissNotification',
          {'key': notifId.key, 'id': notifId.id},
        );
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
        PlatformModule.module.invokeMethod(
          'notifications.dismissNotification',
          {'key': key, 'id': id},
        );
      }

      return;
    }

    // 3. Active popup swipe (<= 5 seconds) -> check package directly
    if (dismiss.notificationId.isNotEmpty) {
      if (replyable) {
        logger.info(
          'watch swiped replyable notification (launching watch replies app)',
          {'package': package, 'key': key},
        );

        AppsModule.module.launchApp(messagesPackage);
      } else {
        logger.info(
          'watch swiped non-replyable notification (dismissing on phone)',
          {'package': package, 'key': key},
        );

        PlatformModule.module.invokeMethod(
          'notifications.dismissNotification',
          {'key': key, 'id': id},
        );
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

    await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.sendPhoneMessage,
      builder: (replyCmd) =>
          replyCmd.thirdPartyApp = (ThirdPartyApp()..message = appMessage),
    );
  }

  Future<void> _handleWatchReply(String text) async {
    if (_lastContactKey == null || _lastContactKey!.isEmpty) return;

    logger.info('received notification quick reply from watch', {
      'key': _lastContactKey,
      'message': text,
    });

    await PlatformModule.module.invokeMethod(
      'notifications.replyToNotification',
      {'key': _lastContactKey, 'message': text},
    );

    await PlatformModule.module.invokeMethod(
      'notifications.dismissNotification',
      {'key': _lastContactKey},
    );
  }

  Future<void> _handleWatchDismiss() async {
    if (_lastContactKey != null && _lastContactKey!.isNotEmpty) {
      logger.info('received dismiss from watch Messages app', {
        'key': _lastContactKey,
      });
      await PlatformModule.module.invokeMethod(
        'notifications.dismissNotification',
        {'key': _lastContactKey},
      );
    }
  }

  @override
  Future<void> sync() async {
    if (!DeviceModule.module.connection.connected.value) return;
    await _syncDnd();
    await _syncContact();
    await _syncVibrations();
  }

  Future<void> _syncDnd() async {
    if (!DndBlob.enabled) return;

    try {
      // Get the current phone dnd status
      final phoneDnd = await _getPhoneDnd();
      // Get watch dnd rules
      final rules = await _getWatchDndRules();
      // Determine if any rule is currently active on the watch (overall DND status)
      final watchDnd = rules.any((r) => r.state == 1);

      // Find the maximum activation time of all rules on the watch
      int watchTime = 0;
      for (final r in rules) {
        if (r.hasLastActivationTime() &&
            r.lastActivationTime.toInt() > watchTime) {
          watchTime = r.lastActivationTime.toInt();
        }
      }

      logger.debug('DND Sync conflict check', {
        'phoneTime': _lastPhoneDndChange,
        'watchTime': watchTime,
        'phoneDnd': phoneDnd,
        'watchDnd': watchDnd,
      });

      // See who wins :)
      if (watchTime >= _lastPhoneDndChange) {
        // Watch state is newer or equal! Watch wins.
        _lastPhoneDndChange = watchTime;
        logger.debug('watch DND is newer watch wins', {'dnd': watchDnd});
        _setPhoneDnd(watchDnd);
      } else {
        // Phone DND is newer! Phone wins.
        _lastPhoneDndChange = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        logger.debug('phone DND is newer, phone wins', {'dnd': phoneDnd});
        _setWatchDnd(phoneDnd, rules, _lastPhoneDndChange);
      }
    } catch (e) {
      logger.error('failed to sync DND', <String, dynamic>{
        'error': e.toString(),
      });
    }
  }

  Future<void> _syncContact() async {
    if (ContactBlob.enabled) {
      await AppsModule.module.enableInternalApp(messagesPackage);
    } else {
      await AppsModule.module.disableInternalApp(messagesPackage);
    }
  }

  Future<void> _setPhoneDnd(bool dnd) async {
    if (!DndBlob.enabled) return;
    final currentPhoneDnd = await _getPhoneDnd();
    if (currentPhoneDnd != dnd) {
      await PlatformModule.module.invokeMethod('notifications.setDnd', {
        'enabled': dnd,
      });
    }
  }

  Future<bool> _getPhoneDnd() async {
    final dnd = await PlatformModule.module.invokeMethod<bool>(
      'notifications.getDnd',
    );
    return dnd ?? false;
  }

  Future<List<ZenRule>> _getWatchDndRules() async {
    final result = await DeviceModule.module.connection.send(
      type: CmdType.system,
      subtype: SystemSubtype.zenRuleGet,
      response: true,
    );

    if (result == null ||
        !result.hasSystem() ||
        !result.system.hasZenRuleList()) {
      return [];
    }

    final rules = result.system.zenRuleList.rules;
    logger.debug('fetched watch dndrules', {
      'rules': rules.map((r) => r.toProto3Json()).toList(),
    });

    return rules;
  }

  Future<void> _setWatchDnd(
    bool dnd,
    List<ZenRule> rules,
    int timestamp,
  ) async {
    // Find or create 'watch_manual' rule and update it
    int watchManualIdx = rules.indexWhere((r) => r.name == 'watch_manual');
    if (watchManualIdx != -1) {
      rules[watchManualIdx].state = dnd ? 1 : 0;
      rules[watchManualIdx].lastActivationTime = timestamp;
    } else {
      rules.add(
        ZenRule()
          ..name = 'watch_manual'
          ..isManualRule = true
          ..state = dnd ? 1 : 0
          ..lastActivationTime = timestamp,
      );
    }

    await DeviceModule.module.connection.send(
      type: CmdType.system,
      subtype: SystemSubtype.zenRuleSet,
      builder: (cmd) =>
          cmd.system = (System()
            ..zenRuleList = (ZenRuleList()..rules.addAll(rules))),
    );
  }

  Future<void> _syncVibrations() async {
    final response = await DeviceModule.module.connection.send(
      type: CmdType.system,
      subtype: SystemSubtype.vibrationGet,
      response: true,
    );

    if (response != null && response.system.hasVibrationPatterns()) {
      final Map<int, int> current = {};
      for (final item in response.system.vibrationPatterns.notificationType) {
        current[item.notificationType] = item.preset;
      }
      vibrations.value = current;
      logger.info(
        'synced vibrations from watch',
        current.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
  }

  Future<void> saveContactEnabled(bool enabled) async {
    ContactBlob.enabled = enabled;
    await _syncContact();
    logger.info('contact sync state updated', {'enabled': enabled});
  }

  Future<void> saveDndEnabled(bool enabled) async {
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

  Future<void> setWatchVibration(int notificationType, int preset) async {
    await DeviceModule.module.connection.send(
      type: CmdType.system,
      subtype: SystemSubtype.vibrationSetPreset,
      builder: (cmd) =>
          cmd.system = (System()
            ..vibrationSetPreset = (VibrationNotificationType()
              ..notificationType = notificationType
              ..preset = preset)),
    );

    final updated = Map<int, int>.from(vibrations.value);
    updated[notificationType] = preset;
    vibrations.value = updated;
    logger.info('vibration preset updated', {
      'type': notificationType,
      'preset': preset,
    });
  }
}
