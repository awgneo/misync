import '../blobs/rides.dart';

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
  Future<bool> authenticate(RideProviderConfig config);

  Future<List<RideEstimate>> getEstimates({
    required RideProviderConfig config,
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required int capacity,
  });

  Future<bool> book({
    required RideProviderConfig config,
    required String fareId,
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
  });
}
