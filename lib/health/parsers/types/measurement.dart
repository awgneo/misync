abstract class Measurement {
  final int timestamp;
  final int type;

  Measurement({required this.timestamp, required this.type});
}

class HeartRateMeasurement extends Measurement {
  final int bpm;

  HeartRateMeasurement({
    required super.timestamp,
    required this.bpm,
  }) : super(type: 1);

  @override
  String toString() => 'HeartRateMeasurement(timestamp: $timestamp, bpm: $bpm)';
}

class OxygenSaturationMeasurement extends Measurement {
  final int percentage;

  OxygenSaturationMeasurement({
    required super.timestamp,
    required this.percentage,
  }) : super(type: 2);

  @override
  String toString() => 'OxygenSaturationMeasurement(timestamp: $timestamp, percentage: $percentage)';
}

class StressMeasurement extends Measurement {
  final int stress;

  StressMeasurement({
    required super.timestamp,
    required this.stress,
  }) : super(type: 3);

  @override
  String toString() => 'StressMeasurement(timestamp: $timestamp, stress: $stress)';
}

class TemperatureMeasurement extends Measurement {
  final double? skinTemp;
  final double? bodyTemp;

  TemperatureMeasurement({
    required super.timestamp,
    this.skinTemp,
    this.bodyTemp,
  }) : super(type: 4);

  @override
  String toString() => 'TemperatureMeasurement(timestamp: $timestamp, skinTemp: $skinTemp, bodyTemp: $bodyTemp)';
}

class BloodPressureMeasurement extends Measurement {
  final int systolic;
  final int diastolic;
  final int? pulse;
  final int? measurementStatus;

  BloodPressureMeasurement({
    required super.timestamp,
    required this.systolic,
    required this.diastolic,
    this.pulse,
    this.measurementStatus,
  }) : super(type: 5);

  @override
  String toString() {
    return 'BloodPressureMeasurement(timestamp: $timestamp, systolic: $systolic, diastolic: $diastolic, pulse: $pulse, status: $measurementStatus)';
  }
}
