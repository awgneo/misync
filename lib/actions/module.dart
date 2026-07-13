import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart' hide Action;
import 'package:misync/screen.dart';
import '../device/proto/xiaomi.pb.dart';
import '../device/proto/constants.dart';
import '../platform/module.dart';
import 'blobs/actions.dart';
import 'screen.dart';
import '../device/module.dart';
import '../apps/blobs/apps.dart' as app_registry;

class ActionsModule extends TabModule {
  @override
  String get name => 'actions';

  @override
  IconData get icon => Icons.touch_app;

  @override
  late final Screen screen = ActionsScreen(this);

  static final ActionsModule _module = ActionsModule._();
  static ActionsModule get module => _module;
  ActionsModule._();

  @override
  Future<void> start() async {
    DeviceModule.module.connection.listen(_receiveWatchCommand);
  }

  @override
  Future<void> sync() async {}

  Future<void> _receiveWatchCommand(Command cmd) async {
    if (cmd.type == CmdType.thirdPartyApp.value &&
        cmd.subtype == ThirdPartyAppSubtype.sendWearMessage.value &&
        cmd.hasThirdPartyApp() &&
        cmd.thirdPartyApp.hasMessage()) {
      await _handleWatchMessage(cmd);
    }
  }

  Future<void> _handleWatchMessage(Command cmd) async {
    final message = cmd.thirdPartyApp.message;
    if (message.appInfo.packageName != 'com.misync.actions') {
      return;
    }

    final String text = utf8.decode(message.content);
    logger.info('received message from watch Actions app: $text');
    final data = jsonDecode(text) as Map<String, dynamic>;

    final command = data['command']?.toString();
    if (command == 'getActions') {
      await _handleWatchGetActions();
    } else if (command == 'launchAction') {
      await _handleWatchLaunchAction(data);
    }
  }

  Future<void> _handleWatchGetActions() async {
    final List<Map<String, String>> actionList = ActionsBlob.map.values
        .map((action) => {
              'name': action.name,
              'icon': action.icon,
            })
        .toList();

    final actionsPayload = {'response': actionList};

    final jsonPayload = jsonEncode(actionsPayload);
    final appInfo = ThirdPartyAppInfo()..packageName = 'com.misync.actions';
    final installed =
        app_registry.AppsBlob.instance.value['com.misync.actions'];
    if (installed != null && installed.fingerprint.isNotEmpty) {
      appInfo.fingerprint = installed.fingerprint;
    }

    final appMessage = ThirdPartyAppMessage()
      ..appInfo = appInfo
      ..content = Uint8List.fromList(utf8.encode(jsonPayload));

    logger.info('sending actions list to watch', actionsPayload);

    await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.sendPhoneMessage,
      builder: (replyCmd) =>
          replyCmd.thirdPartyApp = (ThirdPartyApp()..message = appMessage),
    );
  }

  Future<void> _handleWatchLaunchAction(Map<String, dynamic> data) async {
    // Check if the watch sends an action name: e.g. { "action": "Mute Phone" }
    final actionName = data['action']?.toString().trim();
    if (actionName == null || actionName.isEmpty) {
      logger.info('Invalid action payload received: $data');
      return;
    }

    final action = ActionsBlob.map[actionName];
    if (action != null) {
      runAction(action);
    } else {
      logger.info('No action configured for name: $actionName');
    }
  }

  void runAction(Action action) async {
    final name = action.name;
    final intent = action.intent;
    final package = action.package;
    logger.info(
      'Triggering intent action: $name (intent=$intent, package=$package, uri=${action.uri})',
    );

    final Map<String, String> extras = {};
    if (intent == 'net.dinglisch.android.taskerm.ACTION_TASK') {
      extras['task_name'] = name;
    }
    if (action.extras != null) {
      extras.addAll(action.extras!);
    }

    final bool? success = await PlatformModule.module.invokeMethod<bool>(
      'actions.launchAction',
      {
        'intent': intent,
        'package': package,
        'uri': action.uri,
        'extras': extras,
      },
    );

    logger.info('Action trigger result: $success');
  }

  void addAction(Action action) {
    final updated = Map<String, Action>.from(ActionsBlob.map)
      ..[action.name] = action;
    ActionsBlob.instance.update(updated);
    logger.info('Added action: ${action.name}');
  }

  void editAction(String oldName, Action action) {
    final updated = Map<String, Action>.from(ActionsBlob.map);
    if (oldName != action.name) {
      updated.remove(oldName);
    }
    updated[action.name] = action;
    ActionsBlob.instance.update(updated);
    logger.info('Edited action: $oldName -> ${action.name}');
  }

  void deleteAction(String name) {
    final updated = Map<String, Action>.from(ActionsBlob.map)..remove(name);
    ActionsBlob.instance.update(updated);
    logger.info('Deleted action: $name');
  }
}
