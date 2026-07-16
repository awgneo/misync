import '../../storage/blob.dart';

class InvestmentsWatchlistItem {
  final String symbol;
  final double price;
  final double change;

  const InvestmentsWatchlistItem({
    required this.symbol,
    required this.price,
    required this.change,
  });

  factory InvestmentsWatchlistItem.fromJson(Map<String, dynamic> json) {
    return InvestmentsWatchlistItem(
      symbol: json['symbol'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      change: (json['change'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'symbol': symbol, 'price': price, 'change': change};
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
