import 'dart:typed_data';
import 'types/sleep.dart';
import 'id.dart';
import 'schemas.dart';

class SleepParser {
  static Sleep parse(Id id, Uint8List data) {
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

    // 1. Parse dataValid map
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

    // 2. Sequentially read from byteData
    final parsedValues = <int, dynamic>{};
    int offset = 0;
    for (final dt in Schemas.sleep) {
      if (dt.supportVersion <= id.version) {
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
        report.stages.add(SleepReportStage(prevTime, t, prevState));
      }
      prevTime = t;
      prevState = s;
    }

    return report;
  }
}
