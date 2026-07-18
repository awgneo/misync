import '../../storage/blob.dart';

class Pass {
  final String organizationName;
  final String description;
  final String serialNumber;
  final String passTypeIdentifier;
  final String barcodeMessage;
  final String barcodeFormat;
  final DateTime createdAt;

  const Pass({
    required this.organizationName,
    required this.description,
    required this.serialNumber,
    required this.passTypeIdentifier,
    required this.barcodeMessage,
    required this.barcodeFormat,
    required this.createdAt,
  });

  factory Pass.fromJson(Map<String, dynamic> json) {
    final DateTime created;
    if (json['createdAt'] != null) {
      created = DateTime.parse(json['createdAt'] as String);
    } else {
      created = DateTime.now();
    }
    return Pass(
      organizationName: json['organizationName'] ?? 'Unknown Organization',
      description: json['description'] ?? '',
      serialNumber: json['serialNumber'] ?? '',
      passTypeIdentifier: json['passTypeIdentifier'] ?? '',
      barcodeMessage: json['barcodeMessage'] ?? '',
      barcodeFormat: json['barcodeFormat'] ?? '',
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organizationName': organizationName,
      'description': description,
      'serialNumber': serialNumber,
      'passTypeIdentifier': passTypeIdentifier,
      'barcodeMessage': barcodeMessage,
      'barcodeFormat': barcodeFormat,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class PassesBlob extends Blob<List<Pass>> {
  PassesBlob()
    : super(module: 'wallet', name: 'passes', defaultValue: const []);

  static final PassesBlob instance = PassesBlob();

  static List<Pass> get passes {
    final list = List<Pass>.from(instance.value);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  List<Pass> parse(dynamic json) {
    if (json is List) {
      return json
          .map((item) => Pass.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  @override
  dynamic serialize(List<Pass> value) {
    return value.map((pass) => pass.toJson()).toList();
  }

  Future<void> addPass(Pass pass) async {
    final list = List<Pass>.from(value);
    list.removeWhere((item) => item.serialNumber == pass.serialNumber);
    list.insert(0, pass);
    await update(list);
  }

  Future<void> removePass(String serialNumber) async {
    final list = List<Pass>.from(value);
    list.removeWhere((item) => item.serialNumber == serialNumber);
    await update(list);
  }
}
