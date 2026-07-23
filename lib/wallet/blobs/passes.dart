import '../../storage/blob.dart';

class PassField {
  final String label;
  final String value;

  const PassField({
    required this.label,
    required this.value,
  });

  factory PassField.fromJson(Map<String, dynamic> json) {
    return PassField(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
    };
  }
}

class Pass {
  final String id;
  final String issuer;
  final String title;
  final String type; // "boardingPass", "eventTicket", "coupon", "storeCard", "generic"
  final String backgroundColor;
  final String foregroundColor;
  final String barcodeValue;
  final String barcodeFormat;
  final List<PassField> fields;
  final DateTime createdAt;

  const Pass({
    required this.id,
    required this.issuer,
    required this.title,
    required this.type,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.barcodeValue,
    required this.barcodeFormat,
    required this.fields,
    required this.createdAt,
  });

  factory Pass.fromJson(Map<String, dynamic> json) {
    final DateTime created;
    if (json['createdAt'] != null) {
      created = DateTime.parse(json['createdAt'] as String);
    } else {
      created = DateTime.now();
    }

    final fieldsList = (json['fields'] as List? ?? [])
        .map((f) => PassField.fromJson(Map<String, dynamic>.from(f as Map)))
        .toList();

    return Pass(
      id: json['id']?.toString() ?? 'pass_${created.millisecondsSinceEpoch}',
      issuer: json['issuer']?.toString() ?? 'Pass',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'generic',
      backgroundColor: json['backgroundColor']?.toString() ?? '#111827',
      foregroundColor: json['foregroundColor']?.toString() ?? '#ffffff',
      barcodeValue: json['barcodeValue']?.toString() ?? '',
      barcodeFormat: json['barcodeFormat']?.toString() ?? 'PKBarcodeFormatQR',
      fields: fieldsList,
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issuer': issuer,
      'title': title,
      'type': type,
      'backgroundColor': backgroundColor,
      'foregroundColor': foregroundColor,
      'barcodeValue': barcodeValue,
      'barcodeFormat': barcodeFormat,
      'fields': fields.map((f) => f.toJson()).toList(),
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
    list.removeWhere((item) => item.id == pass.id); // 100% Idempotent Replacement!
    list.insert(0, pass);
    await update(list);
  }

  Future<void> removePass(String id) async {
    final list = List<Pass>.from(value);
    list.removeWhere((item) => item.id == id);
    await update(list);
  }
}
