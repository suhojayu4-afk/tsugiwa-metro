import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/core/pixel/scene_events.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';

void main() {
  const day = SceneEventConditions(part: DayPart.day, month: 6);

  test('events are rare, one at a time, with a rest between them', () {
    final s = SceneEventScheduler(random: math.Random(3));
    final starts = <(double, SceneEventKind)>[];
    double? lastEnd;
    var trainEvery = 0;
    // Two hours on screen, the clock ticking every 320 ms; a train every ~40 s.
    for (var now = 0.0; now < 7200; now += 0.32) {
      final before = s.active;
      final started = s.update(now, day) ?? (++trainEvery % 125 == 0 ? s.trainComing(now, day) : null);
      if (before != null && s.active == null) lastEnd = now;
      if (started != null) {
        expect(before, isNull, reason: 'never two events at once');
        if (lastEnd != null) expect(now - lastEnd, greaterThanOrEqualTo(150 - 0.5));
        starts.add((now, started));
      }
    }
    expect(starts.first.$1, greaterThanOrEqualTo(60));
    // Every few minutes: about 20-45 in two hours.
    expect(starts.length, inInclusiveRange(15, 50));
    // Day: no shooting stars.
    expect(starts.map((e) => e.$2), isNot(contains(SceneEventKind.shootingStar)));
  });

  test('the yellow inspection train is about 1 in 40', () {
    final s = SceneEventScheduler(random: math.Random(11));
    var n = 0;
    for (var i = 0; i < 40000; i++) {
      if (s.pickYellowTrain()) n++;
    }
    expect(n, inInclusiveRange(850, 1150));
  });

  test('shooting stars only on clear nights', () {
    expect(day.weights.containsKey(SceneEventKind.shootingStar), isFalse);
    const evening = SceneEventConditions(part: DayPart.evening);
    expect(evening.weights.containsKey(SceneEventKind.shootingStar), isFalse);
    const night = SceneEventConditions(part: DayPart.night);
    expect(night.weights[SceneEventKind.shootingStar], greaterThan(0));
    const cloudyNight = SceneEventConditions(part: DayPart.night, weather: WeatherKind.cloudy);
    expect(cloudyNight.weights.containsKey(SceneEventKind.shootingStar), isFalse);
    // And at night no cat, pigeons, rainbow or airship.
    expect(night.weights.keys, isNot(contains(SceneEventKind.cat)));
    expect(night.weights.keys, isNot(contains(SceneEventKind.pigeons)));
    expect(night.weights.keys, isNot(contains(SceneEventKind.rainbow)));
  });

  test('red dragonflies only in autumn, by day or at dusk', () {
    for (final m in [9, 10, 11]) {
      expect(SceneEventConditions(part: DayPart.day, month: m).weights[SceneEventKind.dragonflies], greaterThan(0));
    }
    for (final m in [1, 4, 6, 8, 12]) {
      expect(
        SceneEventConditions(part: DayPart.day, month: m).weights.containsKey(SceneEventKind.dragonflies),
        isFalse,
      );
    }
    expect(
      const SceneEventConditions(part: DayPart.night, month: 10).weights.containsKey(SceneEventKind.dragonflies),
      isFalse,
    );
  });

  test('rain keeps animals in; crowds leave no room on the floor', () {
    const rain = SceneEventConditions(part: DayPart.day, weather: WeatherKind.rain);
    expect(rain.weights.keys, isNot(contains(SceneEventKind.cat)));
    expect(rain.weights.keys, isNot(contains(SceneEventKind.pigeons)));
    expect(rain.weights.keys, isNot(contains(SceneEventKind.rainbow)));
    const crowd = SceneEventConditions(part: DayPart.day, sky: 'crowded');
    expect(crowd.weights.keys, isNot(contains(SceneEventKind.cat)));
    expect(crowd.weights.keys, isNot(contains(SceneEventKind.staff)));
    expect(crowd.weights[SceneEventKind.blimp], greaterThan(0));
    // Rainbows are likelier on cloudy days.
    const cloudy = SceneEventConditions(part: DayPart.day, weather: WeatherKind.cloudy);
    expect(cloudy.weights[SceneEventKind.rainbow]!, greaterThan(day.weights[SceneEventKind.rainbow]!));
  });

  test('the attendant waits for a train, then comes out to meet it', () {
    // Only the attendant can happen (night, cloudy: no sky events).
    const c = SceneEventConditions(part: DayPart.night, weather: WeatherKind.cloudy);
    expect(c.weights.keys, [SceneEventKind.staff]);
    final s = SceneEventScheduler(random: math.Random(1), firstGap: (1, 2));
    for (var now = 0.0; now < 5; now += 0.32) {
      expect(s.update(now, c), isNull);
    }
    expect(s.staffWaiting, isTrue);
    expect(s.trainComing(5, c), SceneEventKind.staff);
    expect(s.active, SceneEventKind.staff);
    // Over after its time; then a rest.
    s.update(5 + sceneEventSeconds[SceneEventKind.staff]! + 0.1, c);
    expect(s.active, isNull);
    expect(s.nextAt, greaterThan(150));
  });
}
