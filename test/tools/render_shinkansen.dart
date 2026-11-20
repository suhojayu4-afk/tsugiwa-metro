// The 流星号 (MY train with its own shape) at the platform, for review:
// docs/captures/shinkansen/<case>.png
//   flutter test test/tools/render_shinkansen.dart
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
      final look =
          SceneLook(
                images: {for (final p in DayPart.values) p: 'assets/art/scenes/tokyo_${p.name}.webp'},
                trainColor: const Color(0xFF2F7DE1),
                trainArt: 'assets/art/shinkansen',
              )
              .withLed(['流星号 新大阪'], const [ledOrange])
              .withSign(const StationSign(name: '東京', sub: 'TOKYO', band: Color(0xFFF15A22)));
      final cases = {
        'day': (DayPart.day, null, WeatherKind.sunny, 1.0),
        'evening': (DayPart.evening, null, WeatherKind.sunny, 1.0),
        'night': (DayPart.night, null, WeatherKind.sunny, 1.0),
        'rain': (DayPart.day, 'rain', WeatherKind.rain, 1.0),
        'snow': (DayPart.evening, 'snow', WeatherKind.snow, 1.0),
        'arriving': (DayPart.evening, null, WeatherKind.sunny, 0.6),
      };
      final out = Directory('docs/captures/shinkansen')..createSync(recursive: true);
      for (final c in cases.entries) {
        final img = await renderSceneImage(
          look: look,
          part: c.value.$1,
          lineColor: const Color(0xFFF15A22),
          weather: c.value.$3,
          sky: c.value.$2,
          scale: 2,
          arrive: c.value.$4,
        );
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/${c.key}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
      // Frames of it pulling in, then the passengers, for a review GIF.
      for (final c in {
        'evening': (DayPart.evening, null, WeatherKind.sunny),
        'night': (DayPart.night, null, WeatherKind.sunny),
      }.entries) {
        final dir = Directory('${out.path}/frames_${c.key}')..createSync(recursive: true);
        const frames = 70;
        for (var i = 0; i <= frames + 60; i++) {
          final img = await renderSceneImage(
            look: look,
            part: c.value.$1,
            lineColor: const Color(0xFFF15A22),
            weather: c.value.$3,
            sky: c.value.$2,
            scale: 2,
            arrive: i <= frames ? i / frames : 1,
            platform: i <= frames ? null : (i - frames) / 60,
          );
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${dir.path}/${i.toString().padLeft(3, '0')}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        }
      }
    });
  });
}
