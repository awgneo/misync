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

class DependDataType {
  final int type;
  final List<int> values;
  const DependDataType(this.type, this.values);
}
