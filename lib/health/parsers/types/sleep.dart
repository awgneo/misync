class Sleep {
  final int timestamp;
  int? totalScore;
  int? qualityScore;
  int? durationScore;
  int? sleepSummary;
  int? sleepAdvice;
  int? sleepDuration;
  int? bedTime;
  int? wakeupTime;
  int? recoveryScore;
  int? nervousScore;
  int? deepDuration;
  int? lightDuration;
  int? remDuration;
  int? awakeDuration;
  int? awakeCount;
  int? friendlyTotalScore;
  List<SleepReportStage> stages = [];

  Sleep(this.timestamp);

  DateTime get startTime {
    if (stages.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    }
    final minStartTime = stages
        .map((s) => s.startTime)
        .reduce((a, b) => a < b ? a : b);
    return DateTime.fromMillisecondsSinceEpoch(minStartTime * 1000);
  }

  DateTime get endTime {
    if (stages.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    }
    final maxEndTime = stages
        .map((s) => s.endTime)
        .reduce((a, b) => a > b ? a : b);
    return DateTime.fromMillisecondsSinceEpoch(maxEndTime * 1000);
  }

  List<Map<String, dynamic>> get formattedStages {
    return stages.map((stage) {
      return {
        'start': stage.startTime * 1000,
        'end': stage.endTime * 1000,
        'stage': stage.sleepState,
      };
    }).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'totalScore': totalScore,
      'qualityScore': qualityScore,
      'durationScore': durationScore,
      'sleepSummary': sleepSummary,
      'sleepAdvice': sleepAdvice,
      'sleepDuration': sleepDuration,
      'bedTime': bedTime,
      'wakeupTime': wakeupTime,
      'recoveryScore': recoveryScore,
      'nervousScore': nervousScore,
      'deepDuration': deepDuration,
      'lightDuration': lightDuration,
      'remDuration': remDuration,
      'awakeDuration': awakeDuration,
      'awakeCount': awakeCount,
      'friendlyTotalScore': friendlyTotalScore,
      'stages': stages.map((s) => s.toJson()).toList(),
    };
  }
}

class SleepReportStage {
  final int startTime;
  final int endTime;
  final int sleepState;

  SleepReportStage(this.startTime, this.endTime, this.sleepState);

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'sleepState': sleepState,
    };
  }
}
