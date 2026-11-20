// The train leaving the platform (towards us, then the empty track), for
// review: docs/captures/departure/NNN.png
//   flutter test test/tools/render_departure.dart
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
      final out = Directory('docs/captures/departure')..createSync(recursive: true);
      final look = SceneLook(
        images: {for (final p in DayPart.values) p: 'assets/art/scenes/tokyo_${p.name}.webp'},
      ).withLed(['快速 高尾'], const [ledOrange]);
      for (var i = 0; i <= 24; i++) {
        final img = await renderSceneImage(
          look: look,
          part: DayPart.evening,
          lineColor: const Color(0xFFF15A22),
          scale: 2,
          arrive: 1,
          platform: 1,
          depart: i / 24,
        );
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/${i.toString().padLeft(3, '0')}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    });
  });
}
