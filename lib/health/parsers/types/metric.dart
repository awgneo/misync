class Metric {
  final int timestamp;
  int? steps;
  int? calories;
  int? totalCal;
  int? distance;
  int? hr;
  int? energy;
  int? energyState;
  int? energyStateValue;
  int? spo2;
  int? stress;
  int? activityType;
  int? activityHILevel;
  int? sportType;
  bool? isAbnormalHr;
  int? hrPreAbnormal;
  int? lightValue;
  int? bodyMomentum;

  Metric(this.timestamp);

  DateTime get endTime => DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  DateTime get startTime => endTime.subtract(const Duration(minutes: 1));

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'steps': steps,
      'calories': calories,
      'totalCal': totalCal,
      'distance': distance,
      'hr': hr,
      'energy': energy,
      'energyState': energyState,
      'energyStateValue': energyStateValue,
      'spo2': spo2,
      'stress': stress,
      'activityType': activityType,
      'activityHILevel': activityHILevel,
      'sportType': sportType,
      'isAbnormalHr': isAbnormalHr,
      'hrPreAbnormal': hrPreAbnormal,
      'lightValue': lightValue,
      'bodyMomentum': bodyMomentum,
    };
  }
}
