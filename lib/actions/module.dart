import 'dart:convert';
import 'package:flutter/material.dart' hide Action;
import '../module.dart';
import '../device/connection.dart';
import '../device/proto/xiaomi.pb.dart';
import '../device/proto/constants.dart';
import '../debug/logger.dart';
import '../platform/module.dart';
import 'blobs/actions.dart';
import 'screen.dart';

class ActionsModule extends TabModule {
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
    DeviceConnection.listen(_receiveWatchCommand);
  }

  @override
  Future<void> sync() async {}

  Future<void> _receiveWatchCommand(Command cmd) async {
    if (cmd.type == CmdType.thirdPartyApp.value &&
        cmd.subtype == ThirdPartyAppSubtype.sendWearMessage.value) {
      await _handleWatchMessage(cmd);
    }
  }

  Future<void> _handleWatchMessage(Command cmd) async {
    if (cmd.hasThirdPartyApp() && cmd.thirdPartyApp.hasMessage()) {
      final msg = cmd.thirdPartyApp.message;
      try {
        final String text = utf8.decode(msg.content);
        Logger.info('actions', 'Received message from watch app: $text');

        final data = jsonDecode(text) as Map<String, dynamic>;
        await _handleWatchAction(data);
      } catch (e) {
        Logger.error(
          'actions',
          'Failed to decode or parse watch message content: $e',
        );
      }
    }
  }

  Future<void> _handleWatchAction(Map<String, dynamic> data) async {
    // 1. Check if the watch sends an action name: e.g. { "action": "Mute Phone" }
    final actionName = data['action']?.toString().trim();
    if (actionName != null && actionName.isNotEmpty) {
      final action = ActionsBlob.map[actionName];
      if (action != null) {
        runPhoneAction(action);
      } else {
        Logger.info('actions', 'No action configured for name: $actionName');
      }
    } else {
      Logger.info('actions', 'Invalid action payload received: $data');
    }
  }

  void runPhoneAction(Action action) async {
    final name = action.name;
    final intent = action.intent;
    final package = action.package;
    Logger.info(
      'actions',
      'Triggering intent action: $name (intent=$intent, package=$package)',
    );

    final Map<String, String> extras = {};
    if (intent == 'net.dinglisch.android.taskerm.ACTION_TASK') {
      extras['task_name'] = name;
    }

    try {
      final bool? success = await PlatformModule.instance.invokeMethod<bool>(
        'launchAction',
        {'intent': intent, 'package': package, 'extras': extras},
      );
      Logger.info('actions', 'Action trigger result: $success');
    } catch (e) {
      Logger.error('actions', 'Failed to invoke launchAction: $e');
    }
  }
}
