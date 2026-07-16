import '../../storage/blob.dart';

class Finance {
  final Map<String, String> sources;

  const Finance({this.sources = const {}});

  Finance copyWith({Map<String, String>? sources}) {
    return Finance(sources: sources ?? this.sources);
  }

  factory Finance.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'] as Map<dynamic, dynamic>? ?? {};
    return Finance(sources: Map<String, String>.from(rawSources));
  }

  Map<String, dynamic> toJson() {
    return {'sources': sources};
  }
}

class FinanceBlob extends Blob<Finance> {
  static final FinanceBlob _instance = FinanceBlob._();
  static FinanceBlob get instance => _instance;

  FinanceBlob._()
    : super(module: 'finance', name: 'finance', defaultValue: const Finance());

  static Finance get finance => _instance.value;

  static String getSource(String subtype) {
    return finance.sources[subtype] ?? 'none';
  }

  static bool isSubtypeEnabled(String subtype) {
    final src = getSource(subtype);
    return src != 'none';
  }

  @override
  Finance parse(dynamic json) {
    if (json == null) return const Finance();
    return Finance.fromJson(Map<String, dynamic>.from(json as Map));
  }

  @override
  dynamic serialize(Finance value) => value.toJson();
}
