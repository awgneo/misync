import 'dart:typed_data';

class FitnessDataId {
  static const int lengthDataId = 7;
  final int timeStamp;
  final int tzIn15Min;
  final int version;
  final int dataType;
  final int sportType;
  final int dailyType;
  final int fileType;

  FitnessDataId({
    required this.timeStamp,
    required this.tzIn15Min,
    required this.version,
    required this.dataType,
    required this.sportType,
    required this.dailyType,
    required this.fileType,
  });

  factory FitnessDataId.fromBytes(Uint8List bytes) {
    if (bytes.length < 7) {
      throw ArgumentError('illegal dataId length: ${bytes.length}');
    }
    final byteData = ByteData.sublistView(bytes);
    final timeStamp = byteData.getUint32(0, Endian.little);
    final tzIn15Min = byteData.getInt8(4);
    final version = byteData.getInt8(5);
    final b2 = byteData.getUint8(6);
    final dataType = (b2 & 128) >> 7;
    final val = (b2 & 127) >> 2;
    int sportType = 0;
    int dailyType = 0;
    if (dataType == 1) {
      sportType = val;
    } else {
      dailyType = val;
    }
    final fileType = b2 & 3;

    return FitnessDataId(
      timeStamp: timeStamp,
      tzIn15Min: tzIn15Min,
      version: version,
      dataType: dataType,
      sportType: sportType,
      dailyType: dailyType,
      fileType: fileType,
    );
  }

  Uint8List toBytes() {
    final bytes = Uint8List(7);
    final byteData = ByteData.view(bytes.buffer);
    byteData.setUint32(0, timeStamp, Endian.little);
    byteData.setInt8(4, tzIn15Min);
    byteData.setInt8(5, version);
    int b2 = (dataType << 7);
    final val = (dataType == 1) ? sportType : dailyType;
    b2 |= (val << 2);
    b2 |= (fileType & 3);
    byteData.setUint8(6, b2);
    return bytes;
  }

  String toHexString() {
    return toBytes()
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  @override
  String toString() {
    return 'FitnessDataId(timeStamp: $timeStamp, tzIn15Min: $tzIn15Min, dataType: $dataType, sportType: $sportType, dailyType: $dailyType, fileType: $fileType, version: $version)';
  }
}

class ParsedDailyRecord {
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

  ParsedDailyRecord(this.timestamp);

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

class ParsedSleepStateItem {
  final int startTime;
  final int endTime;
  final int sleepState;

  ParsedSleepStateItem(this.startTime, this.endTime, this.sleepState);

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'sleepState': sleepState,
    };
  }
}

class ParsedSleepReport {
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
  List<ParsedSleepStateItem> stages = [];

  ParsedSleepReport(this.timestamp);

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

class ParsedWorkoutReport {
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

  ParsedWorkoutReport(this.timestamp);

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

class HealthFileParser {
  static List<ParsedDailyRecord> parseDailyRecord(
    Uint8List bodyData,
    Uint8List dataValid,
    FitnessDataId dataId,
  ) {
    final records = <ParsedDailyRecord>[];
    final byteData = ByteData.sublistView(bodyData);
    int offset = 0;

    // Daily log is written minute-by-minute (1440 entries max per daily log file)
    final startTime = dataId.timeStamp;
    const intervalSeconds = 60;

    // Reconstruct valid flags for v2 daily records (excluding index 9 which is dynamic)
    final existMap = <int, bool>{};
    // There are 11 variables in v2DataInfoArray with non-null dataType
    // Each nibble (4 bits) in dataValid represents the flags for one variable.
    // Bit 0 (val & 1) indicates the existence of this variable in the log record.
    int varIdx = 0;
    for (int i = 0; i < 12; i++) {
      if (i == 9) continue; // Skip the dynamic variable
      final byteIdx = varIdx ~/ 2;
      final nibbleIdx = varIdx % 2;
      if (byteIdx < dataValid.length) {
        final b = dataValid[byteIdx];
        final val = (nibbleIdx == 0) ? ((b & 0xF0) >> 4) : (b & 0x0F);
        existMap[i] = (val & 1) > 0;
      } else {
        existMap[i] = false;
      }
      varIdx++;
    }

    int currentTimestamp = (startTime ~/ intervalSeconds) * intervalSeconds;

    while (offset + 1 <= bodyData.length) {
      final record = ParsedDailyRecord(currentTimestamp);
      bool success = true;

      // 0. IncludeSleep & abnormalHr & steps (2 bytes)
      if (existMap[0] == true) {
        if (offset + 2 > bodyData.length) {
          success = false;
          break;
        }
        final val = byteData.getUint16(offset, Endian.little);
        offset += 2;
        record.steps = val & 0x3FFF;
        record.isAbnormalHr = ((val >> 14) & 1) > 0;
      }

      // 1. activityType & calories (1 byte)
      if (existMap[1] == true) {
        if (offset + 1 > bodyData.length) {
          success = false;
          break;
        }
        final val = byteData.getUint8(offset);
        offset += 1;
        record.calories = val & 0x3F;
        record.activityType = (val >> 6) & 3;
      }

      // 2. activityHILevel & sportType (1 byte)
      if (existMap[2] == true) {
        if (offset + 1 > bodyData.length) {
          success = false;
          break;
        }
        final val = byteData.getUint8(offset);
        offset += 1;
        record.sportType = val & 0x1F;
        record.activityHILevel = (val >> 5) & 7;
      }

      // 3. distance (2 bytes)
      if (existMap[3] == true) {
        if (offset + 2 > bodyData.length) {
          success = false;
          break;
        }
        record.distance = byteData.getUint16(offset, Endian.little);
        offset += 2;
      }

      // 4. heart rate (1 byte)
      if (existMap[4] == true) {
        if (offset + 1 > bodyData.length) {
          success = false;
          break;
        }
        record.hr = byteData.getUint8(offset);
        offset += 1;
      }

      // 5. energy (1 byte)
      if (existMap[5] == true) {
        if (offset + 1 > bodyData.length) {
          success = false;
          break;
        }
        record.energy = byteData.getUint8(offset);
        offset += 1;
      }

      // 6. totalCal & energyState & energyStateValue (2 bytes)
      if (existMap[6] == true) {
        if (offset + 2 > bodyData.length) {
          success = false;
          break;
        }
        final val = byteData.getUint16(offset, Endian.little);
        offset += 2;
        record.totalCal = (val >> 10) & 0x3F;
        record.energyState = (val >> 8) & 3;
        final rawVal = val & 0xFF;
        record.energyStateValue =
            (((rawVal & 128) > 0) ? 1 : -1) * (rawVal & 127);
      }

      // 7. spo2 (1 byte)
      if (existMap[7] == true) {
        if (offset + 1 > bodyData.length) {
          success = false;
          break;
        }
        record.spo2 = byteData.getUint8(offset);
        offset += 1;
      }

      // 8. stress (1 byte)
      if (existMap[8] == true) {
        if (offset + 1 > bodyData.length) {
          success = false;
          break;
        }
        record.stress = byteData.getUint8(offset);
        offset += 1;
      }

      // 9. hrPreAbnormal (1 byte, dynamic)
      if (record.isAbnormalHr == true) {
        if (offset + 1 > bodyData.length) {
          success = false;
          break;
        }
        record.hrPreAbnormal = byteData.getUint8(offset);
        offset += 1;
      }

      // 10. lightValue (2 bytes)
      if (existMap[10] == true) {
        if (offset + 2 > bodyData.length) {
          success = false;
          break;
        }
        record.lightValue = byteData.getUint16(offset, Endian.little);
        offset += 2;
      }

      // 11. bodyMomentum (2 bytes)
      if (existMap[11] == true) {
        if (offset + 2 > bodyData.length) {
          success = false;
          break;
        }
        record.bodyMomentum = byteData.getUint16(offset, Endian.little);
        offset += 2;
      }

      records.add(record);
      currentTimestamp += intervalSeconds;
    }

    return records;
  }

  static const _sleepReportSchema = [
    OneDimenDataType(0, 1, 1),
    OneDimenDataType(1, 1, 1),
    OneDimenDataType(2, 1, 1),
    OneDimenDataType(3, 1, 1),
    OneDimenDataType(4, 1, 1),
    OneDimenDataType(5, 2, 1),
    OneDimenDataType(6, 4, 1),
    OneDimenDataType(7, 4, 1),
    OneDimenDataType(8, 1, 1),
    OneDimenDataType(9, 1, 1),
    OneDimenDataType(10, 1, 1),
    OneDimenDataType(11, 2, 1),
    OneDimenDataType(12, 2, 1),
    OneDimenDataType(13, 2, 1),
    OneDimenDataType(14, 2, 1),
    OneDimenDataType(15, 1, 2),
  ];

  static const _outdoorSportSchema = [
    OneDimenDataType(1, 4, 1),
    OneDimenDataType(2, 4, 1),
    OneDimenDataType(3, 4, 1),
    OneDimenDataType(5, 4, 1),
    OneDimenDataType(6, 2, 1),
    OneDimenDataType(8, 4, 1),
    OneDimenDataType(9, 4, 1),
    OneDimenDataType(12, 4, 1, isFloat: true),
    OneDimenDataType(13, 4, 1),
    OneDimenDataType(14, 2, 1),
    OneDimenDataType(16, 1, 1),
    OneDimenDataType(17, 1, 1),
    OneDimenDataType(18, 1, 1),
    OneDimenDataType(19, 4, 1, isFloat: true),
    OneDimenDataType(20, 4, 1, isFloat: true),
    OneDimenDataType(21, 4, 1, isFloat: true),
    OneDimenDataType(22, 4, 1, isFloat: true),
    OneDimenDataType(23, 4, 1, isFloat: true),
    OneDimenDataType(25, 4, 1, isFloat: true),
    OneDimenDataType(27, 1, 1),
    OneDimenDataType(28, 1, 1),
    OneDimenDataType(29, 2, 1),
    OneDimenDataType(30, 4, 1),
    OneDimenDataType(31, 4, 1),
    OneDimenDataType(32, 4, 1),
    OneDimenDataType(33, 4, 1),
    OneDimenDataType(34, 4, 1),
    OneDimenDataType(7, 2, 2),
    OneDimenDataType(4, 4, 3),
    OneDimenDataType(26, 4, 3, isFloat: true),
    OneDimenDataType(90, 1, 4),
    OneDimenDataType(-1, 8, 4, dependData: DependDataType(90, [252, 253, 255])),
    OneDimenDataType(91, 1, 4),
    OneDimenDataType(92, 4, 4),
    OneDimenDataType(93, 2, 4),
    OneDimenDataType(94, 4, 4),
    OneDimenDataType(95, 4, 4),
    OneDimenDataType(96, 2, 4),
  ];

  static const _indoorRunSchema = [
    OneDimenDataType(1, 4, 1),
    OneDimenDataType(2, 4, 1),
    OneDimenDataType(3, 4, 1),
    OneDimenDataType(5, 4, 1),
    OneDimenDataType(6, 2, 1),
    OneDimenDataType(10, 4, 10),
    OneDimenDataType(8, 4, 1),
    OneDimenDataType(9, 4, 1),
    OneDimenDataType(13, 4, 1),
    OneDimenDataType(148, 2, 10),
    OneDimenDataType(15, 2, 10),
    OneDimenDataType(14, 2, 1),
    OneDimenDataType(16, 1, 1),
    OneDimenDataType(17, 1, 1),
    OneDimenDataType(18, 1, 1),
    OneDimenDataType(25, 4, 1, isFloat: true),
    OneDimenDataType(107, 1, 7),
    OneDimenDataType(27, 1, 1),
    OneDimenDataType(109, 1, 7),
    OneDimenDataType(28, 1, 1),
    OneDimenDataType(29, 2, 1),
    OneDimenDataType(30, 4, 1),
    OneDimenDataType(31, 4, 1),
    OneDimenDataType(32, 4, 1),
    OneDimenDataType(33, 4, 1),
    OneDimenDataType(34, 4, 1),
    OneDimenDataType(158, 1, 12),
    OneDimenDataType(159, 1, 12),
    OneDimenDataType(160, 1, 12),
    OneDimenDataType(161, 1, 12),
    OneDimenDataType(162, 1, 12),
    OneDimenDataType(166, 4, 12),
    OneDimenDataType(167, 4, 12),
    OneDimenDataType(168, 4, 12),
    OneDimenDataType(169, 4, 12),
    OneDimenDataType(170, 4, 12),
    OneDimenDataType(7, 2, 2),
    OneDimenDataType(4, 4, 3),
    OneDimenDataType(26, 4, 3, isFloat: true),
    OneDimenDataType(108, 1, 7),
    OneDimenDataType(163, 4, 12, isFloat: true),
    OneDimenDataType(164, 1, 12),
    OneDimenDataType(65, 2, 6),
    OneDimenDataType(90, 1, 4),
    OneDimenDataType(-1, 8, 4, dependData: DependDataType(90, [252, 253, 255])),
    OneDimenDataType(91, 1, 4),
    OneDimenDataType(92, 4, 4),
    OneDimenDataType(93, 2, 4),
    OneDimenDataType(94, 4, 4),
    OneDimenDataType(95, 4, 4),
    OneDimenDataType(99, 4, 6, isFloat: true),
    OneDimenDataType(96, 2, 4),
    OneDimenDataType(100, 4, 5),
    OneDimenDataType(110, 2, 7),
    OneDimenDataType(111, 1, 7),
    OneDimenDataType(112, 4, 7, isFloat: true),
    OneDimenDataType(113, 1, 7),
    OneDimenDataType(114, 1, 8),
    OneDimenDataType(153, 2, 11),
    OneDimenDataType(154, 2, 11),
    OneDimenDataType(156, 2, 11),
    OneDimenDataType(155, 2, 11),
    OneDimenDataType(117, 1, 9),
    OneDimenDataType(125, 4, 9),
    OneDimenDataType(126, 4, 9),
    OneDimenDataType(127, 4, 9),
    OneDimenDataType(128, 1, 9),
    OneDimenDataType(137, 1, 10),
    OneDimenDataType(138, 1, 10),
    OneDimenDataType(139, 1, 10),
    OneDimenDataType(140, 1, 10),
    OneDimenDataType(141, 1, 10),
    OneDimenDataType(142, 2, 10),
    OneDimenDataType(143, 2, 10),
    OneDimenDataType(144, 2, 10),
    OneDimenDataType(145, 2, 10),
    OneDimenDataType(146, 1, 10),
    OneDimenDataType(147, 1, 10),
    OneDimenDataType(199, 2, 13),
    OneDimenDataType(200, 2, 13),
    OneDimenDataType(201, 2, 13),
    OneDimenDataType(202, 2, 13),
    OneDimenDataType(203, 2, 13),
    OneDimenDataType(204, 2, 13),
    OneDimenDataType(205, 2, 13),
    OneDimenDataType(152, 1, 11),
    OneDimenDataType(165, 2, 12),
    OneDimenDataType(173, 2, 12),
    OneDimenDataType(174, 2, 12),
    OneDimenDataType(206, 8, 13),
    OneDimenDataType(207, 4, 13),
  ];

  static const _freeTrainingSchema = [
    OneDimenDataType(1, 4, 1),
    OneDimenDataType(2, 4, 1),
    OneDimenDataType(3, 4, 1),
    OneDimenDataType(6, 2, 1),
    OneDimenDataType(16, 1, 1),
    OneDimenDataType(17, 1, 1),
    OneDimenDataType(18, 1, 1),
    OneDimenDataType(101, 1, 6),
    OneDimenDataType(102, 1, 6),
    OneDimenDataType(103, 1, 6),
    OneDimenDataType(104, 1, 6),
    OneDimenDataType(105, 1, 6),
    OneDimenDataType(106, 1, 6),
    OneDimenDataType(25, 4, 1, isFloat: true),
    OneDimenDataType(107, 1, 7),
    OneDimenDataType(28, 1, 1),
    OneDimenDataType(29, 2, 1),
    OneDimenDataType(30, 4, 1),
    OneDimenDataType(31, 4, 1),
    OneDimenDataType(32, 4, 1),
    OneDimenDataType(33, 4, 1),
    OneDimenDataType(34, 4, 1),
    OneDimenDataType(158, 1, 11),
    OneDimenDataType(159, 1, 11),
    OneDimenDataType(160, 1, 11),
    OneDimenDataType(161, 1, 11),
    OneDimenDataType(162, 1, 11),
    OneDimenDataType(7, 2, 2),
    OneDimenDataType(4, 4, 3),
    OneDimenDataType(26, 4, 3, isFloat: true),
    OneDimenDataType(108, 1, 7),
    OneDimenDataType(163, 4, 11, isFloat: true),
    OneDimenDataType(164, 1, 11),
    OneDimenDataType(65, 2, 4),
    OneDimenDataType(90, 1, 5),
    OneDimenDataType(-1, 8, 5, dependData: DependDataType(90, [252, 253, 255])),
    OneDimenDataType(91, 1, 5),
    OneDimenDataType(92, 4, 5),
    OneDimenDataType(93, 2, 5),
    OneDimenDataType(110, 2, 7),
    OneDimenDataType(111, 1, 7),
    OneDimenDataType(117, 1, 8),
    OneDimenDataType(118, 2, 8),
    OneDimenDataType(119, 2, 8),
    OneDimenDataType(120, 2, 8),
    OneDimenDataType(121, 2, 8),
    OneDimenDataType(122, 4, 8, isFloat: true),
    OneDimenDataType(123, 2, 8),
    OneDimenDataType(124, 1, 8),
    OneDimenDataType(149, 2, 9),
    OneDimenDataType(150, 2, 9),
    OneDimenDataType(151, 2, 9),
    OneDimenDataType(152, 1, 10),
    OneDimenDataType(165, 2, 11),
    OneDimenDataType(206, 8, 12),
    OneDimenDataType(207, 4, 12),
  ];

  static const _ropeSkippingSchema = [
    OneDimenDataType(1, 4, 1),
    OneDimenDataType(2, 4, 1),
    OneDimenDataType(3, 4, 1),
    OneDimenDataType(6, 2, 1),
    OneDimenDataType(16, 1, 1),
    OneDimenDataType(17, 1, 1),
    OneDimenDataType(18, 1, 1),
    OneDimenDataType(25, 4, 1, isFloat: true),
    OneDimenDataType(107, 1, 4),
    OneDimenDataType(28, 1, 1),
    OneDimenDataType(29, 2, 1),
    OneDimenDataType(30, 4, 1),
    OneDimenDataType(31, 4, 1),
    OneDimenDataType(32, 4, 1),
    OneDimenDataType(33, 4, 1),
    OneDimenDataType(34, 4, 1),
    OneDimenDataType(158, 1, 7),
    OneDimenDataType(159, 1, 7),
    OneDimenDataType(160, 1, 7),
    OneDimenDataType(161, 1, 7),
    OneDimenDataType(162, 1, 7),
    OneDimenDataType(7, 2, 1),
    OneDimenDataType(48, 4, 1),
    OneDimenDataType(49, 4, 1),
    OneDimenDataType(50, 4, 1),
    OneDimenDataType(63, 4, 1),
    OneDimenDataType(51, 4, 1),
    OneDimenDataType(52, 4, 1),
    OneDimenDataType(53, 4, 1),
    OneDimenDataType(54, 4, 1),
    OneDimenDataType(55, 4, 1),
    OneDimenDataType(64, 1, 1),
    OneDimenDataType(4, 4, 2),
    OneDimenDataType(26, 4, 2, isFloat: true),
    OneDimenDataType(108, 1, 4),
    OneDimenDataType(163, 4, 7, isFloat: true),
    OneDimenDataType(164, 1, 7),
    OneDimenDataType(90, 1, 3),
    OneDimenDataType(-1, 8, 3, dependData: DependDataType(90, [252, 253, 255])),
    OneDimenDataType(91, 1, 3),
    OneDimenDataType(92, 4, 3),
    OneDimenDataType(93, 2, 3),
    OneDimenDataType(98, 2, 3),
    OneDimenDataType(56, 2, 3),
    OneDimenDataType(110, 2, 4),
    OneDimenDataType(111, 1, 4),
    OneDimenDataType(117, 1, 5),
    OneDimenDataType(152, 1, 6),
    OneDimenDataType(165, 2, 7),
  ];

  static const _defaultSportSchema = [
    OneDimenDataType(1, 4, 1),
    OneDimenDataType(2, 4, 1),
    OneDimenDataType(3, 4, 1),
    OneDimenDataType(5, 4, 1),
    OneDimenDataType(6, 2, 1),
    OneDimenDataType(16, 1, 1),
    OneDimenDataType(17, 1, 1),
    OneDimenDataType(18, 1, 1),
  ];

  static List<OneDimenDataType> _getSchemaForSport(int sportType) {
    if (sportType == 14) return _ropeSkippingSchema;
    if (sportType == 8) return _freeTrainingSchema;
    if (sportType == 3) return _indoorRunSchema;
    if (sportType == 1 ||
        sportType == 2 ||
        sportType == 4 ||
        sportType == 5 ||
        sportType == 15) {
      return _outdoorSportSchema;
    }
    return _defaultSportSchema;
  }

  static ParsedSleepReport parseSleepReport(
    Uint8List bodyData,
    Uint8List dataValid,
    FitnessDataId dataId,
  ) {
    final report = ParsedSleepReport(dataId.timeStamp);
    final byteData = ByteData.sublistView(bodyData);

    // 1. Parse dataValid map
    final validMap = <int, bool>{};
    int bitIdx = 0;
    for (final dt in _sleepReportSchema) {
      if (dt.type >= 0) {
        if (dt.supportVersion > dataId.version) {
          validMap[dt.type] = false;
        } else {
          final byteIdx = bitIdx ~/ 8;
          final bitOffset = bitIdx % 8;
          if (byteIdx < dataValid.length) {
            final b = dataValid[byteIdx];
            validMap[dt.type] = (b & (1 << (7 - bitOffset))) > 0;
          } else {
            validMap[dt.type] = false;
          }
          bitIdx++;
        }
      }
    }

    // 2. Sequentially read from byteData
    final parsedValues = <int, dynamic>{};
    int offset = 0;
    for (final dt in _sleepReportSchema) {
      if (dt.supportVersion <= dataId.version) {
        if (offset + dt.byteCount > bodyData.length) {
          break; // no available bytes
        }
        final isValid = validMap[dt.type] ?? false;
        dynamic val;
        if (dt.byteCount == 1) {
          val = dt.isUnsigned
              ? byteData.getUint8(offset)
              : byteData.getInt8(offset);
        } else if (dt.byteCount == 2) {
          val = dt.isUnsigned
              ? byteData.getUint16(offset, Endian.little)
              : byteData.getInt16(offset, Endian.little);
        } else if (dt.byteCount == 4) {
          val = dt.isFloat
              ? byteData.getFloat32(offset, Endian.little)
              : (dt.isUnsigned
                    ? byteData.getUint32(offset, Endian.little)
                    : byteData.getInt32(offset, Endian.little));
        } else if (dt.byteCount == 8) {
          val = byteData.getInt64(offset, Endian.little);
        }
        offset += dt.byteCount;
        if (isValid) {
          parsedValues[dt.type] = val;
        }
      }
    }

    // 3. Map parsed values to report fields
    if (parsedValues[0] != null) report.totalScore = parsedValues[0];
    if (parsedValues[1] != null) report.qualityScore = parsedValues[1];
    if (parsedValues[2] != null) report.durationScore = parsedValues[2];
    if (parsedValues[3] != null) report.sleepSummary = parsedValues[3];
    if (parsedValues[4] != null) report.sleepAdvice = parsedValues[4];
    if (parsedValues[5] != null) report.sleepDuration = parsedValues[5];
    if (parsedValues[6] != null) report.bedTime = parsedValues[6];
    if (parsedValues[7] != null) report.wakeupTime = parsedValues[7];
    if (parsedValues[8] != null) report.recoveryScore = parsedValues[8];
    if (parsedValues[9] != null) report.nervousScore = parsedValues[9];
    if (parsedValues[10] != null) report.awakeCount = parsedValues[10];
    if (parsedValues[11] != null) report.deepDuration = parsedValues[11];
    if (parsedValues[12] != null) report.lightDuration = parsedValues[12];
    if (parsedValues[13] != null) report.remDuration = parsedValues[13];
    if (parsedValues[14] != null) report.awakeDuration = parsedValues[14];
    if (parsedValues[15] != null) report.friendlyTotalScore = parsedValues[15];

    // Remaining bytes are stages records
    int? prevTime;
    int? prevState;

    while (offset + 5 <= bodyData.length) {
      final t = byteData.getUint32(offset, Endian.little);
      final s = byteData.getUint8(offset + 4);
      offset += 5;

      if (prevTime != null && prevState != null) {
        report.stages.add(ParsedSleepStateItem(prevTime, t, prevState));
      }
      prevTime = t;
      prevState = s;
    }

    return report;
  }

  static ParsedWorkoutReport parseWorkoutReport(
    Uint8List bodyData,
    Uint8List dataValid,
    FitnessDataId dataId,
  ) {
    final report = ParsedWorkoutReport(dataId.timeStamp);
    final byteData = ByteData.sublistView(bodyData);
    final schema = _getSchemaForSport(dataId.sportType);

    // 1. Parse dataValid map
    final validMap = <int, bool>{};
    int bitIdx = 0;
    for (final dt in schema) {
      if (dt.type >= 0) {
        if (dt.supportVersion > dataId.version) {
          validMap[dt.type] = false;
        } else {
          final byteIdx = bitIdx ~/ 8;
          final bitOffset = bitIdx % 8;
          if (byteIdx < dataValid.length) {
            final b = dataValid[byteIdx];
            validMap[dt.type] = (b & (1 << (7 - bitOffset))) > 0;
          } else {
            validMap[dt.type] = false;
          }
          bitIdx++;
        }
      }
    }

    // 2. Helper to check if data item exists based on supportVersion and dependData
    bool isDataExist(OneDimenDataType dt, Map<int, dynamic> parsed) {
      if (dt.supportVersion > dataId.version) {
        return false;
      }
      final depend = dt.dependData;
      if (depend == null) {
        return true;
      }
      final depValue = parsed[depend.type];
      if (depValue != null) {
        if (depValue is int) {
          return depend.values.contains(depValue);
        } else if (depValue is double) {
          return depend.values.contains(depValue.toInt());
        }
      }
      return false;
    }

    // 3. Sequentially read from byteData
    final parsedValues = <int, dynamic>{};
    int offset = 0;
    for (final dt in schema) {
      if (isDataExist(dt, parsedValues)) {
        if (offset + dt.byteCount > bodyData.length) {
          break; // no available bytes
        }
        final isValid = validMap[dt.type] ?? false;
        dynamic val;
        if (dt.byteCount == 1) {
          val = dt.isUnsigned
              ? byteData.getUint8(offset)
              : byteData.getInt8(offset);
        } else if (dt.byteCount == 2) {
          val = dt.isUnsigned
              ? byteData.getUint16(offset, Endian.little)
              : byteData.getInt16(offset, Endian.little);
        } else if (dt.byteCount == 4) {
          val = dt.isFloat
              ? byteData.getFloat32(offset, Endian.little)
              : (dt.isUnsigned
                    ? byteData.getUint32(offset, Endian.little)
                    : byteData.getInt32(offset, Endian.little));
        } else if (dt.byteCount == 8) {
          val = byteData.getInt64(offset, Endian.little);
        }
        offset += dt.byteCount;
        if (isValid) {
          parsedValues[dt.type] = val;
        }
      }
    }

    // 4. Map parsed values to report object
    if (parsedValues[3] != null) report.duration = parsedValues[3];
    if (parsedValues[5] != null) report.distance = parsedValues[5];
    if (parsedValues[6] != null) report.calories = parsedValues[6];
    if (parsedValues[10] != null) report.avgSpeed = parsedValues[10];
    if (parsedValues[11] != null) report.maxSpeed = parsedValues[11];
    if (parsedValues[15] != null) report.avgCadence = parsedValues[15];
    if (parsedValues[16] != null) report.avgHr = parsedValues[16];
    if (parsedValues[17] != null) report.maxHr = parsedValues[17];
    if (parsedValues[18] != null) report.minHr = parsedValues[18];
    if (parsedValues[101] != null) report.avgSpo2 = parsedValues[101];
    if (parsedValues[102] != null) report.maxSpo2 = parsedValues[102];
    if (parsedValues[103] != null) report.minSpo2 = parsedValues[103];
    if (parsedValues[104] != null) report.avgStress = parsedValues[104];
    if (parsedValues[105] != null) report.maxStress = parsedValues[105];
    if (parsedValues[106] != null) report.minStress = parsedValues[106];
    if (dataId.sportType == 14) {
      if (parsedValues[48] != null) report.steps = parsedValues[48];
      if (parsedValues[49] != null) report.avgCadence = parsedValues[49];
      if (parsedValues[50] != null) report.maxCadence = parsedValues[50];
    } else {
      if (parsedValues[7] != null) report.steps = parsedValues[7];
    }

    report.sportType = dataId.sportType;

    return report;
  }

  static int _getDataValidityLen(FitnessDataId id) {
    final version = id.version;
    if (id.dataType == 1) {
      // Sport
      if (id.fileType == 1) {
        // Sport Report Summary
        switch (id.sportType) {
          case 14: // Rope Skipping
            if (version == 1 || version == 2) return 4;
            if (version >= 3 && version <= 6) return 5;
            if (version == 7) return 6;
            return 6; // default fallback
          case 8: // Free Training
            if (version == 1 || version == 2) return 2;
            if (version >= 3 && version <= 5) return 3;
            if (version == 6) return 4;
            if (version == 7) return 5;
            if (version >= 8 && version <= 10) return 6;
            if (version == 11 || version == 12) return 7;
            return 7;
          case 3: // Treadmill
            if (version >= 1 && version <= 3) return 3;
            if (version == 4 || version == 5) return 4;
            if (version == 6) return 5;
            if (version >= 7 && version <= 9) return 6;
            if (version == 10) return 8;
            if (version == 11) return 9;
            if (version == 12) return 11;
            if (version == 13) return 12;
            return 12;
          case 1: // Outdoor Run
          case 2: // Outdoor Walk
          case 4: // Indoor Walk
          case 5: // Cross Country Run
            if (version >= 1 && version <= 3) return 4;
            if (version == 4) return 5;
            return 5;
          default:
            return 5;
        }
      } else {
        // Sport Record Details
        switch (id.sportType) {
          case 14:
            if (version >= 1 && version <= 4) return 1;
            if (version == 5 || version == 6) return 3;
            return 3;
          case 8:
            if (version == 1 || version == 2) return 1;
            if (version == 3 || version == 4) return 2;
            return 2;
          default:
            return 2;
        }
      }
    } else {
      // Daily
      if (id.dailyType == 0) {
        if (id.fileType == 1) {
          if (version == 1 || version == 2) return 2;
          if (version == 3 || version == 4) return 3;
          if (version == 5) return 4;
          if (version == 6) return 5;
          return 5;
        } else {
          if (version == 1 || version == 2) return 4;
          if (version == 3) return 5;
          if (version == 4) return 6;
          return 6;
        }
      } else if (id.dailyType == 3) {
        return 2; // Night Sleep
      } else if (id.dailyType == 7 || id.dailyType == 8) {
        return 1; // All Day Sleep
      }
      return 2;
    }
  }

  static List<ParsedDailyRecord> parseDailyRecordFile(
    Uint8List fileData,
    FitnessDataId id,
  ) {
    if (fileData.length < 7) return [];
    final remaining = fileData.sublist(7);
    const dataValidLen = 6;
    if (remaining.length < 1 + dataValidLen) return [];
    final dataValid = remaining.sublist(1, 1 + dataValidLen);
    final bodyData = remaining.sublist(1 + dataValidLen);
    return parseDailyRecord(bodyData, dataValid, id);
  }

  static ParsedSleepReport parseSleepReportFile(
    Uint8List fileData,
    FitnessDataId id,
  ) {
    if (fileData.length < 7) return ParsedSleepReport(id.timeStamp);
    final remaining = fileData.sublist(7);
    const dataValidLen = 2;
    if (remaining.length < 1 + dataValidLen) {
      return ParsedSleepReport(id.timeStamp);
    }
    final dataValid = remaining.sublist(1, 1 + dataValidLen);
    final bodyData = remaining.sublist(1 + dataValidLen);
    return parseSleepReport(bodyData, dataValid, id);
  }

  static ParsedWorkoutReport parseWorkoutReportFile(
    Uint8List fileData,
    FitnessDataId id,
  ) {
    if (fileData.length < 7) return ParsedWorkoutReport(id.timeStamp);
    final remaining = fileData.sublist(7);
    final dataValidLen = _getDataValidityLen(id);
    if (remaining.length < 1 + dataValidLen) {
      return ParsedWorkoutReport(id.timeStamp);
    }
    final dataValid = remaining.sublist(1, 1 + dataValidLen);
    final bodyData = remaining.sublist(1 + dataValidLen);
    return parseWorkoutReport(bodyData, dataValid, id);
  }
}

class DependDataType {
  final int type;
  final List<int> values;
  const DependDataType(this.type, this.values);
}

class OneDimenDataType {
  final int type;
  final int byteCount;
  final int supportVersion;
  final bool isFloat;
  final DependDataType? dependData;
  final bool isUnsigned;

  const OneDimenDataType(
    this.type,
    this.byteCount,
    this.supportVersion, {
    this.isFloat = false,
    this.dependData,
    this.isUnsigned = false,
  });
}
