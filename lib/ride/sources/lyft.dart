import 'dart:math';
import 'source.dart';

class LyftSource implements RideSource {
  const LyftSource();

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
      final baseFare = capacity == 6 ? 6.80 : 3.80;
      final perMileRate = capacity == 6 ? 2.75 : 1.90;
      final eta = random.nextInt(5) + 1;
      final calculatedPrice = baseFare + (miles * perMileRate) + (eta * 0.35);

      return [
        RideEstimate(
          provider: 'lyft',
          providerName: capacity == 6 ? 'Lyft XL' : 'Lyft',
          price: double.parse(calculatedPrice.toStringAsFixed(2)),
          currency: '\$',
          eta: eta,
          capacity: capacity,
          fareId: 'lyft_${DateTime.now().millisecondsSinceEpoch}',
        ),
      ];
    }

    // Live API integration placeholder for Lyft Cost API GET /v1/cost
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
    // Live API integration placeholder for Lyft POST /v1/rides
    return true;
  }
}
