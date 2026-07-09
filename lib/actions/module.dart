import 'dart:convert';
import 'package:flutter/material.dart';
import '../module.dart';
import '../device/connection.dart';
import '../device/proto/xiaomi.pb.dart';
import '../device/proto/constants.dart';
import '../debug/logger.dart';
import '../platform/module.dart';
import 'blobs/actions.dart';
import 'screen.dart';

class ActionsModule implements TabModule {
  @override
  String get name => 'actions';

  @override
  IconData get icon => Icons.touch_app;

  @override
  Widget get screen => const ActionsScreen();
  static final ActionsModule _instance = ActionsModule._();
  static ActionsModule get instance => _instance;
  ActionsModule._();

  @override
  Future<void> start() async {
    DeviceConnection.listen((cmd) async {
      // 1. Handle app status queries (subtype 6)
      if (cmd.type == 20 && cmd.subtype == 6) {
        if (cmd.hasThirdPartyApp() && cmd.thirdPartyApp.hasAppStatusReq()) {
          final req = cmd.thirdPartyApp.appStatusReq;
          Logger.info('actions', 'Watch queried app status for: ${req.packageName}');

          await DeviceConnection.send(
            type: CmdType.thirdPartyApp,
            subtype: 7, // status response
            builder: (replyCmd) {
              replyCmd.thirdPartyApp = ThirdPartyApp()
                ..appStatusResp = (ThirdPartyAppStatus()
                  ..appInfo = req
                  ..status = 1 // connected/running
                );
            },
          );
          Logger.info('actions', 'Replied with app status: connected');
        }
      }

      // 2. Handle data messages from the watch app (subtype 9)
      if (cmd.type == 20 && cmd.subtype == 9) {
        if (cmd.hasThirdPartyApp() && cmd.thirdPartyApp.hasMessage()) {
          final msg = cmd.thirdPartyApp.message;
          try {
            final String text = utf8.decode(msg.content);
            Logger.info('actions', 'Received message from watch app: $text');
            handleWatchMessage(text);
          } catch (e) {
            Logger.error('actions', 'Failed to decode watch message content: $e');
          }
        }
      }
    });
  }

  @override
  Future<void> sync() async {}

  void handleWatchMessage(String messageText) {
    Logger.info('actions', 'Parsing message from watch: $messageText');

    // 1. Try parsing as JSON
    try {
      final dynamic data = jsonDecode(messageText);
      if (data is Map) {
        final id = data['actionId']?.toString();
        if (id != null) {
          triggerActionById(id);
          return;
        }
        final intent = data['intent']?.toString();
        if (intent != null) {
          final package = data['package']?.toString() ?? '';
          final name = data['name']?.toString() ?? 'Custom Action';
          _triggerAction({
            'id': 'custom',
            'name': name,
            'intent': intent,
            'package': package,
          });
          return;
        }
      }
    } catch (_) {}

    // 2. Try matching by ID
    final idMatch = ActionsBlob.list.firstWhere(
      (a) => a['id'] == messageText.trim(),
      orElse: () => const {},
    );
    if (idMatch.isNotEmpty) {
      _triggerAction(idMatch);
      return;
    }

    // 3. Try matching by Name
    final nameMatch = ActionsBlob.list.firstWhere(
      (a) => a['name']?.toLowerCase().trim() == messageText.toLowerCase().trim(),
      orElse: () => const {},
    );
    if (nameMatch.isNotEmpty) {
      _triggerAction(nameMatch);
      return;
    }

    // 4. Try matching by package name or raw intent action
    if (messageText.contains('.')) {
      _triggerAction({
        'id': 'raw',
        'name': messageText,
        'intent': messageText,
        'package': messageText.split('.').first,
      });
      return;
    }

    Logger.warning('actions', 'Could not map watch message "$messageText" to any action');
  }

  void triggerActionById(String id) {
    final action = ActionsBlob.list.firstWhere(
      (a) => a['id'] == id,
      orElse: () => const {},
    );
    if (action.isNotEmpty) {
      _triggerAction(action);
    } else {
      Logger.warning('actions', 'No action found with ID: $id');
    }
  }

  void _triggerAction(Map<String, String> action) async {
    final name = action['name'] ?? '';
    final intent = action['intent'] ?? '';
    final package = action['package'] ?? '';
    Logger.info('actions', 'Triggering intent action: $name (intent=$intent, package=$package)');

    final Map<String, String> extras = {};
    if (intent == 'net.dinglisch.android.taskerm.ACTION_TASK') {
      extras['task_name'] = name;
    }

    try {
      final bool? success = await PlatformModule.instance.invokeMethod<bool>('launchAction', {
        'intent': intent,
        'package': package,
        'extras': extras,
      });
      Logger.info('actions', 'Action trigger result: $success');
    } catch (e) {
      Logger.error('actions', 'Failed to invoke launchAction: $e');
    }
  }
}
