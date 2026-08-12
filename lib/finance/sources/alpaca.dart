import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../blobs/investments.dart';
import 'source.dart';

class AlpacaSource implements InvestmentSource {
  static const String _base = 'https://api.alpaca.markets';
  static const String _dataBase = 'https://data.alpaca.markets';

  Future<dynamic> _request(
    String method,
    String url,
    String apiKey,
    String secretKey, {
    Object? body,
  }) async {
    final uri = Uri.parse(url);
    final headers = {
      'APCA-API-KEY-ID': apiKey,
      'APCA-API-SECRET-KEY': secretKey,
      if (body != null) 'Content-Type': 'application/json',
    };

    final res = await (method == 'POST'
        ? http.post(uri, headers: headers, body: jsonEncode(body))
        : method == 'PUT'
            ? http.put(uri, headers: headers, body: jsonEncode(body))
            : method == 'DELETE'
                ? http.delete(uri, headers: headers)
                : http.get(uri, headers: headers));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException(
        'Alpaca API $method $url failed (${res.statusCode}): ${res.body}',
      );
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  @override
  Future<bool> authenticate(String apiKey, String secretKey) async {
    await _request('GET', '$_base/v2/watchlists', apiKey, secretKey);
    return true;
  }

  @override
  Future<List<InvestmentsWatchlist>> getWatchlists(
    String apiKey,
    String secretKey,
  ) async {
    final List<InvestmentsWatchlist> compiledWatchlists = [];

    // 1. Fetch watchlists list
    final watchlistsJson =
        await _request('GET', '$_base/v2/watchlists', apiKey, secretKey)
            as List<dynamic>;

    for (final wl in watchlistsJson) {
      final wlMap = Map<String, dynamic>.from(wl as Map);
      final String wlId = wlMap['id'];
      final String wlName = wlMap['name'];

      // 2. Fetch watchlist details (assets)
      final wlDetailJson =
          await _request(
                'GET',
                '$_base/v2/watchlists/$wlId',
                apiKey,
                secretKey,
              )
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
      final snapshotsJson =
          await _request(
                'GET',
                '$_dataBase/v2/stocks/snapshots?symbols=${symbols.join(',')}',
                apiKey,
                secretKey,
              )
              as Map<String, dynamic>;

      // 4. Fetch 15-min historical bars for sparkline charts
      final Map<String, List<dynamic>> sparklinesMap = {};
      final DateTime start = DateTime.now().subtract(const Duration(days: 3));
      final String startTime =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      final int totalLimit = symbols.length * 100;
      final barsUrl =
          '$_dataBase/v2/stocks/bars?symbols=${symbols.join(',')}&timeframe=15Min&start=$startTime&limit=$totalLimit&feed=iex';

      final barsJson =
          await _request('GET', barsUrl, apiKey, secretKey)
              as Map<String, dynamic>;
      final barsBySymbol = barsJson['bars'] as Map<String, dynamic>? ?? {};

      for (final sym in symbols) {
        final barList = barsBySymbol[sym] as List<dynamic>? ?? [];
        final List<List<double>> candles =
            barList
                .map((b) {
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
                })
                .where((c) => c[0] > 0 && c[3] > 0)
                .toList();
        sparklinesMap[sym] =
            candles.length > 24
                ? candles.sublist(candles.length - 24)
                : candles;
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

          final double changePercent =
              closePrice > 0 ? ((price - closePrice) / closePrice) * 100 : 0.0;
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
    await _request(
      'PUT',
      '$_base/v2/watchlists/$watchlistId',
      apiKey,
      secretKey,
      body: {'name': name, 'symbols': symbols},
    );
  }

  @override
  Future<String> createWatchlist(
    String apiKey,
    String secretKey,
    String name,
    List<String> symbols,
  ) async {
    final data =
        await _request(
              'POST',
              '$_base/v2/watchlists',
              apiKey,
              secretKey,
              body: {'name': name, 'symbols': symbols},
            )
            as Map<String, dynamic>;
    return data['id'] as String;
  }

  @override
  Future<void> deleteWatchlist(
    String apiKey,
    String secretKey,
    String watchlistId,
  ) async {
    await _request(
      'DELETE',
      '$_base/v2/watchlists/$watchlistId',
      apiKey,
      secretKey,
    );
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
