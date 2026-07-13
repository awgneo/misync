class Exercise {
  final int timestamp;
  int? duration; // in seconds
  int? calories; // in kcal
  int? distance; // in meters
  int? avgSpeed;
  int? maxSpeed;
  int? avgHr;
  int? maxHr;
  int? minHr;
  int? avgSpo2;
  int? maxSpo2;
  int? minSpo2;
  int? avgStress;
  int? maxStress;
  int? minStress;
  int? avgCadence;
  int? maxCadence;
  int? sportType;
  int? steps; // steps count / stroke count / jump count

  Exercise(this.timestamp);

  DateTime get startTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  DateTime get endTime => startTime.add(Duration(seconds: duration ?? 0));

  String get title => getWorkoutTitle(sportType ?? 0);

  static String getWorkoutTitle(int sportType) {
    switch (sportType) {
      case 1:
        return 'Outdoor run';
      case 2:
        return 'Outdoor walk';
      case 3:
        return 'Treadmill';
      case 4:
        return 'Indoor walk';
      case 5:
        return 'Cross country run';
      case 6:
        return 'Outdoor biking';
      case 7:
        return 'Indoor biking';
      case 8:
        return 'Free training';
      case 9:
        return 'Pool swimming';
      case 10:
        return 'Open water swimming';
      case 11:
        return 'Elliptical';
      case 12:
        return 'Yoga';
      case 13:
        return 'Rowing machine';
      case 14:
        return 'Jump rope';
      case 15:
        return 'Hiking';
      case 16:
        return 'HIIT';
      case 19:
        return 'Basketball';
      case 20:
        return 'Golf';
      case 21:
        return 'Skiing';
      case 22:
        return 'Outdoor step';
      case 24:
        return 'Rock climbing';
      case 25:
        return 'Scuba diving';
      default:
        return 'Workout';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'duration': duration,
      'calories': calories,
      'distance': distance,
      'avgSpeed': avgSpeed,
      'maxSpeed': maxSpeed,
      'avgHr': avgHr,
      'maxHr': maxHr,
      'minHr': minHr,
      'avgSpo2': avgSpo2,
      'maxSpo2': maxSpo2,
      'minSpo2': minSpo2,
      'avgStress': avgStress,
      'maxStress': maxStress,
      'minStress': minStress,
      'avgCadence': avgCadence,
      'maxCadence': maxCadence,
      'sportType': sportType,
      'steps': steps,
    };
  }
}
