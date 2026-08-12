import 'dart:math';

class RideEstimate {
  final String provider;
  final String providerName;
  final double price;
  final String currency;
  final int eta;
  final int capacity;
  final String fareId;

  const RideEstimate({
    required this.provider,
    required this.providerName,
    required this.price,
    this.currency = '\$',
    required this.eta,
    required this.capacity,
    required this.fareId,
  });

  factory RideEstimate.fromJson(Map<String, dynamic> json) {
    return RideEstimate(
      provider: json['provider'] as String? ?? '',
      providerName: json['providerName'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? '\$',
      eta: (json['eta'] as num?)?.toInt() ?? 0,
      capacity: (json['capacity'] as num?)?.toInt() ?? 4,
      fareId: json['fareId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'providerName': providerName,
      'price': price,
      'currency': currency,
      'eta': eta,
      'capacity': capacity,
      'fareId': fareId,
    };
  }
}

abstract class RideSource {
  Future<List<RideEstimate>> getEstimates({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required int capacity,
    required bool mockMode,
  });

  Future<bool> book({
    required String fareId,
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required bool mockMode,
  });
}

double calculateDistanceMiles(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  if (lat1 == lat2 && lon1 == lon2) return 6.5;
  const p = 0.017453292519943295;
  final a = 0.5 -
      cos((lat2 - lat1) * p) / 2 +
      cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
  final km = 12742 * asin(sqrt(a));
  final miles = km * 0.621371;
  return miles < 1.0 ? 6.5 : miles;
}
