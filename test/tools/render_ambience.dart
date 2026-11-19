// The drawn ambience (clouds, birds, stars, windows) on crowd pictures, for
// review: docs/captures/ambience/<picture>_<tick>.png
//   flutter test test/tools/render_ambience.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';

void main() {
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('DotGothic16')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await font.load();
      final out = Directory('docs/captures/ambience')..createSync(recursive: true);
      for (final (scene, part, sky) in [
        ('tokyo', DayPart.day, 'crowded'),
        ('shinjuku', DayPart.evening, 'relaxed'),
        ('ginza', DayPart.night, 'packed'),
      ]) {
        final look = SceneLook(images: {for (final p in DayPart.values) p: 'assets/art/scenes/${scene}_${p.name}.png'});
        for (final tick in [0, 20, 40]) {
          final img = await renderSceneImage(
            look: look,
            part: part,
            lineColor: const Color(0xFF80C241),
            sky: sky,
            scale: 2,
            tick: tick,
          );
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/${scene}_${part.name}_$tick.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        }
      }
    });
  });
}
