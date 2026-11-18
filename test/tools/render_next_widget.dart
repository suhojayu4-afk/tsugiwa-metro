// Renders the つぎの電車 widget into docs/captures/ (review).
//   flutter test test/tools/render_next_widget.dart
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
      const green = Color(0xFF80C241), orange = Color(0xFFF68B1E);
      final out = Directory('docs/captures/next_widget')..createSync(recursive: true);
      for (final sky in ['clear', 'cloudy', 'rainsoon', 'rain', 'snowsoon', 'snow']) {
        final d = NextWidgetData(
          fromName: '東京',
          toName: '上野',
          fromColor: orange,
          toColor: green,
          lineColor: orange,
          trip: '上野まで 約5分',
          last: '終電 00:30',
          alarm: true,
          sky: sky,
          temp: sky.startsWith('snow') ? '1°' : '13°',
          rain: sky == 'clear' ? '10%' : (sky == 'cloudy' ? '30%' : '80%'),
        );
        for (final part in DayPart.values) {
          File('${out.path}/${part.name}_$sky.png').writeAsBytesSync(await renderNextWidget(d, '約15分おき', part));
        }
      }
    });
  });
}
