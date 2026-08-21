import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../blobs/rides.dart';
import 'source.dart';

class UberSource implements RideSource {
  static const String _base = 'https://api.uber.com';

  const UberSource();

  Future<String?> _resolveToken(RideProviderConfig config) async {
    if (config.accessToken.isNotEmpty) return config.accessToken;
    if (config.clientId.isNotEmpty && config.clientSecret.isNotEmpty) {
      try {
        final uri = Uri.parse('https://login.uber.com/oauth/v2/token');
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'client_id': config.clientId,
            'client_secret': config.clientSecret,
            'grant_type': 'client_credentials',
          },
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
    if (token != null && token.isNotEmpty) {
      return {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
    }
    if (config.serverToken.isNotEmpty) {
      return {
        'Authorization': 'Token ${config.serverToken}',
        'Content-Type': 'application/json',
      };
    }
    return {'Content-Type': 'application/json'};
  }

  @override
  Future<bool> authenticate(RideProviderConfig config) async {
    final headers = await _headers(config);
    final uri = Uri.parse('$_base/v1.2/products?latitude=37.7758&longitude=-122.4180');
    final res = await http.get(uri, headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Uber auth failed (${res.statusCode}): ${res.body}');
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
      '$_base/v1.2/estimates/price?start_latitude=$originLat&start_longitude=$originLon&end_latitude=$destLat&end_longitude=$destLon',
    );

    final headers = await _headers(config);
    final res = await http.get(uri, headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Uber price estimates failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final prices = data['prices'] as List<dynamic>? ?? [];

    final List<RideEstimate> list = [];
    for (final item in prices) {
      final map = item as Map<String, dynamic>;
      final displayName = map['localized_display_name'] as String? ?? 'Uber';
      final low = (map['low_estimate'] as num?)?.toDouble();
      final high = (map['high_estimate'] as num?)?.toDouble();
      final avgPrice = low != null && high != null ? (low + high) / 2 : (low ?? high ?? 0.0);
      final duration = (map['duration'] as num?)?.toInt() ?? 0;
      final etaMinutes = (duration / 60).ceil();
      final fareId = map['fare_id'] as String? ?? 'uber_${map['product_id']}';

      final isXl = displayName.toLowerCase().contains('xl') ||
          displayName.toLowerCase().contains('6') ||
          displayName.toLowerCase().contains('suv');
      final itemCapacity = isXl ? 6 : 4;

      if (itemCapacity == capacity && avgPrice > 0) {
        list.add(
          RideEstimate(
            provider: 'uber',
            providerName: displayName,
            price: double.parse(avgPrice.toStringAsFixed(2)),
            currency: '\$',
            eta: etaMinutes > 0 ? etaMinutes : 3,
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

    final uri = Uri.parse('$_base/v1.2/requests');
    final body = {
      'fare_id': fareId,
      'start_latitude': originLat,
      'start_longitude': originLon,
      'end_latitude': destLat,
      'end_longitude': destLon,
    };

    final headers = await _headers(config);
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Uber booking failed (${res.statusCode}): ${res.body}');
    }

    return true;
  }
}
