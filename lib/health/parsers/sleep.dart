import 'dart:typed_data';
import 'types/sleep.dart';
import 'id.dart';
import 'schemas.dart';

class SleepParser {
  static Sleep parse(Id id, Uint8List data) {
    if (id.dailyType == Id.dailyTypeSleepNight) {
      return _parseNightSleep(id, data);
    } else if (id.dailyType == Id.dailyTypeSleepDay) {
      return _parseDaytimeSleep(id, data);
    } else if (id.dailyType == Id.dailyTypeSleepAllDay) {
      return _parseAllDaySleep(id, data);
    }
    return Sleep(id.timeStamp);
  }

  static Sleep _parseNightSleep(Id id, Uint8List data) {
    if (data.length < 7) return Sleep(id.timeStamp);
    final remaining = data.sublist(7);
    const dataValidLen = 2;
    if (remaining.length < 1 + dataValidLen) {
      return Sleep(id.timeStamp);
    }
    final dataValid = remaining.sublist(1, 1 + dataValidLen);
    final bodyData = remaining.sublist(1 + dataValidLen);

    final report = Sleep(id.timeStamp);
    final byteData = ByteData.sublistView(bodyData);

    final validMap = <int, bool>{};
    int bitIdx = 0;
    for (final dt in Schemas.sleep) {
      if (dt.type >= 0) {
        if (dt.supportVersion > id.version) {
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

    final parsedValues = <int, dynamic>{};
    int offset = 0;
    for (final dt in Schemas.sleep) {
      if (dt.supportVersion <= id.version) {
        if (offset + dt.byteCount > bodyData.length) {
          break;
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

    int? prevTime;
    int? prevState;
    while (offset + 5 <= bodyData.length) {
      final t = byteData.getUint32(offset, Endian.little);
      final s = byteData.getUint8(offset + 4);
      offset += 5;

      if (prevTime != null && prevState != null) {
        report.stages.add(SleepStage(prevTime, t, prevState));
      }
      prevTime = t;
      prevState = s;
    }

    return report;
  }

  static Sleep _parseDaytimeSleep(Id id, Uint8List data) {
    if (data.length < 7) return Sleep(id.timeStamp);
    final remaining = data.sublist(7);
    const dataValidLen = 1;
    if (remaining.length < 1 + dataValidLen) {
      return Sleep(id.timeStamp);
    }
    final dataValid = remaining.sublist(1, 1 + dataValidLen);
    final bodyData = remaining.sublist(1 + dataValidLen);

    final report = Sleep(id.timeStamp);
    final byteData = ByteData.sublistView(bodyData);

    final isDurationValid = (dataValid[0] & 0x80) > 0;

    int offset = 0;
    if (isDurationValid && bodyData.length >= 2) {
      report.sleepDuration = byteData.getUint16(0, Endian.little);
      offset += 2;
    }

    int? prevTime;
    int? prevState;
    while (offset + 5 <= bodyData.length) {
      final t = byteData.getUint32(offset, Endian.little);
      final s = byteData.getUint8(offset + 4);
      offset += 5;

      if (prevTime != null && prevState != null) {
        report.stages.add(SleepStage(prevTime, t, prevState));
      }
      prevTime = t;
      prevState = s;
    }

    return report;
  }

  static Sleep _parseAllDaySleep(Id id, Uint8List data) {
    if (data.length < 7) return Sleep(id.timeStamp);
    final remaining = data.sublist(7);

    final int dataValidLen;
    if (id.version <= 4) {
      dataValidLen = 1;
    } else if (id.version == 5) {
      dataValidLen = 2;
    } else {
      dataValidLen = 3;
    }

    int reportVariablesSize = 0;
    if (id.version >= 1) reportVariablesSize += 1; // isSleepFinish
    if (id.version >= 1)
      reportVariablesSize += 8; // bedTime (4) + wakeupTime (4)
    if (id.version >= 4) reportVariablesSize += 1; // sleepQuality
    if (id.version >= 5) {
      reportVariablesSize +=
          17; // sleepEfficiency (1) + entrySleepDuration (4) + linBedDuration (4) + goBedTime (4) + leaveBedTime (4)
    }

    if (remaining.length < 1 + dataValidLen + reportVariablesSize) {
      return Sleep(id.timeStamp);
    }

    final byteData = ByteData.sublistView(remaining);

    // Base bedtime/wake up time from the file header
    int bedTime = byteData.getUint32(2 + dataValidLen, Endian.little);
    int wakeupTime = byteData.getUint32(6 + dataValidLen, Endian.little);

    final report = Sleep(id.timeStamp);
    report.bedTime = bedTime;
    report.wakeupTime = wakeupTime;

    // Search for 0xFFFCFAFB packets inside the payload body
    final bodyOffset = 1 + dataValidLen + reportVariablesSize;
    final bodyData = remaining.sublist(bodyOffset);
    final bodyByteData = ByteData.sublistView(bodyData);

    int packetOffset = 0;
    while (packetOffset + 14 <= bodyData.length) {
      final bool isNewProto;
      if (bodyData[packetOffset] == 0xFF &&
          bodyData[packetOffset + 1] == 0x11) {
        isNewProto = true;
      } else if (packetOffset + 17 <= bodyData.length &&
          bodyData[packetOffset] == 0xFF &&
          bodyData[packetOffset + 1] == 0xFC &&
          bodyData[packetOffset + 2] == 0xFA &&
          bodyData[packetOffset + 3] == 0xFB) {
        isNewProto = false;
      } else {
        packetOffset++;
        continue;
      }

      final int sigLen = isNewProto ? 2 : 5; // signature (1/4) + headerLen (1)
      packetOffset += sigLen;

      if (packetOffset + 12 > bodyData.length) break;

      int ts = bodyByteData.getUint64(packetOffset, Endian.little);
      if (ts > 1000000000000) {
        ts = ts ~/ 1000;
      }
      packetOffset += 8;

      packetOffset += 1; // skip parity
      final type = bodyData[packetOffset];
      packetOffset += 1;

      final dataLen =
          (bodyData[packetOffset] << 8) | bodyData[packetOffset + 1];
      packetOffset += 2;

      if (packetOffset + dataLen > bodyData.length) break;

      final dataByteData = ByteData.sublistView(
        bodyData,
        packetOffset,
        packetOffset + dataLen,
      );

      if (type == 16 && dataLen >= 11) {
        // Sleep report summary packet
        final sleepDuration = dataByteData.getUint16(1, Endian.big);
        final wakeDuration = dataByteData.getUint16(3, Endian.big);
        final lightDuration = dataByteData.getUint16(5, Endian.big);
        final remDuration = dataByteData.getUint16(7, Endian.big);
        final deepDuration = dataByteData.getUint16(9, Endian.big);

        report.sleepDuration = sleepDuration;
        report.awakeDuration = wakeDuration;
        report.lightDuration = lightDuration;
        report.remDuration = remDuration;
        report.deepDuration = deepDuration;
      } else if (type == 17) {
        // Sleep stages transition records packet
        int currentTime = ts;
        for (int i = 0; i < dataLen; i += 2) {
          if (i + 2 > dataLen) break;
          final val = dataByteData.getUint16(i, Endian.big);
          final stage = val >> 12;
          final offsetMinutes = val & 0xFFF;

          final stageStart = currentTime;
          currentTime += offsetMinutes * 60;
          final stageEnd = currentTime;

          report.stages.add(
            SleepStage(stageStart, stageEnd, _decodeStage(stage)),
          );
        }
      }

      packetOffset += dataLen;
    }

    return report;
  }

  static int _decodeStage(int rawStage) {
    switch (rawStage) {
      case 0:
        return 5; // AWAKE
      case 1:
        return 3; // LIGHT_SLEEP
      case 2:
        return 2; // DEEP_SLEEP
      case 3:
        return 4; // RAPID_EYE_MOVEMENT (REM)
      default:
        return 0; // NOT_SLEEP / UNKNOWN
    }
  }
}
