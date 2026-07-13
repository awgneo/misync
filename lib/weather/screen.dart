import 'package:flutter/material.dart';
import '../screen.dart';
import '../widgets/panel.dart';
import '../widgets/items.dart';
import '../widgets/item.dart';
import 'module.dart';
import 'blobs/weather.dart';

class WeatherScreen extends Screen<WeatherModule> {
  const WeatherScreen(super.module, {super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ScreenState<WeatherScreen> {
  @override
  Widget buildScreen(BuildContext context, bool connected) {
    return ListenableBuilder(
      listenable: WeatherBlob.instance,
      builder: (context, _) {
        final weather = WeatherBlob.config;
        return MiPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MiItems(
                children: [
                  MiItem(
                    title: 'Sync Weather',
                    subtitle: 'Fetch location and sync weather to the watch',
                    primaryIcon: const Icon(
                      Icons.cloud_sync,
                      color: Color(0xFF00E5FF),
                    ),
                    enabled: weather.enabled,
                    toggled: (value) async {
                      await WeatherBlob.instance.update(
                        weather.copyWith(enabled: value),
                      );
                      if (value) {
                        widget.module.sync();
                      }
                    },
                  ),
                  MiItem(
                    title: 'Use Fahrenheit',
                    subtitle:
                        'Display temperatures in Fahrenheit instead of Celsius',
                    primaryIcon: const Icon(
                      Icons.thermostat,
                      color: Color(0xFFFFB300),
                    ),
                    enabled: weather.fahrenheit,
                    toggled: (value) async {
                      await WeatherBlob.instance.update(
                        weather.copyWith(fahrenheit: value),
                      );
                      widget.module.sync();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
