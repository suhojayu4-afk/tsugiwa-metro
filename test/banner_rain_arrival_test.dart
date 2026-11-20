import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/congestion/congestion_source.dart';
import 'package:tsugiwa_metro/features/platform/platform_screen.dart' show sceneSky;
import 'package:material_ui/material_ui.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';

void main() {
  setUp(() => rootBundle.clear());

  test('weather pictures are found by scene, time of day and sky', () {
    expect(SceneArt.sceneId(const SceneLook()), 'standard');
    final tokyo = SceneLook(images: {for (final p in DayPart.values) p: 'assets/art/scenes/tokyo_${p.name}.webp'});
    expect(SceneArt.sceneId(tokyo), 'tokyo');
    expect(SceneArt.weatherScene('tokyo', DayPart.day, 'rain'), 'assets/art/weather/tokyo_day_rain.webp');
    expect(File('assets/art/weather/tokyo_day_rain.webp').existsSync(), isTrue);
    expect(SceneArt.weatherScene('tokyo', DayPart.night, 'packed'), 'assets/art/crowd/tokyo_night_packed.webp');
    expect(SceneArt.weatherScene('ginza', DayPart.day, 'winter'), 'assets/art/weather/ginza_day_winter.webp');
    for (final f in ['train_front_snow', 'train_front_rain']) {
      expect(File('assets/art/$f.png').existsSync(), isTrue, reason: f);
    }
  });

  testWidgets('rainy banner with umbrellas; a new route makes the train pull in', (tester) async {
    Widget banner(Object? key) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: PixelSceneBanner(
            lineColor: const Color(0xFF80C241),
            weather: WeatherKind.rain,
            sky: 'rain',
            arrivalKey: key,
            aspect: 1.8,
          ),
        ),
      ),
    );
    await tester.pumpWidget(banner(null));
    // Pictures load from assets with real I/O.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpWidget(banner('tokyo>ueno'));
    await tester.pump(const Duration(milliseconds: 500)); // on its way in
    await tester.pump(const Duration(seconds: 3)); // stopped
    expect(tester.takeException(), isNull);
  });

  test('scene picture: weather first, then winter, then the crowd', () {
    final nov = DateTime.utc(2026, 11, 18, 3); // noon in Tokyo
    final jan = DateTime.utc(2027, 1, 20, 3);
    WeatherNow w(WeatherKind k, {int? pop, double? temp}) => WeatherNow(kind: k, rainChance: pop, tempC: temp);
    expect(sceneSky(w(WeatherKind.sunny), now: nov, crowd: CongestionLevel.packed), 'packed');
    expect(sceneSky(w(WeatherKind.sunny), now: nov), isNull);
    expect(sceneSky(w(WeatherKind.rain), now: nov, crowd: CongestionLevel.packed), 'rain_many');
    expect(sceneSky(w(WeatherKind.rain), now: nov, crowd: CongestionLevel.relaxed), 'rain_few');
    expect(sceneSky(w(WeatherKind.cloudy, pop: 60), now: nov, crowd: CongestionLevel.normal), 'umbrella_few');
    expect(sceneSky(w(WeatherKind.cloudy, pop: 60, temp: 2), now: jan), 'snowsoon');
    expect(sceneSky(w(WeatherKind.cloudy, pop: 60, temp: 9), now: jan), 'umbrella');
    expect(sceneSky(w(WeatherKind.sunny), now: jan, crowd: CongestionLevel.crowded), 'winter_many');
  });
}
