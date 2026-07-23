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

        // 3. Fetch snapshots for latest quotes and daily OHLCV
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

        // 4. Fetch 15-min historical bars for sparkline charts with start timestamp
        final Map<String, List<dynamic>> sparklinesMap = {};
        try {
          final DateTime start = DateTime.now().subtract(const Duration(days: 3));
          final String startTime =
              '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
          final int totalLimit = symbols.length * 100;
          final barsUri = Uri.parse(
            '$_dataBase/v2/stocks/bars?symbols=${symbols.join(',')}&timeframe=15Min&start=$startTime&limit=$totalLimit&feed=iex',
          );
          print('[FINANCE] Alpaca fetching bars URI: $barsUri');
          final barsReq = await client.getUrl(barsUri);
          barsReq.headers.set('APCA-API-KEY-ID', apiKey);
          barsReq.headers.set('APCA-API-SECRET-KEY', secretKey);
          final barsResp = await barsReq.close();
          final String body = await barsResp.transform(utf8.decoder).join();
          print('[FINANCE] Alpaca bars HTTP status: ${barsResp.statusCode}');
          if (barsResp.statusCode == 200) {
            final barsJson = jsonDecode(body) as Map<String, dynamic>;
            final barsBySymbol =
                barsJson['bars'] as Map<String, dynamic>? ?? {};
            for (final sym in symbols) {
              final barList = barsBySymbol[sym] as List<dynamic>? ?? [];
              final List<List<double>> candles = barList.map((b) {
                final map = b as Map;
                final o = ((map['o'] as num?)?.toDouble() ?? 0.0);
                final h = ((map['h'] as num?)?.toDouble() ?? 0.0);
                final l = ((map['l'] as num?)?.toDouble() ?? 0.0);
                final c = ((map['c'] as num?)?.toDouble() ?? 0.0);
                return [
                  double.parse(o.toStringAsFixed(2)),
                  double.parse(h.toStringAsFixed(2)),
                  double.parse(l.toStringAsFixed(2)),
                  double.parse(c.toStringAsFixed(2)),
                ];
              }).where((c) => c[0] > 0 && c[3] > 0).toList();
              sparklinesMap[sym] = candles.length > 24
                  ? candles.sublist(candles.length - 24)
                  : candles;
              print('[FINANCE] Alpaca OHLC candles for $sym: ${sparklinesMap[sym]?.length} bars');
            }
          } else {
            print('[FINANCE] Alpaca bars error ${barsResp.statusCode}: $body');
          }
        } catch (e) {
          print('[FINANCE] Alpaca bars exception: $e');
        }

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

            final dailyBar = snapshot['dailyBar'] as Map<String, dynamic>?;
            final double openPrice =
                (dailyBar?['o'] as num?)?.toDouble() ?? closePrice;
            final double highPrice =
                (dailyBar?['h'] as num?)?.toDouble() ?? price;
            final double lowPrice =
                (dailyBar?['l'] as num?)?.toDouble() ?? price;
            final int volume = (dailyBar?['v'] as num?)?.toInt() ?? 0;
            final double vwap = (dailyBar?['vw'] as num?)?.toDouble() ?? price;

            final double changePercent = closePrice > 0
                ? ((price - closePrice) / closePrice) * 100
                : 0.0;
            final double changeAmount = price - closePrice;

            List<dynamic> sparklineData = sparklinesMap[symbol] ?? const [];
            if (sparklineData.isEmpty && price > 0) {
              sparklineData = _generateIntraday24Points(
                closePrice,
                openPrice,
                lowPrice,
                highPrice,
                vwap,
                price,
              );
            }

            itemsList.add(
              InvestmentsWatchlistItem(
                symbol: symbol,
                name: symbol,
                price: double.parse(price.toStringAsFixed(2)),
                change: double.parse(changePercent.toStringAsFixed(2)),
                changeAmount: double.parse(changeAmount.toStringAsFixed(2)),
                open: double.parse(openPrice.toStringAsFixed(2)),
                high: double.parse(highPrice.toStringAsFixed(2)),
                low: double.parse(lowPrice.toStringAsFixed(2)),
                prevClose: double.parse(closePrice.toStringAsFixed(2)),
                volume: volume,
                vwap: double.parse(vwap.toStringAsFixed(2)),
                sparkline: sparklineData,
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

  List<double> _generateIntraday24Points(
    double prevClose,
    double open,
    double low,
    double high,
    double vwap,
    double close,
  ) {
    final List<double> points = [];
    final bool isPositive = close >= prevClose;

    double step1, step2, step3, step4;
    if (isPositive) {
      step1 = open;
      step2 = low;
      step3 = vwap > 0 ? vwap : (low + high) / 2;
      step4 = high;
    } else {
      step1 = open;
      step2 = high;
      step3 = vwap > 0 ? vwap : (low + high) / 2;
      step4 = low;
    }

    for (int i = 0; i < 24; i++) {
      final double t = i / 23.0;
      double val;
      if (t <= 0.20) {
        val = prevClose + (step1 - prevClose) * (t / 0.20);
      } else if (t <= 0.45) {
        val = step1 + (step2 - step1) * ((t - 0.20) / 0.25);
      } else if (t <= 0.70) {
        val = step2 + (step3 - step2) * ((t - 0.45) / 0.25);
      } else if (t <= 0.88) {
        val = step3 + (step4 - step3) * ((t - 0.70) / 0.18);
      } else {
        val = step4 + (close - step4) * ((t - 0.88) / 0.12);
      }

      final double noise = ((i % 5 - 2) * 0.0008) * val;
      final double finalVal = double.parse((val + noise).toStringAsFixed(2));
      points.add(finalVal);
    }
    return points;
  }
}
