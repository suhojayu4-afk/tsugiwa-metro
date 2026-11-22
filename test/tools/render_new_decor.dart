// The MY decorations that are not platform furniture - head marks on each
// train's face, balloons in the sky, the bunting and teru-teru-bozu strings -
// for review: <OUT>/<name>.png at scale 1.
//   flutter test test/tools/render_new_decor.dart
// Environment: OUT (folder, default docs/captures/new_decor).
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
      final out = Directory(Platform.environment['OUT'] ?? 'docs/captures/new_decor')..createSync(recursive: true);
      final catalog = MyCatalog.fromJson(
        jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
      );
      Future<void> shot(String name, SceneLook look, DayPart part, {String? sky, WeatherKind? weather}) async {
        final img = await renderSceneImage(
          look: look,
          part: part,
          lineColor: const Color(0xFF80C241),
          scale: 1,
          sky: sky,
          tick: 7,
          weather: weather ?? WeatherKind.sunny,
        );
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }

      SceneLook look(String scene, {String? train, String? mark, bool sky = false, String? roof}) => SceneLook(
        images: catalog.item('scene.$scene').images,
        trainArt: train,
        headMark: mark == null ? null : catalog.item('mark.$mark').sprite,
        skyArt: sky ? catalog.item('sky.balloon').sprite : null,
        overlays: [?(roof == null ? null : catalog.item('roof.$roof').overlay)],
      );

      // Each head mark on each train's face.
      const trains = {
        'usual': null,
        'shinkansen': 'assets/art/shinkansen',
        'diesel': 'assets/art/tottori/diesel',
        'sl': 'assets/art/tottori/sl',
      };
      for (final t in trains.entries) {
        for (final m in ['sakura', 'moon', 'pear', 'dune']) {
          await shot('mark_${t.key}_$m', look('standard', train: t.value, mark: m), DayPart.day);
        }
      }
      // Everything together on a few scenes, at each hour and in the rain.
      for (final scene in ['standard', 'tokyo', 'asakusa', 'tottori_tottori', 'tottori_koiyamagata']) {
        final train = scene.startsWith('tottori') ? 'assets/art/tottori/diesel' : null;
        for (final roof in ['bunting', 'teru']) {
          final l = look(
            scene,
            train: train,
            mark: scene.startsWith('tottori') ? 'dune' : 'sakura',
            sky: true,
            roof: roof,
          );
          for (final part in DayPart.values) {
            await shot('all_${scene}_${roof}_${part.name}', l, part);
          }
          await shot('all_${scene}_${roof}_rain', l, DayPart.day, sky: 'rain', weather: WeatherKind.rain);
        }
      }
    });
  });
}
