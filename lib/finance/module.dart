import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:misync/screen.dart';
import '../device/module.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../device/proto/constants.dart';
import '../platform/module.dart';
import '../apps/module.dart';
import '../apps/blobs/apps.dart' as app_registry;
import 'blobs/finance.dart';
import 'blobs/investments.dart';
import 'sources/alpaca.dart';
import 'screen.dart';

class FinanceModule extends TabModule {
  @override
  String get name => 'finance';

  @override
  IconData get icon => Icons.monetization_on;

  @override
  late final Screen screen = FinanceScreen(this);

  static final FinanceModule _module = FinanceModule._();
  static FinanceModule get module => _module;
  FinanceModule._();

  @override
  Future<void> start() async {
    DeviceModule.module.register(this);
    DeviceModule.module.connection.listen(_receiveWatchCommand);
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
    if (message.appInfo.packageName != 'com.misync.investments') {
      return;
    }

    final String text = utf8.decode(message.content);
    logger.info('received message from watch Investments app: $text');

    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      final command = data['command']?.toString();
      if (command == 'getWatchlists') {
        await _handleWatchGetWatchlists();
      }
    } catch (e) {
      logger.error('failed to parse watch message: $e');
    }
  }

  Future<void> _handleWatchGetWatchlists() async {
    final investments = InvestmentsBlob.investments;
    final List<Map<String, dynamic>> watchlistsJson = investments.watchlists
        .map(
          (w) => {
            'name': w.name,
            'investments': w.items
                .map(
                  (i) => {
                    'symbol': i.symbol,
                    'price': i.price,
                    'change': i.change,
                  },
                )
                .toList(),
          },
        )
        .toList();

    final payload = {'response': watchlistsJson};
    final jsonPayload = jsonEncode(payload);

    final appInfo = pb.ThirdPartyAppInfo()
      ..packageName = 'com.misync.investments';
    final installed =
        app_registry.AppsBlob.instance.value['com.misync.investments'];
    if (installed != null && installed.fingerprint.isNotEmpty) {
      appInfo.fingerprint = installed.fingerprint;
    }

    final appMessage = pb.ThirdPartyAppMessage()
      ..appInfo = appInfo
      ..content = Uint8List.fromList(utf8.encode(jsonPayload));

    logger.info('sending investments watchlists to watch', payload);

    await DeviceModule.module.connection.send(
      type: CmdType.thirdPartyApp,
      subtype: ThirdPartyAppSubtype.sendPhoneMessage,
      builder: (replyCmd) =>
          replyCmd.thirdPartyApp = (pb.ThirdPartyApp()..message = appMessage),
    );
  }

  Future<void> saveInvestments(Investments updated) async {
    await InvestmentsBlob.instance.update(updated);
    await sync();
  }

  Future<void> saveWatchlist(
    String watchlistId,
    String name,
    List<String> symbols,
  ) async {
    final sourceId = FinanceBlob.getSource('investments');
    if (sourceId == 'alpaca') {
      final investments = InvestmentsBlob.investments;
      try {
        final source = AlpacaSource();
        await source.saveWatchlist(
          investments.apiKey,
          investments.secretKey,
          watchlistId,
          name,
          symbols,
        );
        logger.info('watchlist updated successfully on Alpaca');
      } catch (e) {
        logger.error('failed to save watchlist to Alpaca: $e');
      }
    }
  }

  @override
  Future<void> sync() async {
    await _syncInvestments();
  }

  Future<void> _syncInvestments() async {
    final enabled = FinanceBlob.isSubtypeEnabled('investments');
    if (enabled) {
      await AppsModule.module.enableInternalApp('com.misync.investments');
    } else {
      await AppsModule.module.disableInternalApp('com.misync.investments');
      return;
    }

    final sourceId = FinanceBlob.getSource('investments');
    if (sourceId == 'none') return;

    final investments = InvestmentsBlob.investments;
    if (investments.apiKey.isEmpty || investments.secretKey.isEmpty) {
      logger.error('API credentials incomplete. Skipping fetch.');
      return;
    }

    if (sourceId == 'alpaca') {
      try {
        final source = AlpacaSource();
        final watchlists = await source.getWatchlists(
          investments.apiKey,
          investments.secretKey,
        );

        await InvestmentsBlob.instance.update(
          investments.copyWith(watchlists: watchlists),
        );
        logger.info('investments data synced and cached successfully');

        await updateWidget();

        if (DeviceModule.module.connection.connected.value) {
          await _handleWatchGetWatchlists();
        }
      } catch (e) {
        logger.error('error during investments API sync: $e');
      }
    }
  }

  Future<void> updateWidget() async {
    try {
      await PlatformModule.module.invokeMethod(
        'finance.updateInvestmentsWidget',
      );
      logger.info('sent request to update android investments widget');
    } catch (e) {
      logger.error('failed to update android widget: $e');
    }
  }
}
