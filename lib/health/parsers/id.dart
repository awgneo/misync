import 'dart:typed_data';

class Id {
  static const int lengthDataId = 7;
  static const int dataTypeDaily = 0;
  static const int dataTypeSport = 1;
  static const int fileTypeDetail = 0;
  static const int fileTypeSummary = 1;
  static const int dailyTypeSleepNight = 3;
  static const int dailyTypeSleepDay = 2;
  final int timeStamp;
  final int tzIn15Min;
  final int version;
  final int dataType;
  final int sportType;
  final int dailyType;
  final int fileType;

  Id({
    required this.timeStamp,
    required this.tzIn15Min,
    required this.version,
    required this.dataType,
    required this.sportType,
    required this.dailyType,
    required this.fileType,
  });

  factory Id.fromBytes(Uint8List bytes) {
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

    return Id(
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
    return 'Id(timeStamp: $timeStamp, tzIn15Min: $tzIn15Min, dataType: $dataType, sportType: $sportType, dailyType: $dailyType, fileType: $fileType, version: $version)';
  }
}
