// One whole station cycle at 8 frames a second, to check that nobody pops
// in or out: the train in (passengers queueing), boarding, the train
// leaving, the next passengers walking in, the next train, boarding.
// Frames go to docs/captures/<dir>/<case>/NNN.png; then
//   python tools/passenger_flow_gif.py
// makes the GIFs and contact sheets and removes the frames.
//   flutter test test/tools/render_passenger_flow.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';

/// The scene's animation values at [t] seconds into the cycle.
({double arrive, double platform, double depart, double gather}) cycleAt(double t) {
  double span(double from, double seconds) => ((t - from) / seconds).clamp(0.0, 1.0);
  // 0 s: the screen opens, the train is in. 2 s: boarding (3.6 s). 7 s: it
  // leaves (5.2 s). 12.2 s: the next passengers walk in (7.5 s). 21 s: the
  // next train (4.6 s), then boarding again.
  if (t < 21) {
    return (
      arrive: 1,
      platform: t < 12.2 ? span(2, 3.6) : 0,
      depart: span(7, 5.2),
      gather: t < 12.2 ? 1 : span(12.2, 7.5),
    );
  }
  return (arrive: span(21, 4.6), platform: span(25.6, 3.6), depart: 0, gather: 1);
}

void main() {
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('DotGothic16')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await font.load();
      SceneLook dressed(SceneLook l, String name, String sub, int band) =>
          l.withLed(['荻窪'], const [ledOrange]).withSign(StationSign(name: name, sub: sub, band: Color(band)));
      final tokyo = SceneLook(images: {for (final p in DayPart.values) p: 'assets/art/scenes/tokyo_${p.name}.webp'});
      // A platform full of people: the next ones come into view in the queue.
      final shinjuku = SceneLook(
        images: {for (final p in DayPart.values) p: 'assets/art/scenes/shinjuku_${p.name}.webp'},
      );
      final only = Platform.environment['FLOW_ONLY'];
      final cases = <String, (String, SceneLook, DayPart, String?, WeatherKind, int)>{
        'standard_day': (
          'passenger_flow',
          dressed(const SceneLook(), '中野', 'NAKANO', 0xFFF15A22),
          DayPart.day,
          null,
          WeatherKind.sunny,
          2,
        ),
        'tokyo_evening': (
          'passenger_flow',
          dressed(tokyo, '東京', 'TOKYO', 0xFFF15A22),
          DayPart.evening,
          null,
          WeatherKind.sunny,
          2,
        ),
        'standard_night_winter': (
          'passenger_flow',
          dressed(const SceneLook(), '中野', 'NAKANO', 0xFF009BBF),
          DayPart.night,
          'winter',
          WeatherKind.sunny,
          2,
        ),
        'shinjuku_day': (
          'passenger_flow',
          dressed(shinjuku, '新宿', 'SHINJUKU', 0xFFF15A22),
          DayPart.day,
          null,
          WeatherKind.sunny,
          2,
        ),
        'underground': (
          'underground',
          dressed(const SceneLook(underground: true), '東京', 'TOKYO', 0xFFF62E36),
          DayPart.day,
          null,
          WeatherKind.sunny,
          3,
        ),
        // Rain outside at night, a busy hour: none of it shows down here.
        'underground_vending': (
          'underground',
          dressed(
            const SceneLook(underground: true, overlays: ['assets/art/decor/vending.webp']),
            '東京',
            'TOKYO',
            0xFFF62E36,
          ),
          DayPart.night,
          'rain_many',
          WeatherKind.rain,
          3,
        ),
      };
      const fps = 8, seconds = 29.5;
      for (final c in cases.entries) {
        if (only != null && !only.split(',').contains(c.key)) continue;
        final (dir, look, part, sky, weather, scale) = c.value;
        final out = Directory('docs/captures/$dir/${c.key}')..createSync(recursive: true);
        for (var i = 0; i < seconds * fps; i++) {
          final t = i / fps;
          final v = cycleAt(t);
          final img = await renderSceneImage(
            look: look,
            part: part,
            lineColor: const Color(0xFFF62E36),
            weather: weather,
            sky: sky,
            scale: scale,
            arrive: v.arrive,
            platform: v.platform,
            depart: v.depart,
            gather: v.gather,
            tick: (t / 0.32).floor(),
          );
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/${i.toString().padLeft(3, '0')}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
          img.dispose();
        }
      }
    });
  }, timeout: const Timeout(Duration(minutes: 20)));
}
