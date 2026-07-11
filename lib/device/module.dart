import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import 'blobs/settings.dart';
import 'proto/constants.dart';
import 'proto/xiaomi.pb.dart';
import 'blobs/device.dart';
import '../module.dart';
import '../platform/module.dart';
import '../debug/logger.dart';
import 'connection.dart';
import 'screen.dart';
import 'pairing/extractor.dart';

class DeviceModule extends TabModule {
  @override
  String get name => 'device';

  @override
  IconData get icon => Icons.link;

  @override
  Widget get screen => const DeviceScreen();

  @override
  List<String> get permissions => const ['companion'];

  static final DeviceModule _instance = DeviceModule._();
  static DeviceModule get instance => _instance;
  DeviceModule._();

  final List<Module> _modules = [];
  bool _deviceAssociated = false;
  Timer? _syncTimer;
  int? _syncInterval;
  bool _syncing = false;

  void register(Module module) {
    _modules.add(module);
  }

  @override
  Future<void> start() async {
    DeviceConnection.logger = logger;
    _startDeviceCompanionship();
    PlatformModule.instance.register(_receivePhoneMethod);
    DeviceConnection.connected.addListener(_watchConnectionChanged);
    DeviceConnection.listen(_receiveWatchCommand);
    SettingsBlob.instance.addListener(_settingsChanged);
    DeviceConnection.connect();
    _startSyncInterval();
  }

  void _startDeviceCompanionship() async {
    _deviceAssociated =
        await PlatformModule.instance.invokeMethod('getDeviceAssociated') ??
        false;
    if (_deviceAssociated) {
      _observeDevicePresence();
    }
  }

  Future<dynamic> _receivePhoneMethod(MethodCall call) async {
    switch (call.method) {
      case 'deviceAssociated':
        _deviceAssociated = true;
        logger.info('device associated');
        _observeDevicePresence();
        break;
      case 'deviceUnassociated':
        _deviceAssociated = false;
        logger.info('device unassociated');
        break;
    }
  }

  void _observeDevicePresence() async {
    if (_deviceAssociated) {
      await PlatformModule.instance.invokeMethod('observeDevicePresence');
    }
  }

  Future<bool> extractDeviceCredentials(String path, String filename) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final creds = Extractor.extractFromBytes(bytes, filename);
    if (creds == null) {
      return false;
    }

    await SettingsBlob.instance.update(
      Settings(
        authKeyHex: creds.authKey,
        watchMac: creds.macAddress,
        deviceId: creds.deviceId,
        deviceModel: creds.model,
        syncIntervalMinutes: SettingsBlob.syncIntervalMinutes,
      ),
    );

    return true;
  }

  void _watchConnectionChanged() {
    if (DeviceConnection.connected.value) {
      sync();
    }
  }

  void _receiveWatchCommand(Command cmd) {
    if (cmd.type == CmdType.system.value) {
      if (cmd.subtype == SystemSubtype.deviceInfo.value) {
        _handleWatchDeviceInfo(cmd);
      } else if (cmd.subtype == SystemSubtype.battery.value) {
        _handleWatchBattery(cmd);
      } else if (cmd.subtype == SystemSubtype.deviceState.value) {
        _handleWatchDeviceState(cmd);
      }
    }
  }

  void _handleWatchDeviceInfo(Command cmd) {
    if (!cmd.system.hasDeviceInfo()) return;
    final info = cmd.system.deviceInfo;
    final current = DeviceBlob.infoState;

    logger.info(
      'received device info: serial=${info.serialNumber}, firmware=${info.firmware}, model=${info.model}',
    );

    DeviceBlob.instance.update(
      DeviceInfoState(
        serialNumber: info.serialNumber,
        firmwareVersion: info.firmware,
        model: info.model,
        batteryLevel: current.batteryLevel,
        isCharging: current.isCharging,
        isWorn: current.isWorn,
        isUserAsleep: current.isUserAsleep,
      ),
    );
  }

  void _handleWatchBattery(Command cmd) {
    if (!cmd.system.hasPower() || !cmd.system.power.hasBattery()) return;
    final battery = cmd.system.power.battery;
    final current = DeviceBlob.infoState;

    logger.info(
      'received battery state: level=${battery.level}, state=${battery.state}',
    );

    DeviceBlob.instance.update(
      DeviceInfoState(
        serialNumber: current.serialNumber,
        firmwareVersion: current.firmwareVersion,
        model: current.model,
        batteryLevel: battery.level,
        isCharging: battery.state == 1 || battery.state == 3,
        isWorn: current.isWorn,
        isUserAsleep: current.isUserAsleep,
      ),
    );
  }

  void _handleWatchDeviceState(Command cmd) {
    if (!cmd.system.hasBasicDeviceState()) return;
    final state = cmd.system.basicDeviceState;
    final current = DeviceBlob.infoState;

    logger.info(
      'received basic device state: charging=${state.isCharging}, level=${state.batteryLevel}, worn=${state.isWorn}, sleep=${state.isUserAsleep}',
    );

    DeviceBlob.instance.update(
      DeviceInfoState(
        serialNumber: current.serialNumber,
        firmwareVersion: current.firmwareVersion,
        model: current.model,
        batteryLevel: state.hasBatteryLevel()
            ? state.batteryLevel
            : current.batteryLevel,
        isCharging: state.isCharging,
        isWorn: state.isWorn,
        isUserAsleep: state.isUserAsleep,
      ),
    );
  }

  void _settingsChanged() {
    _startSyncInterval();
  }

  void _startSyncInterval() {
    final interval = SettingsBlob.syncIntervalMinutes;
    // See if we already have this interval set up
    if (_syncInterval == interval) {
      return;
    }

    _syncInterval = interval;
    _syncTimer?.cancel();
    _syncTimer = null;
    if (interval <= 0) {
      logger.info('auto-sync disabled (syncIntervalMinutes <= 0)');
      return;
    }

    logger.info('scheduling auto-sync every $interval minutes');
    _syncTimer = Timer.periodic(Duration(minutes: interval), (timer) {
      sync();
    });
  }

  @override
  Future<void> sync() async {
    if (_syncing) {
      logger.info('sync already in progress, skipping concurrent call');
      return;
    }

    if (!DeviceConnection.connected.value) {
      logger.info('sync skipped: watch is not connected');
      return;
    }

    _syncing = true;
    logger.info('starting device sync pass');
    await _syncDevice();
    await _syncModules();
    logger.info('device sync pass completed');
    _syncing = false;
  }

  Future<void> _syncDevice() async {
    final futures = [
      DeviceConnection.send(
        type: CmdType.system,
        subtype: SystemSubtype.deviceInfo,
        expectResponse: true,
      ),
      DeviceConnection.send(
        type: CmdType.system,
        subtype: SystemSubtype.battery,
        expectResponse: true,
      ),
    ];

    final results = await Future.wait(futures);
    final infoCmd = results[0];
    final batteryCmd = results[1];

    final current = DeviceBlob.infoState;
    String serial = current.serialNumber;
    String firmware = current.firmwareVersion;
    String model = current.model;
    int batteryLevel = current.batteryLevel;
    bool charging = current.isCharging;
    bool worn = current.isWorn;
    bool userAsleep = current.isUserAsleep;

    if (infoCmd != null && infoCmd.system.hasDeviceInfo()) {
      final info = infoCmd.system.deviceInfo;
      logger.info('received device info in sync: serial=${info.serialNumber}');
      serial = info.serialNumber;
      firmware = info.firmware;
      model = info.model;
    }

    if (batteryCmd != null &&
        batteryCmd.system.hasPower() &&
        batteryCmd.system.power.hasBattery()) {
      final battery = batteryCmd.system.power.battery;
      logger.info('received battery state in sync: level=${battery.level}');
      batteryLevel = battery.level;
      charging = battery.state == 1 || battery.state == 3;
    }

    await DeviceBlob.instance.update(
      DeviceInfoState(
        serialNumber: serial,
        firmwareVersion: firmware,
        model: model,
        batteryLevel: batteryLevel,
        isCharging: charging,
        isWorn: worn,
        isUserAsleep: userAsleep,
      ),
    );
  }

  Future<void> _syncModules() async {
    for (final module in _modules) {
      await module.sync();
    }
  }
}
