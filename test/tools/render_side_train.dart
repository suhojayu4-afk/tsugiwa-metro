// Frames of the side-view train on the trip screen into
// docs/captures/side_train/<case>/NNN.png, for review GIFs.
//   flutter test test/tools/render_side_train.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/features/trip/widgets/side_train_view.dart';

Future<ui.Image> _load(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  return (await codec.getNextFrame()).image;
}

void main() {
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      final art = {for (final p in DayPart.values) p: await SideTrainArt.loadWith(p, _load)};
      const scale = 2.0;
      const dt = 0.05;
      const size = ui.Size(SideTrainPainter.gridW * scale, SideTrainPainter.gridH * scale);

      // Each case: day part, line colour, frames, and (moving, underground) per frame.
      final cases = <String, (DayPart, Color, int, (bool, bool) Function(int))>{
        'day': (DayPart.day, const Color(0xFF80C241), 40, (_) => (true, false)),
        'evening': (DayPart.evening, const Color(0xFFF15A22), 40, (_) => (true, false)),
        'night': (DayPart.night, const Color(0xFF00A7DB), 40, (_) => (true, false)),
        'underground': (DayPart.day, const Color(0xFFF39700), 40, (_) => (true, true)),
        'portal': (DayPart.day, const Color(0xFF009BBF), 40, (i) => (true, i >= 12)),
        'stop_day': (DayPart.day, const Color(0xFF80C241), 110, (i) => (i < 6 || i >= 80, false)),
        'stop_evening': (DayPart.evening, const Color(0xFF9B7CB6), 110, (i) => (i < 6 || i >= 80, false)),
        'stop_underground': (DayPart.day, const Color(0xFFE60012), 110, (i) => (i < 6 || i >= 80, true)),
      };
      for (final c in cases.entries) {
        final (part, color, frames, state) = c.value;
        final out = Directory('docs/captures/side_train/${c.key}')..createSync(recursive: true);
        for (final f in out.listSync()) {
          f.deleteSync();
        }
        final (m0, u0) = state(0);
        final sim = SideTrainSim(moving: m0, underground: u0);
        for (var i = 0; i < frames; i++) {
          final (moving, underground) = state(i);
          sim.step(dt, moving: moving, underground: underground);
          final rec = ui.PictureRecorder();
          SideTrainPainter(sim: sim, part: part, lineColor: color, art: art[part]!).paint(ui.Canvas(rec), size);
          final img = await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/${i.toString().padLeft(3, '0')}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        }
      }
    });
  });
}
