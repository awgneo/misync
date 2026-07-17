import 'dart:convert';
import 'dart:io';
import '../blobs/investments.dart';
import 'source.dart';

class AlpacaSource implements InvestmentSource {
  static const String _base = 'https://api.alpaca.markets';
  static const String _dataBase = 'https://data.alpaca.markets';

  @override
  Future<bool> authenticate(String apiKey, String secretKey) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_base/v2/watchlists');
      final req = await client.getUrl(uri);
      req.headers.set('APCA-API-KEY-ID', apiKey);
      req.headers.set('APCA-API-SECRET-KEY', secretKey);
      final resp = await req.close();
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  @override
  Future<List<InvestmentsWatchlist>> getWatchlists(String apiKey, String secretKey) async {
    final client = HttpClient();
    final List<InvestmentsWatchlist> compiledWatchlists = [];
    try {
      // 1. Fetch watchlists list
      final watchlistsUri = Uri.parse('$_base/v2/watchlists');
      final watchlistsReq = await client.getUrl(watchlistsUri);
      watchlistsReq.headers.set('APCA-API-KEY-ID', apiKey);
      watchlistsReq.headers.set('APCA-API-SECRET-KEY', secretKey);

      final watchlistsResp = await watchlistsReq.close();
      if (watchlistsResp.statusCode != 200) {
        throw HttpException('Failed to fetch watchlists: ${watchlistsResp.statusCode}');
      }

      final watchlistsJson =
          jsonDecode(await watchlistsResp.transform(utf8.decoder).join())
              as List<dynamic>;

      for (final wl in watchlistsJson) {
        final wlMap = Map<String, dynamic>.from(wl as Map);
        final String wlId = wlMap['id'];
        final String wlName = wlMap['name'];

        // 2. Fetch watchlist details (assets)
        final wlDetailUri = Uri.parse('$_base/v2/watchlists/$wlId');
        final wlDetailReq = await client.getUrl(wlDetailUri);
        wlDetailReq.headers.set('APCA-API-KEY-ID', apiKey);
        wlDetailReq.headers.set('APCA-API-SECRET-KEY', secretKey);

        final wlDetailResp = await wlDetailReq.close();
        if (wlDetailResp.statusCode != 200) {
          continue;
        }

        final wlDetailJson =
            jsonDecode(await wlDetailResp.transform(utf8.decoder).join())
                as Map<String, dynamic>;
        final assets = wlDetailJson['assets'] as List<dynamic>? ?? [];
        final List<String> symbols =
            assets.map((a) => (a as Map)['symbol'] as String).toList();

        if (symbols.isEmpty) {
          compiledWatchlists.add(
            InvestmentsWatchlist(id: wlId, name: wlName, items: const []),
          );
          continue;
        }

        // 3. Fetch snapshots for latest quotes
        final snapshotsUri = Uri.parse(
          '$_dataBase/v2/stocks/snapshots?symbols=${symbols.join(',')}',
        );
        final snapshotsReq = await client.getUrl(snapshotsUri);
        snapshotsReq.headers.set('APCA-API-KEY-ID', apiKey);
        snapshotsReq.headers.set('APCA-API-SECRET-KEY', secretKey);

        final snapshotsResp = await snapshotsReq.close();
        if (snapshotsResp.statusCode != 200) {
          continue;
        }

        final snapshotsJson =
            jsonDecode(await snapshotsResp.transform(utf8.decoder).join())
                as Map<String, dynamic>;
        final List<InvestmentsWatchlistItem> itemsList = [];

        for (final symbol in symbols) {
          final snapshot = snapshotsJson[symbol];
          if (snapshot != null) {
            final latestTrade =
                snapshot['latestTrade'] as Map<String, dynamic>?;
            final double price = (latestTrade?['p'] as num?)?.toDouble() ?? 0.0;

            final prevDailyBar =
                snapshot['prevDailyBar'] as Map<String, dynamic>?;
            final double closePrice =
                (prevDailyBar?['c'] as num?)?.toDouble() ?? price;

            final double changePercent = closePrice > 0
                ? ((price - closePrice) / closePrice) * 100
                : 0.0;

            itemsList.add(
              InvestmentsWatchlistItem(
                symbol: symbol,
                price: double.parse(price.toStringAsFixed(2)),
                change: double.parse(changePercent.toStringAsFixed(2)),
              ),
            );
          } else {
            itemsList.add(
              InvestmentsWatchlistItem(symbol: symbol, price: 0.0, change: 0.0),
            );
          }
        }

        compiledWatchlists.add(
          InvestmentsWatchlist(id: wlId, name: wlName, items: itemsList),
        );
      }
    } finally {
      client.close();
    }
    return compiledWatchlists;
  }

  @override
  Future<void> saveWatchlist(
    String apiKey,
    String secretKey,
    String watchlistId,
    String name,
    List<String> symbols,
  ) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_base/v2/watchlists/$watchlistId');
      final req = await client.putUrl(uri);
      req.headers.set('APCA-API-KEY-ID', apiKey);
      req.headers.set('APCA-API-SECRET-KEY', secretKey);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      final body = jsonEncode({
        'name': name,
        'symbols': symbols,
      });
      req.write(body);

      final resp = await req.close();
      if (resp.statusCode != 200) {
        final err = await resp.transform(utf8.decoder).join();
        throw HttpException(
          'Failed to update watchlist: ${resp.statusCode} - $err',
        );
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<String> createWatchlist(
    String apiKey,
    String secretKey,
    String name,
    List<String> symbols,
  ) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_base/v2/watchlists');
      final req = await client.postUrl(uri);
      req.headers.set('APCA-API-KEY-ID', apiKey);
      req.headers.set('APCA-API-SECRET-KEY', secretKey);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      final body = jsonEncode({
        'name': name,
        'symbols': symbols,
      });
      req.write(body);

      final resp = await req.close();
      final resStr = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) {
        throw HttpException(
          'Failed to create watchlist: ${resp.statusCode} - $resStr',
        );
      }
      final data = jsonDecode(resStr);
      return data['id'] as String;
    } finally {
      client.close();
    }
  }

  @override
  Future<void> deleteWatchlist(
    String apiKey,
    String secretKey,
    String watchlistId,
  ) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_base/v2/watchlists/$watchlistId');
      final req = await client.deleteUrl(uri);
      req.headers.set('APCA-API-KEY-ID', apiKey);
      req.headers.set('APCA-API-SECRET-KEY', secretKey);

      final resp = await req.close();
      if (resp.statusCode != 204 && resp.statusCode != 200) {
        final err = await resp.transform(utf8.decoder).join();
        throw HttpException(
          'Failed to delete watchlist: ${resp.statusCode} - $err',
        );
      }
    } finally {
      client.close();
    }
  }
}
