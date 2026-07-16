import 'dart:typed_data';
import 'types/snapshot.dart';
import 'id.dart';

class SnapshotsParser {
  static List<Snapshot> parse(Id id, Uint8List data) {
    if (data.length < 7) return [];
    final remaining = data.sublist(7);
    const dataValidLen = 6;
    if (remaining.length < 1 + dataValidLen) return [];
    final dataValid = remaining.sublist(1, 1 + dataValidLen);
    final bodyData = remaining.sublist(1 + dataValidLen);

    final records = <Snapshot>[];
    final byteData = ByteData.sublistView(bodyData);
    int offset = 0;

    // Daily log is written minute-by-minute (1440 entries max per daily log file)
    final startTime = id.timeStamp;
    const intervalSeconds = 60;

    // Reconstruct valid flags for v2 daily records (excluding index 9 which is dynamic)
    final flagsMap = <int, int>{};
    // There are 11 variables in v2DataInfoArray with non-null dataType
    // Each nibble (4 bits) in dataValid represents the flags for one variable.
    // - Bit 3 (val & 8) represents existence.
    // - Bit 2 (val & 4) represents the high component.
    // - Bit 1 (val & 2) represents the middle component.
    // - Bit 0 (val & 1) represents the low component.
    int varIdx = 0;
    for (int i = 0; i < 12; i++) {
      if (i == 9) continue; // Skip the dynamic variable
      final byteIdx = varIdx ~/ 2;
      final nibbleIdx = varIdx % 2;
      if (byteIdx < dataValid.length) {
        final b = dataValid[byteIdx];
        flagsMap[i] = (nibbleIdx == 0) ? ((b & 0xF0) >> 4) : (b & 0x0F);
      } else {
        flagsMap[i] = 0;
      }
      varIdx++;
    }

    bool exists(int i) => ((flagsMap[i] ?? 0) & 8) > 0;
    bool hasHigh(int i) => ((flagsMap[i] ?? 0) & 4) > 0;
    bool hasMiddle(int i) => ((flagsMap[i] ?? 0) & 2) > 0;
    bool hasLow(int i) => ((flagsMap[i] ?? 0) & 1) > 0;

    int currentTimestamp = (startTime ~/ intervalSeconds) * intervalSeconds;

    while (offset + 1 <= bodyData.length) {
      final record = Snapshot(currentTimestamp);

      // 0. IncludeSleep & abnormalHr & steps (2 bytes)
      if (exists(0)) {
        if (offset + 2 > bodyData.length) {
          break;
        }
        final val = byteData.getUint16(offset, Endian.little);
        offset += 2;
        if (hasLow(0)) {
          record.steps = val & 0x3FFF;
        }
        if (hasMiddle(0)) {
          record.isAbnormalHr = ((val >> 14) & 1) > 0;
        }
      }

      // 1. activityType & calories (1 byte)
      if (exists(1)) {
        if (offset + 1 > bodyData.length) {
          break;
        }
        final val = byteData.getUint8(offset);
        offset += 1;
        if (hasLow(1)) {
          record.calories = val & 0x3F;
        }
        if (hasHigh(1)) {
          record.activityType = (val >> 6) & 3;
        }
      }

      // 2. activityHILevel & sportType (1 byte)
      if (exists(2)) {
        if (offset + 1 > bodyData.length) {
          break;
        }
        final val = byteData.getUint8(offset);
        offset += 1;
        if (hasLow(2)) {
          record.sportType = val & 0x1F;
        }
        if (hasHigh(2)) {
          record.activityHILevel = (val >> 5) & 7;
        }
      }

      // 3. distance (2 bytes)
      if (exists(3)) {
        if (offset + 2 > bodyData.length) {
          break;
        }
        final val = byteData.getUint16(offset, Endian.little);
        offset += 2;
        if (hasHigh(3)) {
          record.distance = val;
        }
      }

      // 4. heart rate (1 byte)
      if (exists(4)) {
        if (offset + 1 > bodyData.length) {
          break;
        }
        final val = byteData.getUint8(offset);
        offset += 1;
        if (hasHigh(4)) {
          record.hr = val;
        }
      }

      // 5. energy (1 byte)
      if (exists(5)) {
        if (offset + 1 > bodyData.length) {
          break;
        }
        final val = byteData.getUint8(offset);
        offset += 1;
        if (hasHigh(5)) {
          record.energy = val;
        }
      }

      // 6. totalCal & energyState & energyStateValue (2 bytes)
      if (exists(6)) {
        if (offset + 2 > bodyData.length) {
          break;
        }
        final val = byteData.getUint16(offset, Endian.little);
        offset += 2;
        if (hasHigh(6)) {
          record.totalCal = (val >> 10) & 0x3F;
        }
        if (hasMiddle(6)) {
          record.energyState = (val >> 8) & 3;
        }
        if (hasLow(6)) {
          final rawVal = val & 0xFF;
          record.energyStateValue =
              (((rawVal & 128) > 0) ? 1 : -1) * (rawVal & 127);
        }
      }

      // 7. spo2 (1 byte)
      if (exists(7)) {
        if (offset + 1 > bodyData.length) {
          break;
        }
        final val = byteData.getUint8(offset);
        offset += 1;
        if (hasHigh(7)) {
          record.spo2 = val;
        }
      }

      // 8. stress (1 byte)
      if (exists(8)) {
        if (offset + 1 > bodyData.length) {
          break;
        }
        final val = byteData.getUint8(offset);
        offset += 1;
        if (hasHigh(8)) {
          record.stress = val;
        }
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
      if (exists(10)) {
        if (offset + 2 > bodyData.length) {
          break;
        }
        final val = byteData.getUint16(offset, Endian.little);
        offset += 2;
        if (hasHigh(10)) {
          record.lightValue = val;
        }
      }

      // 11. bodyMomentum (2 bytes)
      if (exists(11)) {
        if (offset + 2 > bodyData.length) {
          break;
        }
        final val = byteData.getUint16(offset, Endian.little);
        offset += 2;
        if (hasHigh(11)) {
          record.bodyMomentum = val;
        }
      }

      records.add(record);
      currentTimestamp += intervalSeconds;
    }

    return records;
  }
}
