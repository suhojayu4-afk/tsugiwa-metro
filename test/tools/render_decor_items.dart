// Every MY decoration (roof, platform, effect) on a few scenes, day and
// night, for review: <OUT>/<item>__<scene>_<part>[_<sky>].png at scale 1
// (tools/decor_items_sheet.py tiles and enlarges them).
//   flutter test test/tools/render_decor_items.dart
// Environment: OUT (folder), ITEMS (comma list of ids, default all),
// SCENES (default standard,tokyo,asakusa), SKIES (default plain; e.g. plain,rain,crowded).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';

void main() {
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('DotGothic16')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await font.load();
      final env = Platform.environment;
      final out = Directory(env['OUT'] ?? 'docs/captures/my_items/items')..createSync(recursive: true);
      final only = env['ITEMS']?.split(',');
      final scenes = (env['SCENES'] ?? 'standard,tokyo,asakusa').split(',');
      final skies = (env['SKIES'] ?? 'plain').split(',');
      final catalog = MyCatalog.fromJson(
        jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
      );
      for (final item in catalog.items) {
        if (item.overlay == null && item.effect == null) continue;
        if (only != null && !only.contains(item.id)) continue;
        for (final scene in scenes) {
          final look = SceneLook(
            images: catalog.item('scene.$scene').images,
            overlays: [?item.overlay],
            effects: {?item.effect},
          );
          for (final part in [DayPart.day, DayPart.evening, DayPart.night]) {
            for (final sky in skies) {
              final base = sky.split('_').first;
              final img = await renderSceneImage(
                look: look,
                part: part,
                lineColor: const Color(0xFF80C241),
                scale: 1,
                sky: sky == 'plain' ? null : sky,
                tick: 7,
                weather: switch (base) {
                  'rain' => WeatherKind.rain,
                  'snow' => WeatherKind.snow,
                  _ => WeatherKind.sunny,
                },
              );
              final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
              File('${out.path}/${item.id}__${scene}_${part.name}${sky == 'plain' ? '' : '_$sky'}.png')
                  .writeAsBytesSync(bytes!.buffer.asUint8List());
            }
          }
        }
      }
    });
  });
}
