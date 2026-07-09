import 'dart:typed_data';
import 'crc16.dart';

class Packet {
  static const int typeAck = 1;
  static const int typeSessionConfig = 2;
  static const int typeData = 3;

  final int packetType;
  final int sequenceNumber;
  final Uint8List payload;

  Packet({
    required this.packetType,
    required this.sequenceNumber,
    required this.payload,
  });

  Uint8List encode() {
    final payloadBytes = payload;
    final buffer = BytesBuilder();
    buffer.add([0xA5, 0xA5]);
    buffer.addByte(packetType & 0xF);
    buffer.addByte(sequenceNumber & 0xFF);
    
    // Length (2 bytes short, little-endian)
    final lengthByteData = ByteData(2)..setUint16(0, payloadBytes.length, Endian.little);
    buffer.add(lengthByteData.buffer.asUint8List());

    // Checksum (2 bytes short, little-endian)
    final checksum = Crc16.ccitt(payloadBytes);
    final checksumByteData = ByteData(2)..setUint16(0, checksum, Endian.little);
    buffer.add(checksumByteData.buffer.asUint8List());

    buffer.add(payloadBytes);
    return buffer.takeBytes();
  }

  static Packet? decode(Uint8List bytes) {
    if (bytes.length < 8) return null;
    if (bytes[0] != 0xA5 || bytes[1] != 0xA5) return null;

    final packetType = bytes[2] & 0xF;
    final sequenceNumber = bytes[3];
    final payloadLength = bytes[4] | (bytes[5] << 8);
    final givenChecksum = bytes[6] | (bytes[7] << 8);

    if (bytes.length < 8 + payloadLength) return null;

    final payload = bytes.sublist(8, 8 + payloadLength);
    final calculatedChecksum = Crc16.ccitt(payload);

    if (calculatedChecksum != givenChecksum) {
      return null;
    }

    return Packet(
      packetType: packetType,
      sequenceNumber: sequenceNumber,
      payload: payload,
    );
  }
}
