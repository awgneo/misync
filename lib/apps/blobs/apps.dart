import '../../storage/blob.dart';

class App {
  final bool enabled;
  final String hash;
  final String name;
  final bool external;
  final List<int> fingerprint;

  const App({
    required this.enabled,
    required this.hash,
    required this.name,
    required this.external,
    this.fingerprint = const [],
  });

  factory App.fromJson(Map<String, dynamic> json) {
    return App(
      enabled: json['enabled'] as bool? ?? true,
      hash: json['hash'] as String? ?? '',
      name: json['name'] as String? ?? '',
      external: json['external'] as bool? ?? false,
      fingerprint: List<int>.from(json['fingerprint'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hash': hash,
        'name': name,
        'external': external,
        'fingerprint': fingerprint,
      };

  App copyWith({
    bool? enabled,
    String? hash,
    String? name,
    bool? external,
    List<int>? fingerprint,
  }) {
    return App(
      enabled: enabled ?? this.enabled,
      hash: hash ?? this.hash,
      name: name ?? this.name,
      external: external ?? this.external,
      fingerprint: fingerprint ?? this.fingerprint,
    );
  }
}

class AppsBlob extends Blob<Map<String, App>> {
  static final AppsBlob _instance = AppsBlob._();
  static AppsBlob get instance => _instance;

  AppsBlob._()
      : super(
          module: 'apps',
          name: 'installed_hashes',
          defaultValue: const {
            'com.misync.messages': App(
              enabled: true,
              hash: '',
              name: 'Messages',
              external: false,
            ),
          },
        );

  static bool isEnabled(String package) {
    return instance.value[package]?.enabled ?? true;
  }

  static void setEnabled(String package, bool enabled) {
    final updated = Map<String, App>.from(instance.value);
    final current = updated[package] ??
        const App(enabled: true, hash: '', name: '', external: false);
    updated[package] = current.copyWith(enabled: enabled);
    instance.update(updated);
  }

  static String getHash(String package) {
    return instance.value[package]?.hash ?? '';
  }

  static void setHash(String package, String hash) {
    final updated = Map<String, App>.from(instance.value);
    final current = updated[package] ??
        const App(enabled: true, hash: '', name: '', external: false);
    updated[package] = current.copyWith(hash: hash);
    instance.update(updated);
  }

  static void removeHash(String package) {
    final updated = Map<String, App>.from(instance.value);
    final current = updated[package];
    if (current != null) {
      updated[package] = current.copyWith(hash: '');
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
    final parsed = json.map((key, val) => MapEntry(
          key as String,
          App.fromJson(Map<String, dynamic>.from(val ?? {})),
        ));
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
