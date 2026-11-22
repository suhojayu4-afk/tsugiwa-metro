// Tottori platform GIFs into docs/captures/tottori/gif/: the diesel railcar
// pulling in, doors, and leaving at the country station (or a station scene
// with TOTTORI_SCENE=yonago; the steam locomotive with TOTTORI_TRAIN=sl), by
// day, evening rain, night and snow (TOTTORI_CASES=day,night picks some).
//   flutter test test/tools/render_tottori.dart
//   then: python tools/tottori/make_gifs.py
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/core/pixel/scene_events.dart' show tottoriSlArt;
import 'package:tsugiwa_metro/data/weather/weather_source.dart';

void main() {
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('DotGothic16')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await font.load();
      final scene = Platform.environment['TOTTORI_SCENE'];
      final names = {
        null: ('鳥取', 'TOTTORI'),
        'tottori': ('鳥取', 'TOTTORI'),
        'yonago': ('米子', 'YONAGO'),
        'sakaiminato': ('境港', 'SAKAIMINATO'),
        'koiyamagata': ('恋山形', 'KOI-YAMAGATA'),
      };
      final look =
          SceneLook(
                images: {
                  for (final p in DayPart.values)
                    p: scene == null
                        ? 'assets/art/tottori/rural_${p.name}.webp'
                        : 'assets/art/tottori/scenes/${scene}_${p.name}.webp',
                },
                trainArt: Platform.environment['TOTTORI_TRAIN'] == 'sl' ? tottoriSlArt : tottoriDieselArt,
              )
              .withLed(['普通 米子'], const [ledOrange])
              .withSign(StationSign(name: names[scene]!.$1, sub: names[scene]!.$2, band: const Color(0xFF1E73BE)));
      final cases = Platform.environment['TOTTORI_CASES']?.split(',') ?? ['day', 'evening_rain', 'night', 'snow'];
      final all = {
        'day': (DayPart.day, null, WeatherKind.sunny),
        'evening_rain': (DayPart.evening, 'rain', WeatherKind.rain),
        'night': (DayPart.night, null, WeatherKind.sunny),
        'snow': (DayPart.day, 'snow', WeatherKind.snow),
      };
      const color = Color(0xFF1E73BE);
      for (final key in cases) {
        final c = all[key]!;
        final train = Platform.environment['TOTTORI_TRAIN'] == 'sl' ? '_sl' : '';
        final out = Directory('docs/captures/tottori/gif/${scene ?? 'rural'}${train}_$key')
          ..createSync(recursive: true);
        var n = 0;
        Future<void> frame({double? arrive, double? platform, double? depart, int tick = 0}) async {
          final img = await renderSceneImage(
            look: look,
            part: c.$1,
            lineColor: color,
            weather: c.$3,
            sky: c.$2,
            scale: 2,
            arrive: arrive,
            platform: platform,
            depart: depart,
            tick: tick,
          );
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/${(n++).toString().padLeft(3, '0')}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        }

        for (var i = 0; i <= 40; i++) {
          await frame(arrive: i / 40, tick: i);
        }
        for (var i = 1; i <= 24; i++) {
          await frame(arrive: 1, platform: i / 24, tick: 40 + i);
        }
        for (var i = 1; i <= 30; i++) {
          await frame(arrive: 1, platform: 1, depart: i / 30, tick: 64 + i);
        }
      }
    });
  });
}
