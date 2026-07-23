import '../../storage/blob.dart';

class InvestmentsWatchlistItem {
  final String symbol;
  final String name;
  final double price;
  final double change;
  final double changeAmount;

  // Daily OHLCV Metrics
  final double open;
  final double high;
  final double low;
  final double prevClose;
  final int volume;
  final double vwap;

  // Fundamental Metrics (Optional)
  final double? marketCap;
  final double? peRatio;
  final double? high52;
  final double? low52;
  final double? dividendYield;
  final double? eps;

  // Intraday Sparkline Trend Points (OHLC tuples or price numbers)
  final List<dynamic> sparkline;

  const InvestmentsWatchlistItem({
    required this.symbol,
    this.name = '',
    required this.price,
    required this.change,
    this.changeAmount = 0.0,
    this.open = 0.0,
    this.high = 0.0,
    this.low = 0.0,
    this.prevClose = 0.0,
    this.volume = 0,
    this.vwap = 0.0,
    this.marketCap,
    this.peRatio,
    this.high52,
    this.low52,
    this.dividendYield,
    this.eps,
    this.sparkline = const [],
  });

  factory InvestmentsWatchlistItem.fromJson(Map<String, dynamic> json) {
    final rawSparkline = json['sparkline'] as List<dynamic>? ?? [];
    return InvestmentsWatchlistItem(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      change: (json['change'] as num?)?.toDouble() ?? 0.0,
      changeAmount: (json['changeAmount'] as num?)?.toDouble() ?? 0.0,
      open: (json['open'] as num?)?.toDouble() ?? 0.0,
      high: (json['high'] as num?)?.toDouble() ?? 0.0,
      low: (json['low'] as num?)?.toDouble() ?? 0.0,
      prevClose: (json['prevClose'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      vwap: (json['vwap'] as num?)?.toDouble() ?? 0.0,
      marketCap: (json['marketCap'] as num?)?.toDouble(),
      peRatio: (json['peRatio'] as num?)?.toDouble(),
      high52: (json['high52'] as num?)?.toDouble(),
      low52: (json['low52'] as num?)?.toDouble(),
      dividendYield: (json['dividendYield'] as num?)?.toDouble(),
      eps: (json['eps'] as num?)?.toDouble(),
      sparkline: rawSparkline,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'price': price,
      'change': change,
      'changeAmount': changeAmount,
      'open': open,
      'high': high,
      'low': low,
      'prevClose': prevClose,
      'volume': volume,
      'vwap': vwap,
      if (marketCap != null) 'marketCap': marketCap,
      if (peRatio != null) 'peRatio': peRatio,
      if (high52 != null) 'high52': high52,
      if (low52 != null) 'low52': low52,
      if (dividendYield != null) 'dividendYield': dividendYield,
      if (eps != null) 'eps': eps,
      if (sparkline.isNotEmpty) 'sparkline': sparkline,
    };
  }
}

class InvestmentsWatchlist {
  final String id;
  final String name;
  final List<InvestmentsWatchlistItem> items;

  const InvestmentsWatchlist({
    required this.id,
    required this.name,
    required this.items,
  });

  factory InvestmentsWatchlist.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return InvestmentsWatchlist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      items: rawItems
          .map(
            (i) => InvestmentsWatchlistItem.fromJson(
              Map<String, dynamic>.from(i as Map),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}

class Investments {
  final String apiKey;
  final String secretKey;
  final List<InvestmentsWatchlist> watchlists;

  const Investments({
    this.apiKey = '',
    this.secretKey = '',
    this.watchlists = const [],
  });

  Investments copyWith({
    String? apiKey,
    String? secretKey,
    List<InvestmentsWatchlist>? watchlists,
  }) {
    return Investments(
      apiKey: apiKey ?? this.apiKey,
      secretKey: secretKey ?? this.secretKey,
      watchlists: watchlists ?? this.watchlists,
    );
  }

  factory Investments.fromJson(Map<String, dynamic> json) {
    final rawWls = json['watchlists'] as List<dynamic>? ?? [];
    return Investments(
      apiKey: json['apiKey'] as String? ?? '',
      secretKey: json['secretKey'] as String? ?? '',
      watchlists: rawWls
          .map(
            (w) => InvestmentsWatchlist.fromJson(
              Map<String, dynamic>.from(w as Map),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey,
      'secretKey': secretKey,
      'watchlists': watchlists.map((w) => w.toJson()).toList(),
    };
  }
}

class InvestmentsBlob extends Blob<Investments> {
  static final InvestmentsBlob _instance = InvestmentsBlob._();
  static InvestmentsBlob get instance => _instance;

  InvestmentsBlob._()
    : super(
        module: 'finance',
        name: 'investments',
        defaultValue: const Investments(),
      );

  static Investments get investments => _instance.value;

  @override
  Investments parse(dynamic json) {
    if (json == null) return const Investments();
    return Investments.fromJson(Map<String, dynamic>.from(json as Map));
  }

  @override
  dynamic serialize(Investments value) => value.toJson();
}
