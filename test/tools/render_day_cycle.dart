// One full train cycle (arrive, people board, leave, empty track) on the
// platform at day, evening and night, for review GIFs:
// docs/captures/cycle/<part>/NNN.png
//   flutter test test/tools/render_day_cycle.dart
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
      final scene = Platform.environment['SCENE'] ?? 'tokyo';
      final look = SceneLook(
        images: {for (final p in DayPart.values) p: 'assets/art/scenes/${scene}_${p.name}.png'},
        trainColor: const Color(0xFF2F7DE1),
        trainArt: 'assets/art/shinkansen',
      ).withLed(['流星号 新大阪'], const [ledOrange]).withSign(
        const StationSign(name: '東京', sub: 'TOKYO', band: Color(0xFFF15A22)),
      );
      // Seconds: arrive 0-4.6, board 4.6-8.2, wait to 10, leave 10-15.2, empty to 17.
      const step = 0.2;
      for (final part in DayPart.values) {
        final out = Directory('docs/captures/cycle/${part.name}')..createSync(recursive: true);
        var i = 0;
        for (var t = 0.0; t < 17; t += step, i++) {
          final arrive = (t / 4.6).clamp(0.0, 1.0);
          final board = ((t - 4.6) / 3.6).clamp(0.0, 1.0);
          final leave = ((t - 10) / 5.2).clamp(0.0, 1.0);
          final img = await renderSceneImage(
            look: look,
            part: part,
            lineColor: const Color(0xFFF15A22),
            scale: 2,
            arrive: arrive,
            platform: board,
            depart: leave,
            tick: (t / 0.32).floor(),
          );
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/${i.toString().padLeft(3, '0')}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        }
      }
    });
  });
}
