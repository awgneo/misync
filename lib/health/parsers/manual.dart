import 'dart:typed_data';
import 'package:misync/debug/logger.dart';
import 'types/measurement.dart';
import 'id.dart';

class MeasurementParser {
  static List<Measurement> parse(Id id, Uint8List data) {
    if (data.length < 8) return [];
    final bodyData = data.sublist(8);
    final byteData = ByteData.sublistView(bodyData);

    final records = <Measurement>[];
    int offset = 0;

    while (offset + 5 <= bodyData.length) {
      final timestamp = byteData.getUint32(offset, Endian.little);
      final typeInfo = byteData.getUint8(offset + 4);

      int dataType;
      int? dataLen;

      if (id.version == 1) {
        dataType = typeInfo;
        if (dataType == 1 || dataType == 2 || dataType == 3) {
          dataLen = 1;
        } else if (dataType == 4) {
          dataLen = 4;
        } else if (dataType == 5) {
          dataLen = 6;
        }
      } else {
        dataLen = (typeInfo >> 4) & 15;
        dataType = typeInfo & 15;
      }

      if (dataLen == null) {
        break; // Unsupported data type or version mapping
      }

      if (offset + 5 + dataLen > bodyData.length) {
        break; // Incomplete record
      }

      Measurement? record;
      final valOffset = offset + 5;
      final rawRecordBytes = bodyData.sublist(offset, offset + 5 + dataLen);
      final logStr = "MeasurementParser: offset=$offset, timestamp=$timestamp, dataType=$dataType, dataLen=$dataLen, hex=${rawRecordBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}";
      Logger('ManualParser').info(logStr);

      if (dataType == 1) {
        final bpm = byteData.getUint8(valOffset);
        if (bpm > 0) {
          record = HeartRateMeasurement(
            timestamp: timestamp,
            bpm: bpm,
          );
        }
      } else if (dataType == 2) {
        final percentage = byteData.getUint8(valOffset);
        if (percentage > 0) {
          record = OxygenSaturationMeasurement(
            timestamp: timestamp,
            percentage: percentage,
          );
        }
      } else if (dataType == 3) {
        final stress = byteData.getUint8(valOffset);
        if (stress > 0) {
          record = StressMeasurement(
            timestamp: timestamp,
            stress: stress,
          );
        }
      } else if (dataType == 4) {
        final rawSkin = byteData.getUint16(valOffset, Endian.little);
        final rawBody = byteData.getUint16(valOffset + 2, Endian.little);
        final skinTemp = rawSkin > 0 ? (rawSkin / 100.0) - 273.15 : null;
        final bodyTemp = rawBody > 0 ? (rawBody / 100.0) - 273.15 : null;
        if (skinTemp != null || bodyTemp != null) {
          record = TemperatureMeasurement(
            timestamp: timestamp,
            skinTemp: skinTemp,
            bodyTemp: bodyTemp,
          );
        }
      } else if (dataType == 5) {
        final systolic = byteData.getUint16(valOffset, Endian.little);
        final diastolic = byteData.getUint16(valOffset + 2, Endian.little);
        final pulse = byteData.getUint8(valOffset + 4);
        final status = byteData.getUint8(valOffset + 5);
        if (systolic > 0 && diastolic > 0) {
          record = BloodPressureMeasurement(
            timestamp: timestamp,
            systolic: systolic,
            diastolic: diastolic,
            pulse: pulse > 0 ? pulse : null,
            measurementStatus: status,
          );
        }
      }

      if (record != null) {
        records.add(record);
      }

      offset += 5 + dataLen;
    }

    return records;
  }
}
