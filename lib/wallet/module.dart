import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../device/module.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/proto/constants.dart';
import '../platform/module.dart';
import '../apps/blobs/apps.dart' as app_registry;
import '../apps/module.dart';
import '../screen.dart';
import 'blobs/passes.dart';
import 'blobs/wallet.dart';
import 'screen.dart';

class WalletModule extends TabModule {
  @override
  String get name => 'wallet';

  @override
  IconData get icon => Icons.wallet;

  @override
  late final Screen screen = WalletScreen(this);

  static final WalletModule _module = WalletModule._();
  static WalletModule get module => _module;
  WalletModule._();

  @override
  Future<void> start() async {
    WalletBlob.instance.addListener(sync);
    PassesBlob.instance.addListener(sync);
    DeviceModule.module.register(this);
    PlatformModule.module.register(_receivePhoneMethod);
    DeviceModule.module.connection.listen(_receiveWatchCommand);
    await _startPendingPass();
  }

  Future<void> _startPendingPass() async {
    try {
      final data = await PlatformModule.module.invokeMethod<Map>(
        'wallet.getPendingPass',
      );
      if (data != null) {
        logger.info('Found pending pkpass on startup');
        final pass = Pass.fromJson(Map<String, dynamic>.from(data));
        await PassesBlob.instance.addPass(pass);
      }
    } catch (e) {
      logger.error('Failed to query pending pass on startup: $e');
    }
  }

  Future<dynamic> _receivePhoneMethod(MethodCall call) async {
    if (call.method == 'passIntercepted') {
      logger.info('Received passIntercepted callback from native side');
      final data = Map<String, dynamic>.from(call.arguments);
      final pass = Pass.fromJson(data);
      await PassesBlob.instance.addPass(pass);
    }
  }

  void _receiveWatchCommand(pb.Command cmd) {
    if (cmd.type == CmdType.thirdPartyApp.value &&
        cmd.subtype == ThirdPartyAppSubtype.sendWearMessage.value &&
        cmd.hasThirdPartyApp() &&
        cmd.thirdPartyApp.hasMessage()) {
      _handleWatchMessage(cmd);
    }
  }

  Future<void> _handleWatchMessage(pb.Command cmd) async {
    final message = cmd.thirdPartyApp.message;
    if (message.appInfo.packageName != 'com.misync.wallet') {
      return;
    }

    final String text = utf8.decode(message.content);
    logger.info('received message from watch Wallet app: $text');

    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      final command = data['command']?.toString();
      if (command == 'getPasses') {
        await _sendPassesToWatch();
      }
    } catch (e) {
      logger.error('failed to parse watch message: $e');
    }
  }

  Future<void> _sendPassesToWatch() async {
    final passesList = PassesBlob.passes;
    final List<Map<String, dynamic>> passesJson = passesList
        .map(
          (p) => {
            'organizationName': p.organizationName,
            'description': p.description,
            'serialNumber': p.serialNumber,
            'passTypeIdentifier': p.passTypeIdentifier,
            'barcodeMessage': p.barcodeMessage,
            'barcodeFormat': p.barcodeFormat,
          },
        )
        .toList();

    final payload = {'passes': passesJson};
    final jsonPayload = jsonEncode(payload);

    final appInfo = pb.ThirdPartyAppInfo()..packageName = 'com.misync.wallet';
    final installed = app_registry.AppsBlob.instance.value['com.misync.wallet'];
    if (installed != null && installed.fingerprint.isNotEmpty) {
      appInfo.fingerprint = installed.fingerprint;
    }

    final appMessage = pb.ThirdPartyAppMessage()
      ..appInfo = appInfo
      ..content = Uint8List.fromList(utf8.encode(jsonPayload));

    logger.info('sending passes to watch', payload);

    try {
      await DeviceModule.module.connection.send(
        type: CmdType.thirdPartyApp,
        subtype: ThirdPartyAppSubtype.sendPhoneMessage,
        builder: (replyCmd) =>
            replyCmd.thirdPartyApp = (pb.ThirdPartyApp()..message = appMessage),
      );
    } catch (e) {
      logger.error('failed to send passes to watch: $e');
    }
  }

  @override
  Future<void> sync() async {
    await _syncExpiredPasses();
    await _syncWatchWalletApp();
    if (DeviceModule.module.connection.connected.value) {
      await _sendPassesToWatch();
    }
  }

  Future<void> _syncWatchWalletApp() async {
    final wallet = WalletBlob.instance.value;
    if (wallet.enabled) {
      await AppsModule.module.enableInternalApp('com.misync.wallet');
    } else {
      await AppsModule.module.disableInternalApp('com.misync.wallet');
    }
  }

  Future<void> _syncExpiredPasses() async {
    final retentionDays = WalletBlob.instance.value.retentionDays;
    if (retentionDays <= 0) return; // 0 means Unlimited/Never delete

    final threshold = DateTime.now().subtract(Duration(days: retentionDays));
    final list = List<Pass>.from(PassesBlob.passes);
    final countBefore = list.length;
    list.removeWhere((pass) => pass.createdAt.isBefore(threshold));

    if (list.length != countBefore) {
      await PassesBlob.instance.update(list);
    }
  }
}
