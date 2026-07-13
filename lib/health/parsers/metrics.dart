import 'dart:typed_data';
import 'types/metric.dart';
import 'id.dart';

class MetricsParser {
  static List<Metric> parse(Id id, Uint8List data) {
    if (data.length < 7) return [];
    final remaining = data.sublist(7);
    const dataValidLen = 6;
    if (remaining.length < 1 + dataValidLen) return [];
    final dataValid = remaining.sublist(1, 1 + dataValidLen);
    final bodyData = remaining.sublist(1 + dataValidLen);

    final records = <Metric>[];
    final byteData = ByteData.sublistView(bodyData);
    int offset = 0;

    // Daily log is written minute-by-minute (1440 entries max per daily log file)
    final startTime = id.timeStamp;
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
      final record = Metric(currentTimestamp);

      // 0. IncludeSleep & abnormalHr & steps (2 bytes)
      if (existMap[0] == true) {
        if (offset + 2 > bodyData.length) {
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
          break;
        }
        record.distance = byteData.getUint16(offset, Endian.little);
        offset += 2;
      }

      // 4. heart rate (1 byte)
      if (existMap[4] == true) {
        if (offset + 1 > bodyData.length) {
          break;
        }
        record.hr = byteData.getUint8(offset);
        offset += 1;
      }

      // 5. energy (1 byte)
      if (existMap[5] == true) {
        if (offset + 1 > bodyData.length) {
          break;
        }
        record.energy = byteData.getUint8(offset);
        offset += 1;
      }

      // 6. totalCal & energyState & energyStateValue (2 bytes)
      if (existMap[6] == true) {
        if (offset + 2 > bodyData.length) {
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
          break;
        }
        record.spo2 = byteData.getUint8(offset);
        offset += 1;
      }

      // 8. stress (1 byte)
      if (existMap[8] == true) {
        if (offset + 1 > bodyData.length) {
          break;
        }
        record.stress = byteData.getUint8(offset);
        offset += 1;
      }

      // 9. hrPreAbnormal (1 byte, dynamic)
      if (record.isAbnormalHr == true) {
        if (offset + 1 > bodyData.length) {
          break;
        }
        record.hrPreAbnormal = byteData.getUint8(offset);
        offset += 1;
      }

      // 10. lightValue (2 bytes)
      if (existMap[10] == true) {
        if (offset + 2 > bodyData.length) {
          break;
        }
        record.lightValue = byteData.getUint16(offset, Endian.little);
        offset += 2;
      }

      // 11. bodyMomentum (2 bytes)
      if (existMap[11] == true) {
        if (offset + 2 > bodyData.length) {
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
}
