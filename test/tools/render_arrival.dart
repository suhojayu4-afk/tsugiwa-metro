// Frames of the train pulling in (headlights, rocking, wind, LED) into
// docs/captures/arrival/<case>/NNN.png, for review GIFs.
//   flutter test test/tools/render_arrival.dart
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
      final look = SceneLook(images: {for (final p in DayPart.values) p: 'assets/art/scenes/tokyo_${p.name}.png'})
          .withLed(['快速 高尾'], const [ledOrange])
          .withSign(const StationSign(name: '東京', sub: 'TOKYO', band: Color(0xFFF15A22)));
      final cases = {
        'day': (DayPart.day, null, WeatherKind.sunny),
        'evening_rain': (DayPart.evening, 'rain', WeatherKind.rain),
        'night': (DayPart.night, null, WeatherKind.sunny),
      };
      const frames = 70;
      for (final c in cases.entries) {
        final out = Directory('docs/captures/arrival/${c.key}')..createSync(recursive: true);
        for (var i = 0; i <= frames; i++) {
          final img = await renderSceneImage(
            look: look,
            part: c.value.$1,
            lineColor: const Color(0xFFF15A22),
            weather: c.value.$3,
            sky: c.value.$2,
            scale: 2,
            arrive: i / frames,
          );
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/${i.toString().padLeft(3, '0')}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        }
      }
    });
  });
}
