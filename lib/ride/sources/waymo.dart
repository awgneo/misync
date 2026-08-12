import 'dart:math';
import 'source.dart';

class WaymoSource implements RideSource {
  const WaymoSource();

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
      final baseFare = capacity == 6 ? 7.50 : 4.50;
      final perMileRate = capacity == 6 ? 3.10 : 2.15;
      final eta = random.nextInt(6) + 3;
      final calculatedPrice = baseFare + (miles * perMileRate) + (eta * 0.50);

      return [
        RideEstimate(
          provider: 'waymo',
          providerName: 'Waymo Auto',
          price: double.parse(calculatedPrice.toStringAsFixed(2)),
          currency: '\$',
          eta: eta,
          capacity: capacity,
          fareId: 'waymo_${DateTime.now().millisecondsSinceEpoch}',
        ),
      ];
    }

    // Live API integration placeholder for Waymo autonomous API
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
    // Live API integration placeholder for Waymo booking
    return true;
  }
}
