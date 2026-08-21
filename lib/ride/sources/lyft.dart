import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../blobs/rides.dart';
import 'source.dart';

class LyftSource implements RideSource {
  static const String _base = 'https://api.lyft.com';

  const LyftSource();

  Future<String?> _resolveToken(RideProviderConfig config) async {
    if (config.accessToken.isNotEmpty) return config.accessToken;
    if (config.clientId.isNotEmpty && config.clientSecret.isNotEmpty) {
      try {
        final uri = Uri.parse('https://api.lyft.com/oauth/token');
        final basicAuth = base64Encode(utf8.encode('${config.clientId}:${config.clientSecret}'));
        final res = await http.post(
          uri,
          headers: {
            'Authorization': 'Basic $basicAuth',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'grant_type': 'client_credentials', 'scope': 'public'}),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          return data['access_token'] as String?;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, String>> _headers(RideProviderConfig config) async {
    final token = await _resolveToken(config);
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  @override
  Future<bool> authenticate(RideProviderConfig config) async {
    final headers = await _headers(config);
    final uri = Uri.parse('$_base/v1/ridetypes?lat=37.7758&lng=-122.4180');
    final res = await http.get(uri, headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Lyft auth failed (${res.statusCode}): ${res.body}');
    }
    return true;
  }

  @override
  Future<List<RideEstimate>> getEstimates({
    required RideProviderConfig config,
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required int capacity,
  }) async {
    if (!config.hasCredentials) return [];

    final uri = Uri.parse(
      '$_base/v1/cost?start_lat=$originLat&start_lng=$originLon&end_lat=$destLat&end_lng=$destLon',
    );

    final headers = await _headers(config);
    final res = await http.get(uri, headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Lyft cost estimates failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final costEstimates = data['cost_estimates'] as List<dynamic>? ?? [];

    final List<RideEstimate> list = [];
    for (final item in costEstimates) {
      final map = item as Map<String, dynamic>;
      final displayName = map['display_name'] as String? ?? 'Lyft';
      final rideType = map['ride_type'] as String? ?? 'lyft';
      final minCents = (map['estimated_cost_cents_min'] as num?)?.toDouble() ?? 0.0;
      final maxCents = (map['estimated_cost_cents_max'] as num?)?.toDouble() ?? 0.0;
      final avgCents = minCents > 0 && maxCents > 0 ? (minCents + maxCents) / 2 : (minCents > 0 ? minCents : maxCents);
      final price = avgCents / 100.0;
      final duration = (map['estimated_duration_seconds'] as num?)?.toInt() ?? 0;
      final etaMinutes = (duration / 60).ceil();
      final fareId = 'lyft_${rideType}_${DateTime.now().millisecondsSinceEpoch}';

      final isXl = rideType.contains('plus') ||
          rideType.contains('xl') ||
          displayName.toLowerCase().contains('xl') ||
          displayName.toLowerCase().contains('plus');
      final itemCapacity = isXl ? 6 : 4;

      if (itemCapacity == capacity && price > 0) {
        list.add(
          RideEstimate(
            provider: 'lyft',
            providerName: displayName,
            price: double.parse(price.toStringAsFixed(2)),
            currency: '\$',
            eta: etaMinutes > 0 ? etaMinutes : 2,
            capacity: itemCapacity,
            fareId: fareId,
          ),
        );
      }
    }

    return list;
  }

  @override
  Future<bool> book({
    required RideProviderConfig config,
    required String fareId,
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
  }) async {
    if (!config.hasCredentials) return false;

    final uri = Uri.parse('$_base/v1/rides');
    final body = {
      'ride_type': 'lyft',
      'origin': {'lat': originLat, 'lng': originLon},
      'destination': {'lat': destLat, 'lng': destLon},
    };

    final headers = await _headers(config);
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Lyft booking failed (${res.statusCode}): ${res.body}');
    }

    return true;
  }
}
