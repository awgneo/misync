import 'dart:math';
import 'source.dart';

class UberSource implements RideSource {
  const UberSource();

  @override
  Future<List<RideEstimate>> getEstimates({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required int capacity,
    required bool mockMode,
  }) async {
    if (mockMode) {
      final random = Random();
      final miles = calculateDistanceMiles(originLat, originLon, destLat, destLon);
      final baseFare = capacity == 6 ? 6.50 : 4.00;
      final perMileRate = capacity == 6 ? 2.80 : 1.95;
      final eta = random.nextInt(4) + 2;
      final calculatedPrice = baseFare + (miles * perMileRate) + (eta * 0.40);

      return [
        RideEstimate(
          provider: 'uber',
          providerName: capacity == 6 ? 'Uber XL' : 'UberX',
          price: double.parse(calculatedPrice.toStringAsFixed(2)),
          currency: '\$',
          eta: eta,
          capacity: capacity,
          fareId: 'uber_${DateTime.now().millisecondsSinceEpoch}',
        ),
      ];
    }

    // Live API integration placeholder for Uber Rides API GET /v1.2/estimates/price
    return [];
  }

  @override
  Future<bool> book({
    required String fareId,
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required bool mockMode,
  }) async {
    if (mockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }
    // Live API integration placeholder for Uber POST /v1.2/requests
    return true;
  }
}
