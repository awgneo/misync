import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:misync/screen.dart';
import '../device/module.dart';
import '../device/proto/constants.dart';
import '../device/proto/xiaomi.pb.dart' as pb;
import '../platform/module.dart';
import 'blobs/weather.dart';
import 'screen.dart';

class WeatherModule extends TabModule {
  @override
  String get name => 'weather';

  @override
  IconData get icon => Icons.wb_sunny;

  @override
  late final Screen screen = WeatherScreen(this);

  static final WeatherModule _module = WeatherModule._();
  static WeatherModule get module => _module;
  WeatherModule._();

  bool _syncingWeather = false;

  @override
  Future<void> start() async {
    DeviceModule.module.register(this);
    DeviceModule.module.connection.listen(_receiveWatchCommand);
  }

  void _receiveWatchCommand(pb.Command cmd) {
    if (cmd.type == CmdType.weather.value) {
      if (cmd.subtype == WeatherSubtype.requestConditionsForLocation.value) {
        _handleWatchWeatherRequest(cmd);
      }
    }
  }

  void _handleWatchWeatherRequest(pb.Command cmd) {
    logger.info('received weather conditions request from watch');
    if (cmd.hasWeather() &&
        cmd.weather.hasLocation() &&
        cmd.weather.location.code.isNotEmpty &&
        cmd.weather.location.name.isNotEmpty) {
      final code = cmd.weather.location.code;
      final name = cmd.weather.location.name;
      _syncWeather(code: code, name: name);
    } else {
      _syncWeather();
    }
  }

  @override
  Future<void> sync() async {
    await _syncWeather();
  }

  Future<void> _syncWeather({String? code, String? name}) async {
    if (!DeviceModule.module.connection.connected.value) return;

    if (!WeatherBlob.enabled) {
      logger.info('skip weather sync (disabled in settings)');
      return;
    }

    if (_syncingWeather) {
      logger.info('weather sync already in progress, skipping concurrent call');
      return;
    }
    _syncingWeather = true;

    try {
      final loc = await PlatformModule.module.invokeMethod(
        'device.getLocation',
      );
      if (loc == null) {
        logger.error('failed to fetch weather: coordinates unavailable');
        return;
      }

      final double lat = (loc['latitude'] as num).toDouble();
      final double lon = (loc['longitude'] as num).toDouble();
      final String currentCity =
          loc['cityName'] as String? ?? 'Current Location';

      final targetName = name ?? currentCity;
      final targetCode = code ?? 'accu:${targetName.hashCode.abs() % 1000000}';

      logger.info('syncing weather for lat=$lat, lon=$lon ($targetName)');

      final results = await Future.wait([
        _fetchWeather(lat, lon),
        _fetchAqi(lat, lon),
      ]);

      final weatherData = results[0] as Map<String, dynamic>?;
      final aqi = results[1] as int? ?? 0;

      if (weatherData == null) {
        logger.error('failed to fetch weather data from API');
        return;
      }

      await _syncWeatherToWatch(weatherData, targetCode, targetName, aqi);
    } catch (e) {
      logger.error('error during weather sync: $e');
    } finally {
      _syncingWeather = false;
    }
  }

  Future<Map<String, dynamic>?> _fetchWeather(double lat, double lon) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,pressure_msl,uv_index'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset'
        '&hourly=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m'
        '&wind_speed_unit=ms&temperature_unit=celsius&timezone=auto',
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        return json.decode(jsonString) as Map<String, dynamic>;
      } else {
        logger.error('weather API returned status code ${response.statusCode}');
      }
    } catch (e) {
      logger.error('weather API request failed: $e');
    } finally {
      client.close();
    }
    return null;
  }

  Future<int?> _fetchAqi(double lat, double lon) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality'
        '?latitude=$lat&longitude=$lon'
        '&current=us_aqi',
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final data = json.decode(jsonString) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>;
        return (current['us_aqi'] as num).round();
      }
    } catch (e) {
      logger.error('failed to fetch AQI from API: $e');
    } finally {
      client.close();
    }
    return null;
  }

  Future<void> _syncWeatherToWatch(
    Map<String, dynamic> data,
    String code,
    String name,
    int aqi,
  ) async {
    final current = data['current'] as Map<String, dynamic>;
    final daily = data['daily'] as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>;

    final double currentTemp = (current['temperature_2m'] as num).toDouble();
    final int currentHumidity = (current['relative_humidity_2m'] as num)
        .round();
    final int currentWmo = (current['weather_code'] as num).round();
    final double windSpeed = (current['wind_speed_10m'] as num).toDouble();
    final int windDir = (current['wind_direction_10m'] as num).round();
    final double pressure = (current['pressure_msl'] as num).toDouble();
    final double uvIndex = (current['uv_index'] as num).toDouble();

    final int xiaomiCondition = _convertWmoToXiaomi(currentWmo);

    final useFahrenheit = WeatherBlob.fahrenheit;
    final symbol = '℃';

    // Set weather preferences
    final prefs = pb.WeatherPrefs()..temperatureScale = useFahrenheit ? 2 : 1;
    await DeviceModule.module.connection.send(
      type: CmdType.weather,
      subtype: WeatherSubtype.setWeatherPrefs,
      builder: (cmd) => cmd.weather = (pb.Weather()..prefs = prefs),
    );

    // Add Location
    final location = pb.WeatherLocation()
      ..code = code
      ..name = name;

    await DeviceModule.module.connection.send(
      type: CmdType.weather,
      subtype: WeatherSubtype.addLocation,
      builder: (cmd) => cmd.weather = (pb.Weather()..location = location),
    );

    // Set Locations Order
    final locations = pb.WeatherLocations()..location.add(location);
    await DeviceModule.module.connection.send(
      type: CmdType.weather,
      subtype: WeatherSubtype.setLocations,
      builder: (cmd) => cmd.weather = (pb.Weather()..locations = locations),
    );

    // Set Current Weather
    final timestamp = _formatDateTimeToXiaomiIso(DateTime.now());
    final meta = pb.WeatherMetadata()
      ..publicationTimestamp = timestamp
      ..cityName = name
      ..locationName = name
      ..locationKey = code
      ..isCurrentLocation = true;

    final pbCurrent = pb.WeatherCurrent()
      ..metadata = meta
      ..weatherCondition = xiaomiCondition
      ..temperature = _buildUnitValue(currentTemp.round(), symbol)
      ..humidity = _buildUnitValue(currentHumidity, '%')
      ..wind = _buildUnitValue(
        _windSpeedToBeaufort(windSpeed),
        windDir.toString(),
      )
      ..uv = _buildUnitValue(uvIndex.round(), '')
      ..aqi = _buildUnitValue(aqi, _getAqiDescription(aqi))
      ..warning = pb.WeatherWarnings()
      ..pressure = pressure * 100.0;

    await DeviceModule.module.connection.send(
      type: CmdType.weather,
      subtype: WeatherSubtype.setCurrentWeather,
      builder: (cmd) => cmd.weather = (pb.Weather()..current = pbCurrent),
    );

    // Set Daily Forecast
    final entries = pb.ForecastEntries();
    final times = daily['time'] as List<dynamic>;
    final maxTemps = daily['temperature_2m_max'] as List<dynamic>;
    final minTemps = daily['temperature_2m_min'] as List<dynamic>;
    final codes = daily['weather_code'] as List<dynamic>;
    final sunrises = daily['sunrise'] as List<dynamic>;
    final sunsets = daily['sunset'] as List<dynamic>;

    final int days = times.length > 5 ? 5 : times.length;
    for (int i = 0; i < days; i++) {
      final wmo = (codes[i] as num).round();
      final cond = _convertWmoToXiaomi(wmo);
      final maxT = (maxTemps[i] as num).round();
      final minT = (minTemps[i] as num).round();
      final sunriseStr = sunrises[i] as String;
      final sunsetStr = sunsets[i] as String;

      final entry = pb.ForecastEntry()
        ..aqi = _buildUnitValue(aqi, _getAqiDescription(aqi))
        ..temperatureRange = (pb.WeatherRange()
          ..from = minT
          ..to = maxT)
        ..conditionRange = (pb.WeatherRange()
          ..from = cond
          ..to = cond)
        ..temperatureSymbol = symbol
        ..sunriseSunset = (pb.WeatherSunriseSunset()
          ..sunrise = _formatDateTimeToXiaomiIso(DateTime.parse(sunriseStr))
          ..sunset = _formatDateTimeToXiaomiIso(DateTime.parse(sunsetStr)));
      entries.entry.add(entry);
    }

    final pbForecast = pb.WeatherForecast()
      ..metadata = meta
      ..entries = entries;

    await DeviceModule.module.connection.send(
      type: CmdType.weather,
      subtype: WeatherSubtype.updateDailyForecast,
      builder: (cmd) => cmd.weather = (pb.Weather()..forecast = pbForecast),
    );

    // Set Hourly Forecast (next 24 hours)
    final hEntries = pb.ForecastEntries();
    final hTemps = hourly['temperature_2m'] as List<dynamic>;
    final hCodes = hourly['weather_code'] as List<dynamic>;
    final hWinds = hourly['wind_speed_10m'] as List<dynamic>;
    final hDirs = hourly['wind_direction_10m'] as List<dynamic>;

    final int hours = hTemps.length > 24 ? 24 : hTemps.length;
    for (int i = 0; i < hours; i++) {
      final hWmo = (hCodes[i] as num).round();
      final hCond = _convertWmoToXiaomi(hWmo);
      final hTemp = (hTemps[i] as num).round();
      final hWind = (hWinds[i] as num).toDouble();
      final hDir = (hDirs[i] as num).round();

      final hEntry = pb.ForecastEntry()
        ..temperatureRange = (pb.WeatherRange()
          ..from = hTemp
          ..to = hTemp)
        ..conditionRange = (pb.WeatherRange()
          ..from = hCond
          ..to = hCond)
        ..wind = _buildUnitValue(_windSpeedToBeaufort(hWind), hDir.toString());
      hEntries.entry.add(hEntry);
    }

    final pbHourlyForecast = pb.WeatherForecast()
      ..metadata = meta
      ..entries = hEntries;

    await DeviceModule.module.connection.send(
      type: CmdType.weather,
      subtype: WeatherSubtype.updateHourlyForecast,
      builder: (cmd) =>
          cmd.weather = (pb.Weather()..forecast = pbHourlyForecast),
    );
  }

  String _getAqiDescription(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  pb.WeatherUnitValue _buildUnitValue(int val, String unit) {
    return pb.WeatherUnitValue()
      ..unit = unit
      ..value = val;
  }

  int _convertWmoToXiaomi(int wmoCode) {
    switch (wmoCode) {
      case 0:
        return 0; // CLEAR_SKY
      case 1:
      case 2:
        return 1; // CLOUDY
      case 3:
        return 2; // OVERCAST
      case 45:
      case 48:
        return 18; // MIST / FOG
      case 51:
      case 53:
      case 55:
        return 7; // LIGHT_RAIN
      case 56:
      case 57:
        return 19; // FREEZING_RAIN
      case 61:
        return 7; // LIGHT_RAIN
      case 63:
        return 8; // MODERATE_RAIN
      case 65:
        return 9; // HEAVY_RAINFALL
      case 66:
      case 67:
        return 19; // FREEZING_RAIN
      case 71:
        return 14; // LIGHT_SNOW
      case 73:
        return 15; // MODERATE_SNOW
      case 75:
        return 16; // HEAVY_SNOW
      case 77:
        return 14; // LIGHT_SNOW
      case 80:
      case 81:
      case 82:
        return 3; // SHOWER
      case 85:
      case 86:
        return 13; // SNOW_SHOWERS
      case 95:
        return 4; // THUNDERSTORM
      case 96:
      case 99:
        return 5; // HAIL
      default:
        return 0; // CLEAR_SKY
    }
  }

  int _windSpeedToBeaufort(double speedMs) {
    if (speedMs < 0.3) return 0;
    if (speedMs < 1.6) return 1;
    if (speedMs < 3.4) return 2;
    if (speedMs < 5.5) return 3;
    if (speedMs < 8.0) return 4;
    if (speedMs < 10.8) return 5;
    if (speedMs < 13.9) return 6;
    if (speedMs < 17.2) return 7;
    if (speedMs < 20.8) return 8;
    if (speedMs < 24.5) return 9;
    if (speedMs < 28.5) return 10;
    if (speedMs < 32.7) return 11;
    return 12;
  }

  String _formatDateTimeToXiaomiIso(DateTime dt) {
    final String datePart = dt.toIso8601String().substring(0, 19);
    final offset = dt.timeZoneOffset;
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final sign = offset.isNegative ? '-' : '+';
    return '$datePart$sign$hours:$minutes';
  }
}
