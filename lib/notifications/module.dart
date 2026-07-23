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
import 'blobs/pushed.dart';
import 'screen.dart';

class NotificationModule extends TabModule {
  @override
  String get name => 'notifications';

  @override
  IconData get icon => Icons.notifications;

  static const String messagesPackage = 'com.misync.messages';
  static const String emailsPackage = 'com.misync.emails';

  int _lastPhoneDndChange = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final ValueNotifier<Map<int, int>> vibrations = ValueNotifier({});

  @override
  late final Screen screen = NotificationsScreen(this);
  static final NotificationModule _module = NotificationModule._();
  static NotificationModule get module => _module;
  NotificationModule._();

  int? _dismissedId;

  @override
  Future<void> start() async {
    DeviceModule.module.register(this);
    PlatformModule.module.register(_receivePhoneMethod);
    DeviceModule.module.connection.listen(_receiveWatchCommand);
    DeviceModule.module.connection.connected.addListener(
      _watchConnectionChanged,
    );
  }

  void _watchConnectionChanged() {
    final connected = DeviceModule.module.connection.connected.value;
    logger.info('_watchConnectionChanged event fired (connected=$connected)');
    if (connected) {
      _syncActiveNotifications();
    }
  }

  Future<void> _syncActiveNotifications() async {
    try {
      final List? metas = await PlatformModule.module.invokeMethod<List>(
        'notifications.getActiveMetas',
      );
      final Set<int> pushedIds = PushedBlob.ids.toSet();
      if (metas == null || metas.isEmpty) {
        logger.info(
          'syncActiveNotifications: no active notification metas returned from Kotlin',
        );
        // If no active notifications on phone, dismiss all previously pushed watch notifications
        if (pushedIds.isNotEmpty) {
          logger.info('purging all previously pushed notifications from watch', {
            'count': pushedIds.length,
          });
          final dismissProto = NotificationDismiss();
          for (final id in pushedIds) {
            dismissProto.notificationId.add(NotificationId()..id = id & 0xFFFFFFFF);
          }
          await DeviceModule.module.connection.send(
            type: CmdType.notification,
            subtype: NotificationSubtype.dismiss,
            builder: (cmd) => cmd.notification = (Notification()..notificationDismiss = dismissProto),
          );
          PushedBlob.setAll([]);
        }
        return;
      }

      logger.info('syncing active notifications catch-up to watch', {
        'count': metas.length,
      });

      final items = <NotificationItem>[];

      for (final raw in metas) {
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          final item = _buildNotificationItem(data);
          if (item != null) {
            items.add(item);
            logger.info('batch notification item prepared', {
              'package': item.package,
              'title': item.title,
              'id': item.id,
              'key': item.key,
            });
          }
        }
      }

      final Set<int> currentIds = items.map((i) => i.id).toSet();
      final Set<int> staleIds = pushedIds.difference(currentIds);

      // Purge notifications that were dismissed on phone while disconnected
      if (staleIds.isNotEmpty) {
        logger.info('purging stale notifications from watch on sync', {
          'staleCount': staleIds.length,
        });
        final dismissProto = NotificationDismiss();
        for (final id in staleIds) {
          dismissProto.notificationId.add(NotificationId()..id = id & 0xFFFFFFFF);
        }
        await DeviceModule.module.connection.send(
          type: CmdType.notification,
          subtype: NotificationSubtype.dismiss,
          builder: (cmd) => cmd.notification = (Notification()..notificationDismiss = dismissProto),
        );
      }

      // Only push notifications that have not been pushed to the watch yet
      final newItems = items.where((i) => !pushedIds.contains(i.id)).toList();

      if (newItems.isNotEmpty) {
        logger.info('pushing new active notification list batch to watch', {
          'newItemCount': newItems.length,
        });

        await DeviceModule.module.connection.send(
          type: CmdType.notification,
          subtype: NotificationSubtype.push,
          builder:
              (cmd) =>
                  cmd.notification = (Notification()
                    ..notificationList =
                        (NotificationList()
                          ..notificationItem.addAll(newItems))),
        );
      } else {
        logger.info('all active notifications already pushed to watch, skipping push');
      }

      PushedBlob.setAll(currentIds);
    } catch (e) {
      logger.error('failed to sync active notifications catch-up: $e');
    }
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

  NotificationItem? _buildNotificationItem(Map<String, dynamic> data) {
    final String package = data['package'] ?? '';
    final String kind = data['kind'] ?? 'standard';
    final bool call = kind == 'call';
    final bool sms = kind == 'text';
    final bool isEmail = kind == 'email';

    // See if we allow this notification based on contact/app settings
    final bool allowed;
    if (call) {
      allowed = ContactBlob.contact.callEnabled;
    } else if (sms) {
      allowed = ContactBlob.contact.textEnabled;
    } else if (isEmail) {
      allowed = ContactBlob.contact.emailEnabled;
    } else {
      allowed = AppsBlob.map[package] == true;
    }

    if (!allowed) {
      return null;
    }

    final String title = data['title'] ?? '';
    final String body = data['body'] ?? '';
    final int id = data['id'] ?? 0;
    final String key = (data['key'] ?? '').toString().toLowerCase();

    final String app =
        data['app'] != null && (data['app'] as String).isNotEmpty
            ? data['app']
            : package.split('.').last;

    final rawTimestamp = data['timestamp'];
    final DateTime notifTime;
    if (rawTimestamp is num && rawTimestamp > 0) {
      notifTime = DateTime.fromMillisecondsSinceEpoch(rawTimestamp.toInt());
    } else {
      notifTime = DateTime.now();
    }

    final timestampStr =
        notifTime
            .toIso8601String()
            .replaceAll('-', '')
            .replaceAll(':', '')
            .split('.')
            .first;

    return NotificationItem()
      ..package = package
      ..appName = app
      ..title = title
      ..body = body
      ..id = id & 0xFFFFFFFF
      ..key = key
      ..unknown4 = ''
      ..timestamp = timestampStr
      ..repliesAllowed = true
      ..openOnPhone = true;
  }

  void _handlePhoneNotificationReceived(Map<String, dynamic> data) async {
    final item = _buildNotificationItem(data);
    if (item == null) {
      return;
    }

    PushedBlob.add(item.id);

    logger.info('pushing phone notification to watch', {
      'package': item.package,
      'app': item.appName,
      'title': item.title,
      'body': item.body,
      'id': item.id,
      'key': item.key,
    });

    await DeviceModule.module.connection.send(
      type: CmdType.notification,
      subtype: NotificationSubtype.push,
      builder:
          (cmd) =>
              cmd.notification = (Notification()
                ..notificationList =
                    (NotificationList()..notificationItem.add(item))),
    );
  }

  void _handlePhoneNotificationRemoved(Map<String, dynamic> data) async {
    final String package = data['package'] ?? '';
    final String category = data['category'] ?? '';
    final String key = (data['key'] ?? '').toString().toLowerCase();
    final int id = data['id'] ?? 0;

    PushedBlob.remove(id & 0xFFFFFFFF);

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

  Future<void> _handleWatchNotificationReply(Command cmd) async {
    if (!cmd.hasNotification() || !cmd.notification.hasNotificationReply()) {
      return;
    }

    final reply = cmd.notification.notificationReply;

    logger.info('received notification reply from watch', {
      'id': reply.unknown1,
      'message': reply.message,
    });

    try {
      await PlatformModule.module.invokeMethod(
        'notifications.replyToNotification',
        {'id': reply.unknown1, 'message': reply.message},
      );
    } catch (e) {
      logger.error('failed to reply to notification: $e');
    }
  }

  Future<void> _handleWatchNotificationDismiss(Command cmd) async {
    if (!cmd.hasNotification() || !cmd.notification.hasNotificationDismiss()) {
      return;
    }

    final dismiss = cmd.notification.notificationDismiss;
    if (dismiss.notificationId.isEmpty) return;

    // If multiple notifications dismissed at once (e.g. Clear All), clear all on phone status bar and exit early
    if (dismiss.notificationId.length > 1) {
      logger.info('watch dismissed multiple notifications at once (clearing on phone)', {
        'count': dismiss.notificationId.length,
      });
      for (var notifId in dismiss.notificationId) {
        try {
          await PlatformModule.module.invokeMethod(
            'notifications.dismissNotification',
            {'id': notifId.id},
          );
        } catch (e) {
          logger.error('failed to dismiss notification on phone: $e');
        }
      }
      return;
    }

    // Single notification dismissed
    final int id = dismiss.notificationId.first.id;

    final Map? meta = await PlatformModule.module.invokeMethod<Map>(
      'notifications.getNotificationMeta',
      {'id': id},
    );

    final String kind = meta?['kind']?.toString() ?? 'standard';
    final bool replyable = meta?['replyable'] as bool? ?? false;

    if (kind == 'email') {
      _dismissedId = id;
      logger.debug(
        'watch dismissed single email notification (launching watch emails app)',
        {'id': id},
      );

      final hapUri = 'hap://app/$emailsPackage/pages/index';
      await AppsModule.module.launchApp(emailsPackage, uri: hapUri);
    } else if (replyable || kind == 'text' || kind == 'call') {
      _dismissedId = id;
      logger.debug(
        'watch dismissed single replyable notification (launching watch messages app)',
        {'id': id, 'kind': kind},
      );

      final hapUri = 'hap://app/$messagesPackage/pages/index';
      await AppsModule.module.launchApp(messagesPackage, uri: hapUri);
    } else {
      logger.debug(
        'watch dismissed non-replyable notification (dismissing on phone status bar)',
        {'id': id, 'kind': kind},
      );

      try {
        await PlatformModule.module.invokeMethod(
          'notifications.dismissNotification',
          {'id': id},
        );
      } catch (e) {
        logger.error('failed to dismiss notification on phone: $e');
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
    final String targetPkg = msg.appInfo.packageName;
    if (targetPkg != messagesPackage && targetPkg != emailsPackage) {
      return;
    }

    final String text = utf8.decode(msg.content);
    final data = jsonDecode(text) as Map<String, dynamic>;
    final command = data['command']?.toString();
    final int? rawId = data['id'] is int
        ? data['id'] as int
        : int.tryParse(data['id']?.toString() ?? '');
    final int? id = (rawId != null && rawId != 0) ? rawId : _dismissedId;

    if (targetPkg == emailsPackage) {
      logger.debug('received message from watch Emails app', {'payload': data});
      if (command == 'getDismissedId') {
        await _handleWatchGetDismissedId(emailsPackage);
      } else if (command == 'dismiss') {
        await _handleWatchDismiss(id);
      } else if (command == 'archive' || command == 'delete') {
        await _handleWatchEmailAction(id, command!);
      } else if (command == 'open') {
        await _handleWatchEmailOpen(id);
      }
    } else {
      logger.debug('received message from watch Messages app', {
        'payload': data,
      });

      if (command == 'getDismissedId') {
        await _handleWatchGetDismissedId(messagesPackage);
      } else if (command == 'getReplies') {
        await _handleWatchGetReplies(messagesPackage);
      } else if (command == 'reply') {
        final replyText = data['text']?.toString() ?? '';
        await _handleWatchReply(id, replyText);
      } else if (command == 'dismiss') {
        await _handleWatchDismiss(id);
      }
    }
  }

  Future<void> _handleWatchEmailAction(int? id, String action) async {
    if (id != null && id != 0) {
      logger.info('received email action from watch Emails app', {
        'id': id,
        'action': action,
      });
      try {
        await PlatformModule.module.invokeMethod(
          'notifications.triggerNotificationAction',
          {'id': id, 'action': action},
        );
      } catch (e) {
        logger.error('failed to trigger notification action: $e');
      }
    }
    _dismissedId = null;
  }

  Future<void> _handleWatchEmailOpen(int? id) async {
    if (id != null && id != 0) {
      logger.info('received email open from watch Emails app', {'id': id});
      try {
        await PlatformModule.module.invokeMethod(
          'notifications.openNotificationOnPhone',
          {'id': id},
        );
      } catch (e) {
        logger.error('failed to open notification on phone: $e');
      }
    }
    _dismissedId = null;
  }

  Future<void> _handleWatchGetDismissedId(String targetPkg) async {
    final Map<String, dynamic> payload = {'dismissedId': _dismissedId ?? 0};

    final jsonPayload = jsonEncode(payload);
    final appInfo = ThirdPartyAppInfo()..packageName = targetPkg;
    final installed = app_registry.AppsBlob.instance.value[targetPkg];
    if (installed != null && installed.fingerprint.isNotEmpty) {
      appInfo.fingerprint = installed.fingerprint;
    }

    final appMessage = ThirdPartyAppMessage()
      ..appInfo = appInfo
      ..content = Uint8List.fromList(utf8.encode(jsonPayload));

    logger.debug(
      'sending getDismissedId response to watch app ($targetPkg)',
      payload,
    );

    await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.sendPhoneMessage,
      builder: (replyCmd) =>
          replyCmd.thirdPartyApp = (ThirdPartyApp()..message = appMessage),
    );
  }

  Future<void> _handleWatchGetReplies(String targetPkg) async {
    final Map<String, dynamic> payload = {'replies': RepliesBlob.list};

    final jsonPayload = jsonEncode(payload);
    final appInfo = ThirdPartyAppInfo()..packageName = targetPkg;
    final installed = app_registry.AppsBlob.instance.value[targetPkg];
    if (installed != null && installed.fingerprint.isNotEmpty) {
      appInfo.fingerprint = installed.fingerprint;
    }

    final appMessage = ThirdPartyAppMessage()
      ..appInfo = appInfo
      ..content = Uint8List.fromList(utf8.encode(jsonPayload));

    logger.debug(
      'sending getReplies response to watch app ($targetPkg)',
      payload,
    );

    await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.sendPhoneMessage,
      builder: (replyCmd) =>
          replyCmd.thirdPartyApp = (ThirdPartyApp()..message = appMessage),
    );
  }

  Future<void> _handleWatchReply(int? id, String text) async {
    logger.info('received notification quick reply from watch', {
      'id': id,
      'message': text,
    });

    if (id != null && id != 0) {
      try {
        await PlatformModule.module.invokeMethod(
          'notifications.replyToNotification',
          {'id': id, 'message': text},
        );
      } catch (e) {
        logger.error('failed to reply to notification: $e');
      }

      try {
        await PlatformModule.module.invokeMethod(
          'notifications.dismissNotification',
          {'id': id},
        );
      } catch (e) {
        logger.error('failed to dismiss notification: $e');
      }
    }
    _dismissedId = null;
  }

  Future<void> _handleWatchDismiss(int? id) async {
    if (id != null && id != 0) {
      logger.info('received dismiss from watch app', {'id': id});
      try {
        await PlatformModule.module.invokeMethod(
          'notifications.dismissNotification',
          {'id': id},
        );
      } catch (e) {
        logger.error('failed to dismiss notification: $e');
      }
    }
    _dismissedId = null;
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
    final contact = ContactBlob.contact;
    if (contact.callEnabled || contact.textEnabled) {
      await AppsModule.module.enableInternalApp(messagesPackage);
    } else {
      await AppsModule.module.disableInternalApp(messagesPackage);
    }

    if (contact.emailEnabled) {
      await AppsModule.module.enableInternalApp('com.misync.emails');
    } else {
      await AppsModule.module.disableInternalApp('com.misync.emails');
    }
  }

  Future<void> _setPhoneDnd(bool dnd) async {
    if (!DndBlob.enabled) return;
    try {
      final currentPhoneDnd = await _getPhoneDnd();
      if (currentPhoneDnd != dnd) {
        await PlatformModule.module.invokeMethod('notifications.setDnd', {
          'enabled': dnd,
        });
      }
    } catch (e) {
      logger.error('failed to set phone DND state: $e');
    }
  }

  Future<bool> _getPhoneDnd() async {
    try {
      final dnd = await PlatformModule.module.invokeMethod<bool>(
        'notifications.getDnd',
      );
      return dnd ?? false;
    } catch (e) {
      logger.error('failed to get phone DND state: $e');
      rethrow;
    }
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

  Future<void> saveContact({
    bool? callEnabled,
    bool? textEnabled,
    bool? emailEnabled,
  }) async {
    final old = ContactBlob.contact;
    final updated = Contact(
      callEnabled: callEnabled ?? old.callEnabled,
      textEnabled: textEnabled ?? old.textEnabled,
      emailEnabled: emailEnabled ?? old.emailEnabled,
    );
    ContactBlob.contact = updated;
    await _syncContact();
    logger.info('contact sync state updated', updated.toJson());
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
