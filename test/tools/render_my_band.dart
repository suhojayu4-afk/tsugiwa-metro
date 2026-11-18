// MY駅 widget info band previews into docs/captures/my_band/ (review).
//   flutter test test/tools/render_my_band.dart
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
      final out = Directory('docs/captures/my_band')..createSync(recursive: true);
      for (final (sky, part, weather, rain) in [
        ('clear', DayPart.day, '晴れ 14.0°C', '降水確率 10%'),
        ('rain', DayPart.evening, '雨 11.5°C', '傘を忘れずに'),
        ('snow', DayPart.night, '雪 0.5°C', '傘を忘れずに'),
      ]) {
        final d = NextWidgetData(
          fromName: '東京',
          toName: '上野',
          fromColor: const Color(0xFF80C241),
          toColor: const Color(0xFF80C241),
          lineColor: const Color(0xFF80C241),
          trip: '',
          last: '終電 00:30',
          alarm: true,
          sky: sky,
          temp: '',
          rain: '',
          weather: weather,
        );
        File('${out.path}/${part.name}_$sky.png').writeAsBytesSync(await renderMyBand(d, '東京 → 上野', rain, part));
      }
    });
  });
}
