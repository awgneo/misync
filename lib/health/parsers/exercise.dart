import 'dart:typed_data';
import 'types/exercise.dart';
import 'id.dart';
import 'schemas.dart';

class ExerciseParser {
  static Exercise parse(Id id, Uint8List data) {
    if (data.length < 7) return Exercise(id.timeStamp);
    final remaining = data.sublist(7);
    final dataValidLen = _getDataValidityLen(id);
    if (remaining.length < 1 + dataValidLen) {
      return Exercise(id.timeStamp);
    }
    final dataValid = remaining.sublist(1, 1 + dataValidLen);
    final bodyData = remaining.sublist(1 + dataValidLen);

    final report = Exercise(id.timeStamp);
    final byteData = ByteData.sublistView(bodyData);
    final schema = Schemas.exercise(id.sportType);

    // 1. Parse dataValid map
    final validMap = <int, bool>{};
    int bitIdx = 0;
    for (final dt in schema) {
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

    // 2. Helper to check if data item exists based on supportVersion and dependData
    bool isDataExist(OneDimenDataType dt, Map<int, dynamic> parsed) {
      if (dt.supportVersion > id.version) {
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
    if (id.sportType == 14) {
      if (parsedValues[48] != null) report.steps = parsedValues[48];
      if (parsedValues[49] != null) report.avgCadence = parsedValues[49];
      if (parsedValues[50] != null) report.maxCadence = parsedValues[50];
    } else {
      if (parsedValues[7] != null) report.steps = parsedValues[7];
    }

    report.sportType = id.sportType;

    return report;
  }

  static int _getDataValidityLen(Id id) {
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
}
