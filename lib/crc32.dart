class Crc32 {
  static final List<int> _table = List<int>.generate(256, (i) {
    int c = i;
    for (int k = 0; k < 8; ++k) {
      if ((c & 1) != 0) {
        c = 0xEDB88320 ^ (c >> 1);
      } else {
        c = c >> 1;
      }
    }
    return c;
  });

  /// Computes the IEEE 802.3 CRC-32 checksum of the given [bytes].
  static int calculate(List<int> bytes) {
    int c = 0xFFFFFFFF;
    for (int i = 0; i < bytes.length; ++i) {
      c = _table[(c ^ bytes[i]) & 0xFF] ^ (c >> 8);
    }
    return c ^ 0xFFFFFFFF;
  }
}
