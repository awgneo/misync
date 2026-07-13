import '../../storage/blob.dart';

class DeviceInfoState {
  final String serialNumber;
  final String firmwareVersion;
  final String model;
  
  final int batteryLevel;
  final bool isCharging;
  final bool isWorn;
  final bool isUserAsleep;
  final int lastAgpsSyncMs;

  const DeviceInfoState({
    required this.serialNumber,
    required this.firmwareVersion,
    required this.model,
    required this.batteryLevel,
    required this.isCharging,
    required this.isWorn,
    required this.isUserAsleep,
    required this.lastAgpsSyncMs,
  });

  DeviceInfoState copyWith({
    String? serialNumber,
    String? firmwareVersion,
    String? model,
    int? batteryLevel,
    bool? isCharging,
    bool? isWorn,
    bool? isUserAsleep,
    int? lastAgpsSyncMs,
  }) {
    return DeviceInfoState(
      serialNumber: serialNumber ?? this.serialNumber,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      model: model ?? this.model,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      isWorn: isWorn ?? this.isWorn,
      isUserAsleep: isUserAsleep ?? this.isUserAsleep,
      lastAgpsSyncMs: lastAgpsSyncMs ?? this.lastAgpsSyncMs,
    );
  }
}

class DeviceBlob extends Blob<DeviceInfoState> {
  static final DeviceBlob _instance = DeviceBlob._();
  static DeviceBlob get instance => _instance;

  DeviceBlob._()
    : super(
        module: 'device',
        name: 'info_state',
        defaultValue: const DeviceInfoState(
          serialNumber: '',
          firmwareVersion: '',
          model: '',
          batteryLevel: 0,
          isCharging: false,
          isWorn: false,
          isUserAsleep: false,
          lastAgpsSyncMs: 0,
        ),
      );

  static DeviceInfoState get infoState => _instance.value;

  @override
  DeviceInfoState parse(dynamic json) {
    final map = Map<String, dynamic>.from(json ?? {});
    return DeviceInfoState(
      serialNumber: map['serialNumber'] ?? '',
      firmwareVersion: map['firmwareVersion'] ?? '',
      model: map['model'] ?? '',
      batteryLevel: map['batteryLevel'] ?? 0,
      isCharging: map['isCharging'] ?? false,
      isWorn: map['isWorn'] ?? false,
      isUserAsleep: map['isUserAsleep'] ?? false,
      lastAgpsSyncMs: map['lastAgpsSyncMs'] ?? 0,
    );
  }

  @override
  dynamic serialize(DeviceInfoState value) => {
    'serialNumber': value.serialNumber,
    'firmwareVersion': value.firmwareVersion,
    'model': value.model,
    'batteryLevel': value.batteryLevel,
    'isCharging': value.isCharging,
    'isWorn': value.isWorn,
    'isUserAsleep': value.isUserAsleep,
    'lastAgpsSyncMs': value.lastAgpsSyncMs,
  };
}
