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
  List<SleepStage> stages = [];

  Sleep(this.timestamp);

  DateTime get startTime {
    if (bedTime != null && bedTime! > 0) {
      return DateTime.fromMillisecondsSinceEpoch(bedTime! * 1000);
    }
    if (stages.isNotEmpty) {
      final minStartTime = stages
          .map((s) => s.startTime)
          .reduce((a, b) => a < b ? a : b);
      return DateTime.fromMillisecondsSinceEpoch(minStartTime * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  DateTime get endTime {
    if (wakeupTime != null && wakeupTime! > 0) {
      return DateTime.fromMillisecondsSinceEpoch(wakeupTime! * 1000);
    }
    if (stages.isNotEmpty) {
      final maxEndTime = stages
          .map((s) => s.endTime)
          .reduce((a, b) => a > b ? a : b);
      return DateTime.fromMillisecondsSinceEpoch(maxEndTime * 1000);
    }
    final start = startTime;
    if (sleepDuration != null && sleepDuration! > 0) {
      return start.add(Duration(minutes: sleepDuration!));
    }
    return start;
  }

  List<Map<String, dynamic>> get formattedStages {
    final startSec = startTime.millisecondsSinceEpoch ~/ 1000;
    final endSec = endTime.millisecondsSinceEpoch ~/ 1000;
    if (endSec <= startSec) return [];

    final list = List<SleepStage>.from(stages);
    list.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Pad beginning if stages start after bedTime
    if (list.isNotEmpty && list.first.startTime > startSec) {
      list.insert(0, SleepStage(startSec, list.first.startTime, 5)); // 5 = AWAKE
    }

    // Pad end if stages end before wakeupTime
    if (list.isNotEmpty && list.last.endTime < endSec) {
      list.add(SleepStage(list.last.endTime, endSec, 5)); // 5 = AWAKE
    }

    // Fill intermediate gaps with AWAKE (state 5)
    final continuous = <SleepStage>[];
    for (int i = 0; i < list.length; i++) {
      if (continuous.isNotEmpty && continuous.last.endTime < list[i].startTime) {
        continuous.add(SleepStage(continuous.last.endTime, list[i].startTime, 5));
      }
      continuous.add(list[i]);
    }

    return continuous.map((stage) {
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

class SleepStage {
  final int startTime;
  final int endTime;
  final int sleepState;

  SleepStage(this.startTime, this.endTime, this.sleepState);

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'sleepState': sleepState,
    };
  }
}
