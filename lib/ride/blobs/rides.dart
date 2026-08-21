import '../../storage/blob.dart';

class RideProviderConfig {
  final bool enabled;
  final String clientId;
  final String clientSecret;
  final String serverToken;
  final String accessToken;
  final String refreshToken;

  const RideProviderConfig({
    this.enabled = true,
    this.clientId = '',
    this.clientSecret = '',
    this.serverToken = '',
    this.accessToken = '',
    this.refreshToken = '',
  });

  bool get hasCredentials {
    return serverToken.isNotEmpty ||
        accessToken.isNotEmpty ||
        (clientId.isNotEmpty && clientSecret.isNotEmpty);
  }

  factory RideProviderConfig.fromJson(Map<String, dynamic> json) {
    return RideProviderConfig(
      enabled: json['enabled'] as bool? ?? true,
      clientId: json['clientId'] as String? ?? '',
      clientSecret: json['clientSecret'] as String? ?? '',
      serverToken: json['serverToken'] as String? ?? '',
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'clientId': clientId,
      'clientSecret': clientSecret,
      'serverToken': serverToken,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }

  RideProviderConfig copyWith({
    bool? enabled,
    String? clientId,
    String? clientSecret,
    String? serverToken,
    String? accessToken,
    String? refreshToken,
  }) {
    return RideProviderConfig(
      enabled: enabled ?? this.enabled,
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      serverToken: serverToken ?? this.serverToken,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }
}

class Ride {
  final RideProviderConfig uber;
  final RideProviderConfig lyft;

  const Ride({
    this.uber = const RideProviderConfig(),
    this.lyft = const RideProviderConfig(),
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      uber: RideProviderConfig.fromJson(
        Map<String, dynamic>.from(json['uber'] as Map? ?? {}),
      ),
      lyft: RideProviderConfig.fromJson(
        Map<String, dynamic>.from(json['lyft'] as Map? ?? {}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uber': uber.toJson(),
      'lyft': lyft.toJson(),
    };
  }

  Ride copyWith({
    RideProviderConfig? uber,
    RideProviderConfig? lyft,
  }) {
    return Ride(
      uber: uber ?? this.uber,
      lyft: lyft ?? this.lyft,
    );
  }
}

class RidesBlob extends Blob<Ride> {
  RidesBlob._()
      : super(
          module: 'ride',
          name: 'rides',
          defaultValue: const Ride(),
        );

  static final RidesBlob _blob = RidesBlob._();
  static RidesBlob get blob => _blob;
  static Ride get rides => _blob.value;

  static bool isProviderEnabled(String provider) {
    if (provider == 'uber') return rides.uber.enabled && rides.uber.hasCredentials;
    if (provider == 'lyft') return rides.lyft.enabled && rides.lyft.hasCredentials;
    return false;
  }

  @override
  Ride parse(dynamic json) {
    if (json is Map) {
      return Ride.fromJson(Map<String, dynamic>.from(json));
    }
    return const Ride();
  }

  @override
  dynamic serialize(Ride value) {
    return value.toJson();
  }
}
