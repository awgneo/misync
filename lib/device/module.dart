import 'dart:async';
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
  bool isCompanionAssociated = false;
  bool _wasConnected = false;
  Timer? _syncTimer;
  int? _lastScheduledInterval;
  bool _lastConnectionState = false;
  bool _isSyncing = false;

  void register(Module module) {
    _modules.add(module);
  }

  @override
  Future<void> sync() async {
    if (_isSyncing) {
      Logger.info('sync', 'sync already in progress, skipping concurrent call');
      return;
    }
    if (!DeviceConnection.connected.value) {
      Logger.info('sync', 'sync skipped: watch is not connected');
      return;
    }

    _isSyncing = true;
    Logger.info('sync', 'starting global device sync pass');

    try {
      await _syncDevice();
      await _syncModules();
      Logger.info('sync', 'global device sync pass completed');
    } catch (e) {
      Logger.error('sync', 'error during global device sync: $e');
    } finally {
      _isSyncing = false;
    }
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
    bool isCharging = current.isCharging;
    bool isWorn = current.isWorn;
    bool isUserAsleep = current.isUserAsleep;

    if (infoCmd != null && infoCmd.system.hasDeviceInfo()) {
      final info = infoCmd.system.deviceInfo;
      Logger.info(
        'device',
        'received device info in sync: serial=${info.serialNumber}',
      );
      serial = info.serialNumber;
      firmware = info.firmware;
      model = info.model;
    }

    if (batteryCmd != null &&
        batteryCmd.system.hasPower() &&
        batteryCmd.system.power.hasBattery()) {
      final battery = batteryCmd.system.power.battery;
      Logger.info(
        'device',
        'received battery state in sync: level=${battery.level}',
      );
      batteryLevel = battery.level;
      isCharging = battery.state == 1 || battery.state == 3;
    }

    await DeviceBlob.instance.update(
      DeviceInfoState(
        serialNumber: serial,
        firmwareVersion: firmware,
        model: model,
        batteryLevel: batteryLevel,
        isCharging: isCharging,
        isWorn: isWorn,
        isUserAsleep: isUserAsleep,
      ),
    );
  }

  Future<void> _syncModules() async {
    for (final module in _modules) {
      try {
        await module.sync();
      } catch (e) {
        Logger.error('sync', 'module ${module.runtimeType} sync failed: $e');
      }
    }
  }

  @override
  Future<void> start() async {
    DeviceConnection.logger = logger;
    _checkPermissions();
    PlatformModule.instance.register(_handleMethodCall);
    DeviceConnection.instance.addListener(_onConnectionChanged);
    DeviceConnection.listen(_handleCommand);
    SettingsBlob.instance.addListener(_updateSyncTimer);
    DeviceConnection.connect();
  }

  void _handleCommand(Command cmd) {
    if (cmd.type == CmdType.system.value) {
      _handleSystemCommand(cmd);
    }
  }

  void _handleSystemCommand(Command cmd) {
    if (cmd.subtype == SystemSubtype.deviceInfo.value) {
      _handleDeviceInfo(cmd);
    } else if (cmd.subtype == SystemSubtype.battery.value) {
      _handleBattery(cmd);
    } else if (cmd.subtype == SystemSubtype.deviceState.value) {
      _handleDeviceState(cmd);
    }
  }

  void _handleDeviceInfo(Command cmd) {
    if (!cmd.system.hasDeviceInfo()) return;
    final info = cmd.system.deviceInfo;
    final current = DeviceBlob.infoState;
    Logger.info(
      'device',
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

  void _handleBattery(Command cmd) {
    if (!cmd.system.hasPower() || !cmd.system.power.hasBattery()) return;
    final battery = cmd.system.power.battery;
    final current = DeviceBlob.infoState;
    Logger.info(
      'device',
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

  void _handleDeviceState(Command cmd) {
    if (!cmd.system.hasBasicDeviceState()) return;
    final state = cmd.system.basicDeviceState;
    final current = DeviceBlob.infoState;
    Logger.info(
      'device',
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

  void _onConnectionChanged() {
    final connected = DeviceConnection.connected.value;
    if (connected && !_wasConnected) {
      _wasConnected = true;
      _registerCompanionPresence();
      sync();
    } else if (!connected) {
      _wasConnected = false;
    }
    _updateSyncTimer();
  }

  void _updateSyncTimer() {
    final isConnected = DeviceConnection.connected.value;
    final interval = SettingsBlob.syncIntervalMinutes;

    if (_lastScheduledInterval == interval &&
        _lastConnectionState == isConnected) {
      return;
    }

    _lastScheduledInterval = interval;
    _lastConnectionState = isConnected;

    _syncTimer?.cancel();
    _syncTimer = null;

    if (!isConnected) {
      Logger.info('sync', 'auto-sync timer stopped: watch disconnected');
      return;
    }

    if (interval <= 0) {
      Logger.info('sync', 'auto-sync disabled (syncIntervalMinutes <= 0)');
      return;
    }

    Logger.info('sync', 'scheduling auto-sync every $interval minutes');
    _syncTimer = Timer.periodic(Duration(minutes: interval), (timer) {
      sync();
    });
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onCompanionAssociationComplete':
        isCompanionAssociated = true;
        Logger.info('device', 'companion device associated successfully');
        _registerCompanionPresence();
        break;
      case 'onCompanionUnassociated':
        isCompanionAssociated = false;
        Logger.info('device', 'companion device unassociated');
        break;
    }
  }

  void _checkPermissions() async {
    try {
      isCompanionAssociated =
          await PlatformModule.instance.invokeMethod(
            'checkCompanionAssociation',
          ) ??
          false;
    } catch (_) {}
  }

  void _registerCompanionPresence() async {
    if (isCompanionAssociated) {
      try {
        await PlatformModule.instance.invokeMethod('startPresenceObservation');
      } catch (_) {}
    }
  }}
