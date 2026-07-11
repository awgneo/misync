import 'dart:typed_data';

class App {
  final String package;
  final String name;
  final Uint8List? icon;

  App({
    required this.package,
    required this.name,
    this.icon,
  });

  factory App.fromJson(Map<String, dynamic> json) {
    final rawBytes = json['iconBytes'] as List<dynamic>?;
    final bytes = rawBytes != null ? Uint8List.fromList(rawBytes.cast<int>()) : null;

    return App(
      package: json['packageName'] as String? ?? '',
      name: json['appName'] as String? ?? '',
      icon: bytes,
    );
  }
}
