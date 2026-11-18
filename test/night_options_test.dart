import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/night_options.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';
import 'package:tsugiwa_metro/features/platform/platform_screen.dart' show sceneSky;

import 'trip_logic_test.dart' as t;

void main() {
  final city = t.loadTokyo();
  String id(String ja) => city.stations.values.firstWhere((s) => s.name.ja == ja).id;

  test('taxi fare: Tokyo tariff, 20% more late at night', () {
    expect(taxiFareYen(800), 500); // within the first 1,096 m
    expect(taxiFareYen(1096 + 255), 600);
    expect(taxiFareYen(10000), 500 + 35 * 100); // ceil(8904/255) = 35
    expect(taxiFareYen(10000, lateNight: true), 4800);
    expect(isLateNight(DateTime(2026, 1, 1, 23)), isTrue);
    expect(isLateNight(DateTime(2026, 1, 1, 4, 59)), isTrue);
    expect(isLateNight(DateTime(2026, 1, 1, 5)), isFalse);
  });

  test('distance and walking between stations look real', () {
    final m = roadMetres(city, id('東京'), id('有楽町'));
    expect(m, inInclusiveRange(600, 1400)); // about 0.8 km apart
    expect(walkMinutes(m), lessThan(20));
    final far = roadMetres(city, id('渋谷'), id('浅草'));
    expect(walkMinutes(far), greaterThan(maxWalkMinutes));
    expect(taxiFareYen(far, lateNight: true), inInclusiveRange(4000, 9000));
  });

  test('first train countdown after the last train and before the first', () {
    final tt = city.timetables['tokyo.ginza']!;
    final first = tt.firstTrainMin; // e.g. 05:00
    DateTime at(int h, int m) => DateTime(2026, 11, 19, h, m);
    expect(tt.minutesToFirstTrain(at(12, 0)), isNull); // running
    // 01:00: four hours (or so) to the first train.
    expect(tt.minutesToFirstTrain(at(1, 0)), first - 60);
    // 04:30 (a new service day, not yet running).
    expect(tt.minutesToFirstTrain(at(4, 30)), first - 270);
  });

  test('closed station picture after the last train', () {
    final now = DateTime.utc(2026, 11, 18, 16); // 01:00 in Tokyo
    expect(sceneSky(const WeatherNow(kind: WeatherKind.sunny), now: now, closed: true), 'closed');
    expect(sceneSky(const WeatherNow(kind: WeatherKind.rain), now: now, closed: true), 'closed');
  });
}
