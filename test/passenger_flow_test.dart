import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/core/pixel/scene_events.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';

/// The scene at 1:1 as RGBA bytes.
Future<Uint8List> _render(
  SceneLook look, {
  DayPart part = DayPart.day,
  String? sky,
  WeatherKind weather = WeatherKind.sunny,
  double? arrive,
  double? platform,
  double? depart,
  double? gather,
}) async {
  final image = await renderSceneImage(
    look: look,
    part: part,
    lineColor: const Color(0xFFF62E36),
    weather: weather,
    sky: sky,
    scale: 1,
    arrive: arrive,
    platform: platform,
    depart: depart,
    gather: gather,
  );
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  image.dispose();
  return bytes;
}

/// Pixels that differ between [a] and [b] inside [r] (scene pixels).
int _diff(Uint8List a, Uint8List b, Rect r) {
  var n = 0;
  for (var y = r.top.toInt(); y < r.bottom; y++) {
    for (var x = r.left.toInt(); x < r.right; x++) {
      final i = (y * SceneArt.width + x) * 4;
      if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) n++;
    }
  }
  return n;
}

void main() {
  // Where the two stand in the queue (right of the stopped train) and the
  // whole platform they walk in over.
  const queue = Rect.fromLTRB(260, 80, 296, 136);
  const platform = Rect.fromLTRB(256, 60, 384, 192);

  testWidgets('the queue is there from the first frame and nobody pops in or out', (tester) async {
    await tester.runAsync(() async {
      const look = SceneLook();
      final empty = await _render(look, arrive: 1, platform: 1, depart: 1, gather: 0);
      final waiting = await _render(look, arrive: 1, platform: 0, depart: 1, gather: 1);
      expect(_diff(empty, waiting, queue), greaterThan(150), reason: 'two people stand in the queue');

      // The moment a train appears far down the line: they already stand there.
      final trainFar = await _render(look, arrive: 0, platform: 0, depart: 0, gather: 1);
      expect(_diff(trainFar, waiting, queue), 0);
      // The frame the train stops (boarding has not started yet): still there.
      final stopped = await _render(look, arrive: 1, platform: 0, depart: 0, gather: 1);
      expect(_diff(stopped, waiting, queue), 0);

      // Walking in: nothing at the start, then a little more each frame.
      final start = await _render(look, arrive: 1, platform: 0, depart: 1, gather: 0);
      expect(_diff(start, empty, platform), 0);
      var before = start, most = 0;
      const steps = 60; // 8 frames a second over the 7.5 s
      for (var i = 1; i <= steps; i++) {
        final now = await _render(look, arrive: 1, platform: 0, depart: 1, gather: i / steps);
        final moved = _diff(before, now, platform);
        if (moved > most) most = moved;
        before = now;
      }
      expect(_diff(before, waiting, platform), 0, reason: 'they end in the queue');
      // A walker beside the camera is about 30 x 85 pixels: one step moves
      // part of it, never a whole new person at once in the queue.
      expect(most, lessThan(2600));
      final nearlyThere = await _render(look, arrive: 1, platform: 0, depart: 1, gather: 0.99);
      expect(_diff(nearlyThere, waiting, queue), lessThan(400));

      // A plain still (home screen widget, share card) stays as it was drawn.
      final still = await _render(look);
      final stillBoarded = await _render(look, arrive: 1, platform: 1);
      expect(_diff(still, stillBoarded, platform), 0);
    });
  });

  testWidgets('the subway platform: no sky, no weather, an owned scene wins', (tester) async {
    await tester.runAsync(() async {
      DecorIndex.resetCache();
      expect(File(SceneArt.underground).existsSync(), isTrue);
      const look = SceneLook(underground: true, overlays: ['assets/art/decor/vending.webp']);
      expect(look.showsUnderground, isTrue);
      expect(look.withLed(['a'], const [ledOrange]).withSign(null).underground, isTrue);
      expect(look == look.withUnderground(false), isFalse);

      final art = await loadSceneArt(look, DayPart.night, sky: 'rain_many');
      expect(art.underground, isTrue);
      expect(art.part, DayPart.day);
      expect((art.sky, art.weathered, art.trainWeather, art.ambience), (null, false, null, null));
      // Lines up with the standard pictures drawn from the same original.
      final usual = await SceneArt.vanishingFor('assets/art/weather/standard_day_winter.webp');
      expect((art.vanishing - usual).distance, lessThan(1.5));
      expect(art.decorShift, 10);
      expect(art.overlayLights.single, isNotNull, reason: 'lamps are lit down here');
      // The queue is always drawn, in the clothes of the weather outside.
      expect(art.walkers.length, 2);
      expect(walkersFor('packed', underground: true), ['suit_man', 'office_woman']);
      expect(walkersFor('winter_many', underground: true), ['coat_man', 'coat_woman']);
      expect(walkersFor('closed', underground: true), isEmpty);
      expect(walkersFor('packed'), isEmpty);

      // The same picture at any hour and in any weather.
      final noon = await _render(look, arrive: 1, platform: 0);
      final rainyNight = await _render(look, part: DayPart.night, weather: WeatherKind.rain, arrive: 1, platform: 0);
      expect(_diff(noon, rainyNight, const Rect.fromLTRB(0, 0, 384, 192)), 0);

      // After the last train the display says so and nobody waits.
      final closed = await loadSceneArt(look, DayPart.night, sky: 'closed');
      expect((closed.underground, closed.closed, closed.walkers.length), (true, true, 0));

      // A station scene the user owns stays.
      final tokyo = SceneLook(
        images: {for (final p in DayPart.values) p: 'assets/art/scenes/tokyo_${p.name}.webp'},
        underground: true,
      );
      expect(tokyo.showsUnderground, isFalse);
      expect((await loadSceneArt(tokyo, DayPart.day)).underground, isFalse);
    });
  });

  test('underground: only the attendant comes out', () {
    for (final part in DayPart.values) {
      for (final weather in [WeatherKind.sunny, WeatherKind.cloudy]) {
        final c = SceneEventConditions(part: part, weather: weather, month: 10, sky: 'crowded', underground: true);
        expect(c.weights.keys, [SceneEventKind.staff]);
      }
    }
    expect(const SceneEventConditions(part: DayPart.night, sky: 'closed', underground: true).weights, isEmpty);
  });

  testWidgets('the banner shows the subway platform and fades a new picture in', (tester) async {
    Widget banner(SceneLook look, Object? key) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: PixelSceneBanner(
            lineColor: const Color(0xFFF62E36),
            weather: WeatherKind.rain,
            look: look,
            arrivalKey: key,
          ),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await tester.pumpWidget(banner(const SceneLook(), null));
    await settle();
    // Rain falls on the open-air platform …
    expect(find.descendant(of: find.byType(PixelSceneBanner), matching: find.byType(CustomPaint)), findsNWidgets(2));
    await tester.pumpWidget(banner(const SceneLook(underground: true), 'tokyo>ginza'));
    await settle();
    // … not underground (one picture, no rain layer).
    expect(find.descendant(of: find.byType(PixelSceneBanner), matching: find.byType(CustomPaint)), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // the train is in
    await tester.pump(const Duration(seconds: 4)); // everyone on board
    expect(tester.takeException(), isNull);
  });
}
