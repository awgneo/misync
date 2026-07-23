import 'dart:convert';
import '../../storage/blob.dart';

class PassBarcode {
  final String message;
  final String format;
  final String? altText;

  const PassBarcode({
    required this.message,
    required this.format,
    this.altText,
  });

  factory PassBarcode.fromJson(Map<String, dynamic> json) {
    return PassBarcode(
      message: json['message']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
      altText: json['altText']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'format': format,
      if (altText != null) 'altText': altText,
    };
  }
}

class PassField {
  final String key;
  final String label;
  final String value;

  const PassField({
    required this.key,
    required this.label,
    required this.value,
  });

  factory PassField.fromJson(Map<String, dynamic> json) {
    return PassField(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'label': label,
      'value': value,
    };
  }
}

class Pass {
  final int formatVersion;
  final String passTypeIdentifier;
  final String serialNumber;
  final String? teamIdentifier;
  final String organizationName;
  final String description;
  final String? logoText;
  final String? relevantDate;
  final String? expirationDate;
  final String? foregroundColor;
  final String? backgroundColor;
  final String? labelColor;
  final List<PassBarcode> barcodes;
  final String passType; // "boardingPass", "eventTicket", "coupon", "generic", "storeCard"
  final List<PassField> fields;
  final DateTime createdAt;

  const Pass({
    this.formatVersion = 1,
    required this.passTypeIdentifier,
    required this.serialNumber,
    this.teamIdentifier,
    required this.organizationName,
    required this.description,
    this.logoText,
    this.relevantDate,
    this.expirationDate,
    this.foregroundColor,
    this.backgroundColor,
    this.labelColor,
    required this.barcodes,
    required this.passType,
    required this.fields,
    required this.createdAt,
  });

  String get barcodeMessage => barcodes.isNotEmpty ? barcodes.first.message : '';
  String get barcodeFormat => barcodes.isNotEmpty ? barcodes.first.format : '';

  factory Pass.fromJson(Map<String, dynamic> rawJson) {
    Map<String, dynamic> json = rawJson;
    if (rawJson['passJson'] != null) {
      try {
        json = jsonDecode(rawJson['passJson'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    final DateTime created;
    if (rawJson['createdAt'] != null) {
      created = DateTime.parse(rawJson['createdAt'] as String);
    } else {
      created = DateTime.now();
    }

    final int fmtVer = (json['formatVersion'] as num?)?.toInt() ?? 1;
    final String passTypeIdent = json['passTypeIdentifier']?.toString() ?? rawJson['passTypeIdentifier']?.toString() ?? '';
    final String serialNum = json['serialNumber']?.toString() ?? rawJson['serialNumber']?.toString() ?? '';
    final String? teamIdent = json['teamIdentifier']?.toString() ?? rawJson['teamIdentifier']?.toString();
    final String orgName = json['organizationName']?.toString() ?? rawJson['organizationName']?.toString() ?? 'Pass';
    final String? logoTxt = json['logoText']?.toString() ?? rawJson['logoText']?.toString();
    final String? relDate = json['relevantDate']?.toString() ?? rawJson['relevantDate']?.toString();
    final String? expDate = json['expirationDate']?.toString() ?? rawJson['expirationDate']?.toString();

    // Convert colors to Hex for QuickApp CSS compatibility
    final String? fgColor = _parseColorToHex(json['foregroundColor']?.toString() ?? rawJson['foregroundColor']?.toString());
    final String? bgColor = _parseColorToHex(json['backgroundColor']?.toString() ?? rawJson['backgroundColor']?.toString());
    final String? lblColor = _parseColorToHex(json['labelColor']?.toString() ?? rawJson['labelColor']?.toString());

    // Parse barcodes
    final barcodesList = <PassBarcode>[];
    if (rawJson['barcodes'] is List) {
      for (final b in rawJson['barcodes'] as List) {
        if (b is Map) barcodesList.add(PassBarcode.fromJson(Map<String, dynamic>.from(b)));
      }
    } else if (json['barcodes'] is List) {
      for (final b in json['barcodes'] as List) {
        if (b is Map) barcodesList.add(PassBarcode.fromJson(Map<String, dynamic>.from(b)));
      }
    } else if (json['barcode'] is Map) {
      barcodesList.add(PassBarcode.fromJson(Map<String, dynamic>.from(json['barcode'] as Map)));
    } else if (rawJson['barcodeMessage'] != null) {
      barcodesList.add(PassBarcode(
        message: rawJson['barcodeMessage'].toString(),
        format: rawJson['barcodeFormat']?.toString() ?? '',
      ));
    }

    // Extract fields & passType
    final extractedResult = _extractPassFields(json, rawJson);

    final List<PassField> parsedFields;
    if (rawJson['fields'] is List) {
      parsedFields = (rawJson['fields'] as List)
          .map((f) => PassField.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList();
    } else {
      parsedFields = extractedResult.fields;
    }

    final String rawDesc = (json['description']?.toString() ?? rawJson['description']?.toString() ?? '').trim();
    final String finalDesc = _sanitizeDescription(rawDesc, orgName, parsedFields);

    return Pass(
      formatVersion: fmtVer,
      passTypeIdentifier: passTypeIdent,
      serialNumber: serialNum,
      teamIdentifier: teamIdent,
      organizationName: orgName,
      description: finalDesc,
      logoText: logoTxt,
      relevantDate: relDate,
      expirationDate: expDate,
      foregroundColor: fgColor,
      backgroundColor: bgColor,
      labelColor: lblColor,
      barcodes: barcodesList,
      passType: extractedResult.passType,
      fields: parsedFields,
      createdAt: created,
    );
  }

  static String? _parseColorToHex(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final str = raw.trim().toLowerCase();
    if (str.startsWith('#')) return str;

    final rgbMatch = RegExp(r'rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)').firstMatch(str);
    if (rgbMatch != null) {
      final r = int.parse(rgbMatch.group(1)!);
      final g = int.parse(rgbMatch.group(2)!);
      final b = int.parse(rgbMatch.group(3)!);
      return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
    }
    return str;
  }

  static String _cleanLabel(String rawLabel) {
    if (rawLabel.trim().isEmpty) return 'INFO';
    var label = rawLabel.trim();

    // Strip trailing 'Heading', 'heading', 'Label', 'label', 'Text', 'text'
    label = label.replaceAll(RegExp(r'(Heading|heading|Label|label|Text|text)$'), '').trim();
    if (label.isEmpty) label = rawLabel.trim();

    // Insert spaces before capital letters (camelCase to Title Case)
    label = label.replaceAll(RegExp(r'(?<=[a-z])(?=[A-Z])'), ' ');
    label = label.replaceAll(RegExp(r'[_]+'), ' ').trim();

    // Capitalize words
    return label.split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  static String _sanitizeDescription(String rawDesc, String orgName, List<PassField> fields) {
    if (rawDesc.isNotEmpty && rawDesc.toLowerCase() != 'description') {
      return rawDesc;
    }
    if (fields.isNotEmpty) {
      final parts = <String>[];
      for (final f in fields) {
        if (parts.length < 3 && f.value.isNotEmpty) {
          if (f.label.isNotEmpty && f.label != 'INFO' && !f.value.toLowerCase().contains(f.label.toLowerCase())) {
            parts.add('${f.label} ${f.value}');
          } else {
            parts.add(f.value);
          }
        }
      }
      if (parts.isNotEmpty) return parts.join(' • ');
    }
    return orgName;
  }

  static _ExtractedPass _extractPassFields(Map<String, dynamic> json, Map<String, dynamic> raw) {
    String passType = 'generic';
    Map<String, dynamic>? passTypeObj;
    const passKeys = ['boardingPass', 'eventTicket', 'coupon', 'generic', 'storeCard'];
    for (final key in passKeys) {
      if (json[key] is Map) {
        passType = key;
        passTypeObj = Map<String, dynamic>.from(json[key] as Map);
        break;
      }
    }

    final fields = <PassField>[];
    if (passTypeObj == null) {
      return _ExtractedPass(passType: passType, fields: fields);
    }

    void processFieldArray(String arrayKey) {
      final arr = passTypeObj![arrayKey] as List?;
      if (arr == null) return;

      for (final item in arr) {
        if (item is Map) {
          final k = (item['key']?.toString() ?? '').trim();
          final rawLabel = (item['label']?.toString() ?? '').trim();
          final value = (item['value']?.toString() ?? '').trim();
          if (value.isNotEmpty) {
            final cleanedLabel = _cleanLabel(rawLabel);
            fields.add(PassField(key: k, label: cleanedLabel, value: value));
          }
        }
      }
    }

    processFieldArray('primaryFields');
    processFieldArray('secondaryFields');
    processFieldArray('auxiliaryFields');
    processFieldArray('headerFields');

    return _ExtractedPass(passType: passType, fields: fields);
  }

  Map<String, dynamic> toJson() {
    return {
      'formatVersion': formatVersion,
      'passTypeIdentifier': passTypeIdentifier,
      'serialNumber': serialNumber,
      if (teamIdentifier != null) 'teamIdentifier': teamIdentifier,
      'organizationName': organizationName,
      'description': description,
      if (logoText != null) 'logoText': logoText,
      if (relevantDate != null) 'relevantDate': relevantDate,
      if (expirationDate != null) 'expirationDate': expirationDate,
      if (foregroundColor != null) 'foregroundColor': foregroundColor,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
      if (labelColor != null) 'labelColor': labelColor,
      'barcodeMessage': barcodeMessage,
      'barcodeFormat': barcodeFormat,
      'barcodes': barcodes.map((b) => b.toJson()).toList(),
      'passType': passType,
      'fields': fields.map((f) => f.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class _ExtractedPass {
  final String passType;
  final List<PassField> fields;

  _ExtractedPass({
    required this.passType,
    required this.fields,
  });
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
