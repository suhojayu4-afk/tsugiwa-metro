import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/weather/weather_source.dart';
import '../../l10n/app_localizations.dart';

/// Today's weather for the city: pixel icon, temperature, humidity, rain chance.
/// Refreshes every 10 minutes while visible.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key, required this.area, this.onWeather});
  final WeatherArea area;

  /// Lets the screen react to the weather (e.g. rainy sky in the scene).
  final ValueChanged<WeatherNow>? onWeather;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  WeatherNow? _now;
  bool _failed = false;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(minutes: 10), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final w = await Services.weather.fetch(widget.area);
      if (!mounted) return;
      setState(() {
        _now = w;
        _failed = false;
      });
      widget.onWeather?.call(w);
    } catch (_) {
      if (mounted) setState(() => _failed = _now == null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final w = _now;
    if (w == null) {
      return PixelBox(child: PixelText(_failed ? t.weatherError : t.loading, size: 15, color: PixelColors.muted));
    }
    final (icon, label) = switch (w.kind) {
      WeatherKind.sunny => ('sunny', t.weatherSunny),
      WeatherKind.cloudy => ('cloudy', t.weatherCloudy),
      WeatherKind.rain => ('rain', t.weatherRain),
      WeatherKind.snow => ('snow', t.weatherSnow),
      WeatherKind.unknown => ('cloudy', t.weatherUnknown),
    };
    return PixelBox(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WeatherIcon(name: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PixelText(label, size: 16, color: PixelColors.muted),
                    PixelText(w.tempC == null ? '―' : '${w.tempC!.toStringAsFixed(1)}℃', size: 34, bold: true),
                  ],
                ),
              ),
              _Mini(label: t.humidityLabel, value: w.humidity == null ? '―' : '${w.humidity}%'),
              const SizedBox(width: 14),
              _Mini(label: t.rainChanceLabel, value: w.rainChance == null ? '―' : '${w.rainChance}%'),
            ],
          ),
          if (w.kind == WeatherKind.rain || w.kind == WeatherKind.snow || w.wetLater) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFE6F1FA), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.umbrella_rounded, size: 16, color: Color(0xFF2F6FA8)),
                  const SizedBox(width: 6),
                  PixelText(t.umbrellaReminder, size: 13, color: const Color(0xFF2F6FA8)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          PixelText(t.weatherCredit, size: 11, color: PixelColors.muted),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      PixelText(label, size: 16, color: PixelColors.muted),
      PixelText(value, size: 24, bold: true),
    ],
  );
}

/// 32×32 pixel-art weather icon (assets/art/weather_*.png), scaled so every
/// art pixel is a whole number of device pixels.
class WeatherIcon extends StatelessWidget {
  const WeatherIcon({super.key, required this.name, this.approxSize = 56});
  final String name;
  final double approxSize;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final perArt = (approxSize / 32 * dpr).round().clamp(1, 32);
    final size = 32 * perArt / dpr;
    return Image.asset(
      'assets/art/weather_$name.png',
      width: size,
      height: size,
      // Without an explicit fit, small images are never scaled up.
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
    );
  }
}
