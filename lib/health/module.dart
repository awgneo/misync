import 'package:flutter/material.dart';
import '../module.dart';
import '../device/proto/xiaomi.pb.dart';
import '../device/proto/constants.dart';
import '../device/connection.dart';
import '../debug/logger.dart';
import 'screen.dart';

class HealthModule extends TabModule {
  @override
  String get name => 'health';

  @override
  IconData get icon => Icons.favorite;

  @override
  Widget get screen => const HealthScreen();

  static final HealthModule _instance = HealthModule._();
  static HealthModule get instance => _instance;
  HealthModule._();

  @override
  Future<void> start() async {
    // DeviceModule.instance.register(this); // Commented out for manual testing
  }

  @override
  Future<void> sync() async {
    Logger.info(
      'health',
      'syncing health configuration and requesting activities from watch',
    );

    if (!DeviceConnection.connected.value) return;

    // 1. Sync User Profile Info (Type 8, Subtype 0)
    await DeviceConnection.send(
      type: CmdType.health,
      subtype: HealthSubtype.userInfo,
      builder: (cmd) => cmd.health = (Health()
        ..userInfo = (UserInfo()
          ..height = 175
          ..weight = 70
          ..gender =
              1 // Male
          ..birthday = 19950101
          ..maxHeartRate = 180
          ..goalSteps = 10000
          ..goalCalories = 500
          ..goalStanding = 12
          ..goalMoving = 30)),
    );

    // 2. Fetch Activity (Type 8, Subtype 1)
    await DeviceConnection.send(
      type: CmdType.health,
      subtype: HealthSubtype.fetchData,
    );

    Logger.info('health', 'health sync tasks initiated');
  }
}
