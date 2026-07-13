import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

class XiaomiDeviceCredentials {
  final String authKey;
  final String macAddress;
  final String deviceId;
  final String model;

  XiaomiDeviceCredentials({
    required this.authKey,
    required this.macAddress,
    required this.deviceId,
    required this.model,
  });

  @override
  String toString() {
    return 'Credentials(MAC: $macAddress, DID: $deviceId, Model: $model, Key: $authKey)';
  }
}

class Extractor {
  static XiaomiDeviceCredentials? extractFromContent(String content) {
    String? authKey;
    String? macSuffix;
    String? deviceId;
    String? model;
    final List<String> allMacAddresses = [];

    // Case-insensitive regexes
    final encryptKeyRegex = RegExp(r'"encryptKey"\s*:\s*"([0-9a-fA-F]{32})"', caseSensitive: false);
    final tokenRegex = RegExp(r'"token"\s*:\s*"([0-9a-fA-F]{32})"', caseSensitive: false);
    final macSuffixRegex = RegExp(r'"mac"\s*:\s*"([0-9a-fA-F]{2}:[0-9a-fA-F]{2})"', caseSensitive: false);
    final didRegex = RegExp(r'"did"\s*:\s*"([0-9]+)"', caseSensitive: false);
    final modelRegex = RegExp(r'"model"\s*:\s*"([^"]+)"', caseSensitive: false);
    final fullMacRegex = RegExp(r'([0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2})');

    // Extract Auth Key (take the last one as it's the most recent pairing)
    final encryptKeyMatches = encryptKeyRegex.allMatches(content);
    if (encryptKeyMatches.isNotEmpty) {
      authKey = encryptKeyMatches.last.group(1);
    } else {
      final tokenMatches = tokenRegex.allMatches(content);
      if (tokenMatches.isNotEmpty) {
        authKey = tokenMatches.last.group(1);
      }
    }

    // Extract MAC Suffix (take the last one)
    final macSuffixMatches = macSuffixRegex.allMatches(content);
    if (macSuffixMatches.isNotEmpty) {
      macSuffix = macSuffixMatches.last.group(1);
    }

    // Extract DID (take the last one)
    final didMatches = didRegex.allMatches(content);
    if (didMatches.isNotEmpty) {
      deviceId = didMatches.last.group(1);
    }

    // Extract Model (take the last one)
    final modelMatches = modelRegex.allMatches(content);
    if (modelMatches.isNotEmpty) {
      model = modelMatches.last.group(1);
    }

    // Collect all full MAC addresses
    final matches = fullMacRegex.allMatches(content);
    for (final match in matches) {
      final mac = match.group(0);
      if (mac != null && !allMacAddresses.contains(mac)) {
        allMacAddresses.add(mac);
      }
    }

    if (authKey == null) return null;

    // Resolve full MAC address targeting the suffix if found
    String? resolvedMac;
    if (macSuffix != null) {
      final suffixUpper = macSuffix.replaceAll(':', '').toUpperCase();
      for (final mac in allMacAddresses) {
        final macClean = mac.replaceAll(':', '').toUpperCase();
        if (macClean.endsWith(suffixUpper)) {
          resolvedMac = mac;
          break;
        }
      }
    }

    if (resolvedMac == null && allMacAddresses.isNotEmpty) {
      resolvedMac = allMacAddresses.first;
    }

    if (resolvedMac == null) return null;

    return XiaomiDeviceCredentials(
      authKey: authKey,
      macAddress: resolvedMac,
      deviceId: deviceId ?? 'Unknown',
      model: model ?? 'miwear.watch.p67cn',
    );
  }

  static XiaomiDeviceCredentials? extractFromBytes(Uint8List bytes, String filename) {
    return _extract(bytes, filename, 0);
  }

  static XiaomiDeviceCredentials? _extract(Uint8List bytes, String filename, int depth) {
    if (depth > 3) return null; // Prevent deep recursion or circular zips

    final lowerFilename = filename.toLowerCase();
    if (lowerFilename.endsWith('.zip')) {
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final file in archive) {
          if (!file.isFile) continue;
          final fileBytes = file.content as List<int>;
          final u8bytes = Uint8List.fromList(fileBytes);

          if (file.name.toLowerCase().endsWith('.zip')) {
            final creds = _extract(u8bytes, file.name, depth + 1);
            if (creds != null) return creds;
          } else {
            final lowerName = file.name.toLowerCase();
            final isLogFile = lowerName.contains('.log') ||
                lowerName.contains('.txt') ||
                lowerName.contains('log_') ||
                lowerName.contains('device_log');
            if (isLogFile && file.size <= 15 * 1024 * 1024) {
              final content = utf8.decode(fileBytes, allowMalformed: true);
              final creds = extractFromContent(content);
              if (creds != null) return creds;
            }
          }
        }
      } catch (_) {}
    } else {
      try {
        final content = utf8.decode(bytes, allowMalformed: true);
        return extractFromContent(content);
      } catch (_) {}
    }
    return null;
  }
}
