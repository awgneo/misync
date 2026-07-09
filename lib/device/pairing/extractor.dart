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

    // Extract Auth Key
    final encryptKeyMatch = encryptKeyRegex.firstMatch(content);
    if (encryptKeyMatch != null) {
      authKey = encryptKeyMatch.group(1);
    } else {
      final tokenMatch = tokenRegex.firstMatch(content);
      if (tokenMatch != null) {
        authKey = tokenMatch.group(1);
      }
    }

    // Extract MAC Suffix
    final macSuffixMatch = macSuffixRegex.firstMatch(content);
    if (macSuffixMatch != null) {
      macSuffix = macSuffixMatch.group(1);
    }

    // Extract DID
    final didMatch = didRegex.firstMatch(content);
    if (didMatch != null) {
      deviceId = didMatch.group(1);
    }

    // Extract Model
    final modelMatch = modelRegex.firstMatch(content);
    if (modelMatch != null) {
      model = modelMatch.group(1);
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
    if (filename.toLowerCase().endsWith('.zip')) {
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final file in archive) {
          if (!file.isFile) continue;
          if (!file.name.endsWith('.log') && !file.name.endsWith('.txt')) continue;
          final fileBytes = file.content as List<int>;
          final content = utf8.decode(fileBytes, allowMalformed: true);
          final creds = extractFromContent(content);
          if (creds != null) return creds;
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
