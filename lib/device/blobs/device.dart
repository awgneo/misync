import '../../storage/blob.dart';

class DeviceInfoState {
  final String serialNumber;
  final String firmwareVersion;
  final String model;
  
  final int batteryLevel;
  final bool isCharging;
  final bool isWorn;
  final bool isUserAsleep;

  const DeviceInfoState({
    required this.serialNumber,
    required this.firmwareVersion,
    required this.model,
    required this.batteryLevel,
    required this.isCharging,
    required this.isWorn,
    required this.isUserAsleep,
  });
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
  };
}
