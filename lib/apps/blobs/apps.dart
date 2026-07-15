import '../../storage/blob.dart';

class App {
  final bool enabled;
  final int versionCode;
  final String package;
  final bool external;
  final List<int> fingerprint;

  const App({
    required this.enabled,
    required this.versionCode,
    required this.package,
    required this.external,
    this.fingerprint = const [],
  });

  String get name {
    final lastSegment = package.split('.').last;
    if (lastSegment.isEmpty) return package;
    return '${lastSegment[0].toUpperCase()}${lastSegment.substring(1)}';
  }

  bool get isInternal => !external;

  factory App.fromJson(Map<String, dynamic> json) {
    return App(
      enabled: json['enabled'] as bool? ?? true,
      versionCode: json['versionCode'] as int? ?? 0,
      package: json['package'] as String? ?? '',
      external: json['external'] as bool? ?? false,
      fingerprint: List<int>.from(json['fingerprint'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'versionCode': versionCode,
    'package': package,
    'external': external,
    'fingerprint': fingerprint,
  };

  App copyWith({
    bool? enabled,
    int? versionCode,
    String? package,
    bool? external,
    List<int>? fingerprint,
  }) {
    return App(
      enabled: enabled ?? this.enabled,
      versionCode: versionCode ?? this.versionCode,
      package: package ?? this.package,
      external: external ?? this.external,
      fingerprint: fingerprint ?? this.fingerprint,
    );
  }
}

class AppsBlob extends Blob<Map<String, App>> {
  static final AppsBlob _instance = AppsBlob._();
  static AppsBlob get instance => _instance;

  AppsBlob._()
    : super(module: 'apps', name: 'installed_hashes', defaultValue: const {});

  static bool getEnabled(String package) {
    return instance.value[package]?.enabled ?? false;
  }

  static void setEnabled(String package, bool enabled) {
    final updated = Map<String, App>.from(instance.value);
    final current =
        updated[package] ??
        App(enabled: true, versionCode: 0, package: package, external: false);
    updated[package] = current.copyWith(enabled: enabled);
    instance.update(updated);
  }

  static int getVersionCode(String package) {
    return instance.value[package]?.versionCode ?? 0;
  }

  static void setVersionCode(String package, int versionCode) {
    final updated = Map<String, App>.from(instance.value);
    final current =
        updated[package] ??
        App(enabled: true, versionCode: 0, package: package, external: false);
    updated[package] = current.copyWith(versionCode: versionCode);
    instance.update(updated);
  }

  static void removeVersionCode(String package) {
    final updated = Map<String, App>.from(instance.value);
    final current = updated[package];
    if (current != null) {
      updated[package] = current.copyWith(versionCode: 0);
      instance.update(updated);
    }
  }

  @override
  Future<void> update(Map<String, App> newValue) async {
    final sortedEntries = newValue.entries.toList()
      ..sort((a, b) {
        if (a.value.external != b.value.external) {
          return a.value.external ? 1 : -1;
        }
        return a.value.name.compareTo(b.value.name);
      });
    final sortedMap = Map<String, App>.fromEntries(sortedEntries);
    await super.update(sortedMap);
  }

  @override
  Map<String, App> parse(dynamic json) {
    if (json is! Map) return const {};
    final parsed = json.map((key, val) {
      final map = Map<String, dynamic>.from(val ?? {});
      map['package'] ??= key as String;
      return MapEntry(key as String, App.fromJson(map));
    });
    final sortedEntries = parsed.entries.toList()
      ..sort((a, b) {
        if (a.value.external != b.value.external) {
          return a.value.external ? 1 : -1;
        }
        return a.value.name.compareTo(b.value.name);
      });
    return Map<String, App>.fromEntries(sortedEntries);
  }

  @override
  dynamic serialize(Map<String, App> value) {
    return value.map((key, val) => MapEntry(key, val.toJson()));
  }
}
