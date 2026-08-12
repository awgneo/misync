import '../../storage/blob.dart';

class Destination {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String icon;

  const Destination({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.icon = 'location_on',
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      icon: json['icon'] as String? ?? 'location_on',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'icon': icon,
    };
  }
}

class DestinationsBlob extends Blob<List<Destination>> {
  DestinationsBlob._()
      : super(
          module: 'ride',
          name: 'destinations',
          defaultValue: const [],
        );

  static final DestinationsBlob _blob = DestinationsBlob._();
  static DestinationsBlob get blob => _blob;

  @override
  List<Destination> parse(dynamic json) {
    if (json is List) {
      return json
          .map((e) => Destination.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  @override
  dynamic serialize(List<Destination> value) {
    return value.map((d) => d.toJson()).toList();
  }
}
