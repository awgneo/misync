import '../../storage/blob.dart';

class Settings {
  final String authKeyHex;
  final String watchMac;
  final String deviceId;
  final String deviceModel;
  final int syncIntervalMinutes; // Sync frequency: e.g. 0 (disabled), 5, 10, 15, 30, 60

  const Settings({
    required this.authKeyHex,
    required this.watchMac,
    required this.deviceId,
    required this.deviceModel,
    required this.syncIntervalMinutes,
  });
}

class SettingsBlob extends Blob<Settings> {
  static final SettingsBlob _instance = SettingsBlob._();
  static SettingsBlob get instance => _instance;

  SettingsBlob._()
    : super(
        module: 'device',
        name: 'settings',
        defaultValue: const Settings(
          authKeyHex: '0e11f584d16c128ce9437a8a3838d665',
          watchMac: '2C:0D:CF:6E:E6:D4',
          deviceId: '2198524676',
          deviceModel: 'miwear.watch.p67cn',
          syncIntervalMinutes: 15,
        ),
      );

  static String get authKeyHex => _instance.value.authKeyHex;
  static String get watchMac => _instance.value.watchMac;
  static String get deviceId => _instance.value.deviceId;
  static String get deviceModel => _instance.value.deviceModel;
  static int get syncIntervalMinutes => _instance.value.syncIntervalMinutes;

  @override
  Settings parse(dynamic json) {
    final map = Map<String, dynamic>.from(json ?? {});
    return Settings(
      authKeyHex: map['authKeyHex'] ?? '0e11f584d16c128ce9437a8a3838d665',
      watchMac: map['watchMac'] ?? '2C:0D:CF:6E:E6:D4',
      deviceId: map['deviceId'] ?? '2198524676',
      deviceModel: map['deviceModel'] ?? 'miwear.watch.p67cn',
      syncIntervalMinutes: map['syncIntervalMinutes'] ?? 15,
    );
  }

  @override
  dynamic serialize(Settings value) => {
    'authKeyHex': value.authKeyHex,
    'watchMac': value.watchMac,
    'deviceId': value.deviceId,
    'deviceModel': value.deviceModel,
    'syncIntervalMinutes': value.syncIntervalMinutes,
  };
}
