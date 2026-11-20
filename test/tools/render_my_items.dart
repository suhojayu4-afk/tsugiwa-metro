// MY decorations on every scene, for review: docs/captures/my_items/<scene>_<part>.png
//   flutter test test/tools/render_my_items.dart
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
      final out = Directory('docs/captures/my_items')..createSync(recursive: true);
      final deco = (Platform.environment['DECO'] ?? 'vending,garland').split(',');
      for (final scene in ['standard', 'tokyo', 'shibuya', 'shinjuku', 'asakusa', 'ginza']) {
        for (final part in [DayPart.evening, DayPart.night]) {
          final look = SceneLook(
            images: scene == 'standard'
                ? const {}
                : {for (final p in DayPart.values) p: 'assets/art/scenes/${scene}_${p.name}.webp'},
            overlays: [if (deco.contains('vending')) 'assets/art/decor/vending.webp'],
            effects: {if (deco.contains('garland')) 'garland'},
          );
          final img = await renderSceneImage(look: look, part: part, lineColor: const Color(0xFF80C241), scale: 2);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/${scene}_${part.name}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        }
      }
    });
  });
}
