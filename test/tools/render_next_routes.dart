// Same widget, other routes: names, colours and numbers change, the font stays.
//   flutter test test/tools/render_next_routes.dart
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
      final routes = [
        ('渋谷', '浅草', 0xFFF39700, 0xFFF39700, '浅草まで 約32分', '終電 00:01', '約3分おき', 'clear', DayPart.day),
        ('新宿', '池袋', 0xFF80C241, 0xFF80C241, '池袋まで 約9分', '終電 00:48', '約4分おき', 'rain', DayPart.evening),
        ('京成上野', '成田空港', 0xFF005AAA, 0xFF005AAA, '成田空港まで 約44分', '終電 22:58', '約40分おき', 'snow', DayPart.night),
        ('高田馬場', '西船橋', 0xFF009BBF, 0xFF009BBF, '西船橋まで 約38分', '終電 00:12', '約5分おき', 'cloudy', DayPart.day),
      ];
      final out = Directory('docs/captures/next_widget_routes')..createSync(recursive: true);
      var i = 0;
      for (final (from, to, fc, tc, trip, last, led, sky, part) in routes) {
        final d = NextWidgetData(
          fromName: from,
          toName: to,
          fromColor: Color(fc),
          toColor: Color(tc),
          lineColor: Color(fc),
          trip: trip,
          last: last,
          alarm: i.isEven,
          sky: sky,
          temp: sky == 'snow' ? '0°' : '15°',
          rain: sky == 'clear' ? '0%' : '70%',
        );
        File('${out.path}/r${i++}.png').writeAsBytesSync(await renderNextWidget(d, led, part));
      }
    });
  });
}
