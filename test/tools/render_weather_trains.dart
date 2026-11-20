// Renders every weather picture with the train, LED and station sign, the
// way のりば draws them, into docs/captures/weather_trains/ (for review).
//   flutter test test/tools/render_weather_trains.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';

void main() {
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('DotGothic16')
        ..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await font.load();
      const scenes = {
        'standard': ('桜坂', 'SAKURAZAKA', Color(0xFF80C241), '各停 上野'),
        'tokyo': ('東京', 'TOKYO', Color(0xFFF15A22), '快速 高尾'),
        'shinjuku': ('新宿', 'SHINJUKU', Color(0xFF80C241), '山手線 内回り'),
        'shibuya': ('渋谷', 'SHIBUYA', Color(0xFFF39700), '各停 浅草'),
        'asakusa': ('浅草', 'ASAKUSA', Color(0xFFE85298), '各停 西馬込'),
        'ginza': ('銀座', 'GINZA', Color(0xFFE60012), '各停 池袋'),
      };
      const skies = {
        'base': (null, WeatherKind.sunny),
        'umbrella': ('umbrella', WeatherKind.cloudy),
        'rain': ('rain', WeatherKind.rain),
        'snow': ('snow', WeatherKind.snow),
        'winter': ('winter', WeatherKind.sunny),
        'snowsoon': ('snowsoon', WeatherKind.cloudy),
        'umbrella_m': ('umbrella_many', WeatherKind.cloudy),
        'umbrella_f': ('umbrella_few', WeatherKind.cloudy),
        'rain_m': ('rain_many', WeatherKind.rain),
        'rain_f': ('rain_few', WeatherKind.rain),
        'snow_m': ('snow_many', WeatherKind.snow),
        'snow_f': ('snow_few', WeatherKind.snow),
        'winter_m': ('winter_many', WeatherKind.sunny),
        'winter_f': ('winter_few', WeatherKind.sunny),
        'snowsoon_m': ('snowsoon_many', WeatherKind.cloudy),
        'snowsoon_f': ('snowsoon_few', WeatherKind.cloudy),
        'closed': ('closed', WeatherKind.sunny),
        'relaxed': ('relaxed', WeatherKind.sunny),
        'normal': ('normal', WeatherKind.sunny),
        'crowded': ('crowded', WeatherKind.sunny),
        'packed': ('packed', WeatherKind.sunny),
      };
      final out = Directory('docs/captures/weather_trains')..createSync(recursive: true);
      for (final sc in scenes.entries) {
        final (name, en, color, led) = sc.value;
        var look = sc.key == 'standard'
            ? const SceneLook()
            : SceneLook(images: {for (final p in DayPart.values) p: 'assets/art/scenes/${sc.key}_${p.name}.webp'});
        look = look.withLed([led], const [ledOrange]).withSign(StationSign(name: name, sub: en, band: color));
        for (final part in DayPart.values) {
          for (final sky in skies.entries) {
            final img = await renderSceneImage(
              look: look,
              part: part,
              lineColor: color,
              weather: sky.value.$2,
              sky: sky.value.$1,
              scale: 2,
            );
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            File('${out.path}/${sc.key}_${part.name}_${sky.key}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
          }
        }
      }
    });
  });
}
