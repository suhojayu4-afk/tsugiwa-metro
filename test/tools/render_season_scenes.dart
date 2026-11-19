// Renders every seasonal (期間限定) scene with the train, LED and station
// sign, the way のりば draws them, into docs/captures/season/ (for review).
//   flutter test test/tools/render_season_scenes.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';

void main() {
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('DotGothic16')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await font.load();
      const seasons = {
        'sakura': ('桜坂', 'SAKURAZAKA', Color(0xFFE85298), '各停 上野', WeatherKind.sunny),
        'hanabi': ('両国', 'RYOGOKU', Color(0xFFF39700), '各停 浅草', WeatherKind.sunny),
        'xmas': ('銀座', 'GINZA', Color(0xFFE60012), '各停 池袋', WeatherKind.sunny),
      };
      final out = Directory('docs/captures/season')..createSync(recursive: true);
      for (final s in seasons.entries) {
        final (name, en, color, led, weather) = s.value;
        final look = SceneLook(
          images: {for (final p in DayPart.values) p: 'assets/art/scenes_season/${s.key}_${p.name}.png'},
        ).withLed([led], const [ledOrange]).withSign(StationSign(name: name, sub: en, band: color));
        for (final part in DayPart.values) {
          final img = await renderSceneImage(look: look, part: part, lineColor: color, weather: weather, scale: 2);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/${s.key}_${part.name}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        }
      }
    });
  });
}
