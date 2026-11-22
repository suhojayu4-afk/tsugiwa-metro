// A platform decoration on every scene picture the app can show, for
// review: <OUT>/<scene>_<part>_<sky>.png (scale 1; tools/decor_sheet.py
// tiles and enlarges them).
//   flutter test test/tools/render_vending_check.dart
// Environment: OVERLAY (asset, default the vending machine), OUT (folder),
// SCENES (comma list), EFFECT (drawn effect name).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';

const skies = [
  null,
  'crowded',
  'packed',
  'umbrella',
  'umbrella_few',
  'umbrella_many',
  'rain',
  'rain_few',
  'rain_many',
  'snow',
  'snow_few',
  'snow_many',
  'snowsoon',
  'snowsoon_few',
  'snowsoon_many',
  'winter',
  'winter_few',
  'winter_many',
  'closed',
];

void main() {
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('DotGothic16')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await font.load();
      final env = Platform.environment;
      final out = Directory(env['OUT'] ?? 'docs/captures/my_items/vending_check')..createSync(recursive: true);
      final overlay = env['OVERLAY'] ?? 'assets/art/decor/vending.webp';
      final effect = env['EFFECT'];
      final only = env['SCENES']?.split(',');
      final catalog = (jsonDecode(File('assets/my/catalog.json').readAsStringSync())['items'] as List)
          .cast<Map<String, dynamic>>();
      for (final item in catalog.where((i) => i['slot'] == 'scene')) {
        final id = (item['id'] as String).split('.').last;
        if (only != null && !only.contains(id)) continue;
        final images = {
          for (final e in (item['images'] as Map<String, dynamic>? ?? const {}).entries)
            DayPart.values.byName(e.key): e.value as String,
        };
        final look = SceneLook(images: images, overlays: [if (overlay.isNotEmpty) overlay], effects: {?effect});
        for (final part in DayPart.values) {
          for (final sky in skies) {
            if (sky == 'closed' && part != DayPart.night) continue;
            final base = sky?.split('_').first;
            final img = await renderSceneImage(
              look: look,
              part: part,
              lineColor: const Color(0xFF80C241),
              scale: 1,
              sky: sky,
              weather: switch (base) {
                'rain' => WeatherKind.rain,
                'snow' => WeatherKind.snow,
                'umbrella' || 'snowsoon' => WeatherKind.cloudy,
                _ => WeatherKind.sunny,
              },
            );
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            File('${out.path}/${id}_${part.name}_${sky ?? 'plain'}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
          }
        }
      }
    });
  });
}
