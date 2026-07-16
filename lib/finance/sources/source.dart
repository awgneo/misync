import '../blobs/investments.dart';

abstract class InvestmentSource {
  Future<bool> authenticate(String apiKey, String secretKey);
  Future<List<InvestmentsWatchlist>> getWatchlists(String apiKey, String secretKey);
  Future<void> saveWatchlist(
    String apiKey,
    String secretKey,
    String watchlistId,
    String name,
    List<String> symbols,
  );
}
