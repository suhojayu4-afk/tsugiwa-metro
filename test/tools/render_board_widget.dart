// 地下鉄案内 widget previews into docs/captures/board_widget/ (review).
//   flutter test test/tools/render_board_widget.dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/platform/next_widget_art.dart';

void main() {
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('DotGothic16')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await font.load();
      final out = Directory('docs/captures/board_widget')..createSync(recursive: true);
      for (final (sky, part) in [('clear', DayPart.day), ('rain', DayPart.evening), ('clear', DayPart.night), ('snow', DayPart.night)]) {
        final d = NextWidgetData(
          fromName: '東京',
          toName: '上野',
          fromColor: const Color(0xFFF68B1E),
          toColor: const Color(0xFF80C241),
          lineColor: const Color(0xFFF68B1E),
          trip: '東京 → 上野  約5分 · 1駅',
          last: '終電 00:30',
          alarm: true,
          sky: sky,
          temp: '14°',
          rain: '10%',
          lineLabel: '宇都宮線 白岡方面',
          first: '始発 04:50',
        );
        File('${out.path}/${part.name}_$sky.png').writeAsBytesSync(await renderBoardWidget(d, part));
      }
    });
  });
}
