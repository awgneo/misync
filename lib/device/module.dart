import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import 'package:misync/screen.dart';
import 'blobs/settings.dart';
import 'proto/constants.dart';
import 'proto/xiaomi.pb.dart';
import 'blobs/device.dart';
import '../platform/module.dart';
import 'connection.dart';
import 'screen.dart';
import 'pairing/extractor.dart';

class DeviceModule extends TabModule {
  @override
  String get name => 'device';

  @override
  IconData get icon => Icons.link;

  @override
  late final Screen screen = DeviceScreen(this);

  late final DeviceConnection connection;

  static final DeviceModule _module = DeviceModule._();
  static DeviceModule get module => _module;
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
    connection = DeviceConnection(logger);
    _startDeviceCompanionship();
    PlatformModule.module.register(_receivePhoneMethod);
    connection.connected.addListener(_watchConnectionChanged);
    connection.listen(_receiveWatchCommand);
    SettingsBlob.instance.addListener(_settingsChanged);
    connection.connect();
    _startSyncInterval();
  }

  void _startDeviceCompanionship() async {
    _deviceAssociated =
        await PlatformModule.module.invokeMethod(
          'device.getDeviceAssociated',
        ) ??
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
      case 'stopFindPhone':
        logger.info('stopFindPhone request from native side');
        await stopFindPhone();
        break;
    }
  }

  void _observeDevicePresence() async {
    if (_deviceAssociated) {
      await PlatformModule.module.invokeMethod('device.observeDevicePresence');
    }
  }

  void _watchConnectionChanged() {
    if (connection.connected.value) {
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
      } else if (cmd.subtype == SystemSubtype.findPhone.value) {
        _handleWatchFindPhone(cmd);
      } else if (cmd.subtype == SystemSubtype.findWatch.value) {
        _handleWatchFindWatch(cmd);
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
      current.copyWith(
        serialNumber: info.serialNumber,
        firmwareVersion: info.firmware,
        model: info.model,
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
      current.copyWith(
        batteryLevel: battery.level,
        isCharging: battery.state == 1 || battery.state == 3,
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
      current.copyWith(
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

    if (!connection.connected.value) {
      logger.info('sync skipped: watch is not connected');
      return;
    }

    _syncing = true;
    logger.info('starting device sync pass');
    await _syncDevice();
    await _syncModules();
    await _syncGps();
    logger.info('device sync pass completed');
    _syncing = false;
  }

  Future<void> _syncGps() async {
    final now = DateTime.now();
    final lastSyncMs = DeviceBlob.infoState.lastAgpsSyncMs;
    if (lastSyncMs > 0) {
      final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
      if (now.difference(lastSyncTime).inHours < 24) {
        return; // Silent check
      }
    }

    logger.info('syncing GPS helper data...');
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('http://epodownload.mediatek.com/EPO.DAT'),
      );
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytesBuilder = BytesBuilder();
        await for (final chunk in response) {
          bytesBuilder.add(chunk);
        }
        final bytes = bytesBuilder.takeBytes();

        final success = await connection.uploadData(type: 1, bytes: bytes);
        if (success) {
          logger.info('GPS sync completed');
          await DeviceBlob.instance.update(
            DeviceBlob.infoState.copyWith(lastAgpsSyncMs: now.millisecondsSinceEpoch),
          );
        } else {
          logger.error('failed to upload GPS data');
        }
      } else {
        logger.error('failed to fetch GPS data: HTTP ${response.statusCode}');
      }
    } catch (e) {
      logger.error('GPS sync error: $e');
    } finally {
      client.close();
    }
  }

  Future<void> _syncDevice() async {
    final futures = [
      connection.send(
        type: CmdType.system,
        subtype: SystemSubtype.deviceInfo,
        expectResponse: true,
      ),
      connection.send(
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
      DeviceBlob.infoState.copyWith(
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

  void _handleWatchFindPhone(Command cmd) {
    final int findDevice = cmd.system.findDevice;
    logger.info('received find phone request: findDevice=$findDevice');
    if (findDevice == 0) {
      PlatformModule.module.invokeMethod('device.startFindPhone');
    } else {
      PlatformModule.module.invokeMethod('device.stopFindPhone');
    }
  }

  void _handleWatchFindWatch(Command cmd) {
    final int findDevice = cmd.system.findDevice;
    logger.info(
      'received find watch update from wrist: findDevice=$findDevice',
    );
    if (findDevice == 1) {
      PlatformModule.module.findingWatch.value = false;
      PlatformModule.module.invokeMethod('device.updateFindWatchState', false);
    }
  }

  Future<void> stopFindPhone() async {
    logger.info('stopping find phone alert');
    if (connection.connected.value) {
      await connection.send(
        type: CmdType.system,
        subtype: SystemSubtype.findPhone,
        builder: (cmd) => cmd.system = (System()..findDevice = 1),
      );
    }
    await PlatformModule.module.invokeMethod('device.stopFindPhone');
  }
}
