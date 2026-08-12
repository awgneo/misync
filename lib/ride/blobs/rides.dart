import '../../storage/blob.dart';

class RideProviderConfig {
  final bool enabled;
  final String apiKey;
  final String secretKey;
  final String oauthToken;

  const RideProviderConfig({
    this.enabled = true,
    this.apiKey = '',
    this.secretKey = '',
    this.oauthToken = '',
  });

  factory RideProviderConfig.fromJson(Map<String, dynamic> json) {
    return RideProviderConfig(
      enabled: json['enabled'] as bool? ?? true,
      apiKey: json['apiKey'] as String? ?? '',
      secretKey: json['secretKey'] as String? ?? '',
      oauthToken: json['oauthToken'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'apiKey': apiKey,
      'secretKey': secretKey,
      'oauthToken': oauthToken,
    };
  }

  RideProviderConfig copyWith({
    bool? enabled,
    String? apiKey,
    String? secretKey,
    String? oauthToken,
  }) {
    return RideProviderConfig(
      enabled: enabled ?? this.enabled,
      apiKey: apiKey ?? this.apiKey,
      secretKey: secretKey ?? this.secretKey,
      oauthToken: oauthToken ?? this.oauthToken,
    );
  }
}

class Ride {
  final bool mockMode;
  final RideProviderConfig uber;
  final RideProviderConfig lyft;
  final RideProviderConfig waymo;

  const Ride({
    this.mockMode = true,
    this.uber = const RideProviderConfig(),
    this.lyft = const RideProviderConfig(),
    this.waymo = const RideProviderConfig(),
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      mockMode: json['mockMode'] as bool? ?? true,
      uber: RideProviderConfig.fromJson(
        Map<String, dynamic>.from(json['uber'] as Map? ?? {}),
      ),
      lyft: RideProviderConfig.fromJson(
        Map<String, dynamic>.from(json['lyft'] as Map? ?? {}),
      ),
      waymo: RideProviderConfig.fromJson(
        Map<String, dynamic>.from(json['waymo'] as Map? ?? {}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mockMode': mockMode,
      'uber': uber.toJson(),
      'lyft': lyft.toJson(),
      'waymo': waymo.toJson(),
    };
  }

  Ride copyWith({
    bool? mockMode,
    RideProviderConfig? uber,
    RideProviderConfig? lyft,
    RideProviderConfig? waymo,
  }) {
    return Ride(
      mockMode: mockMode ?? this.mockMode,
      uber: uber ?? this.uber,
      lyft: lyft ?? this.lyft,
      waymo: waymo ?? this.waymo,
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
