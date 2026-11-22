// The MY trains with their own shape (tools/make_trains.py) on the platform,
// for review: coming up the line, stopped by day / evening / night, in rain
// and snow, with a head mark. <OUT>/<train>_<case>.png at scale 1.
//   flutter test test/tools/render_trains.dart
// Environment: OUT (folder, default docs/captures/trains), TRAINS (comma list of folders' names).
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
      final env = Platform.environment;
      final out = Directory(env['OUT'] ?? 'docs/captures/trains')..createSync(recursive: true);
      for (final name in (env['TRAINS'] ?? 'oni,yako,tenbo').split(',')) {
        final look = SceneLook(
          trainArt: 'assets/art/trains/$name',
          trainColor: const Color(0xFFF5B92E),
          led: const ['渋谷'],
        );
        Future<void> shot(
          String id,
          DayPart part, {
          double? arrive,
          String? sky,
          WeatherKind weather = WeatherKind.sunny,
          SceneLook? as,
        }) async {
          final img = await renderSceneImage(
            look: as ?? look,
            part: part,
            lineColor: const Color(0xFF80C241),
            scale: 1,
            sky: sky,
            tick: 7,
            arrive: arrive,
            weather: weather,
          );
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/${name}_$id.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        }

        await shot('far', DayPart.day, arrive: 0.45);
        await shot('near', DayPart.day, arrive: 0.7);
        await shot('day', DayPart.day);
        await shot('evening', DayPart.evening);
        await shot('night', DayPart.night);
        await shot('rain', DayPart.day, sky: 'rain', weather: WeatherKind.rain);
        await shot('snow', DayPart.day, sky: 'snow', weather: WeatherKind.snow);
        await shot(
          'mark',
          DayPart.day,
          as: SceneLook(
            trainArt: look.trainArt,
            trainColor: look.trainColor,
            led: look.led,
            headMark: 'assets/art/marks/sakura.png',
          ),
        );
      }
    });
  });
}
