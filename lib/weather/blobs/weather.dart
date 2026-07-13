import '../../storage/blob.dart';

class Weather {
  final bool enabled;
  final bool fahrenheit;

  const Weather({required this.enabled, required this.fahrenheit});

  Weather copyWith({bool? enabled, bool? fahrenheit}) {
    return Weather(
      enabled: enabled ?? this.enabled,
      fahrenheit: fahrenheit ?? this.fahrenheit,
    );
  }
}

class WeatherBlob extends Blob<Weather> {
  static final WeatherBlob _instance = WeatherBlob._();
  static WeatherBlob get instance => _instance;

  WeatherBlob._()
    : super(
        module: 'weather',
        name: 'weather',
        defaultValue: const Weather(enabled: true, fahrenheit: true),
      );

  static Weather get config => _instance.value;
  static bool get enabled => _instance.value.enabled;
  static bool get fahrenheit => _instance.value.fahrenheit;

  @override
  Weather parse(dynamic json) {
    if (json == null) {
      return const Weather(enabled: true, fahrenheit: true);
    }
    if (json is bool) {
      return Weather(enabled: json, fahrenheit: true);
    }
    final map = json as Map<String, dynamic>;
    return Weather(
      enabled: map['enabled'] as bool? ?? true,
      fahrenheit:
          map['useFahrenheit'] as bool? ?? map['fahrenheit'] as bool? ?? true,
    );
  }

  @override
  dynamic serialize(Weather value) {
    return {'enabled': value.enabled, 'fahrenheit': value.fahrenheit};
  }
}
