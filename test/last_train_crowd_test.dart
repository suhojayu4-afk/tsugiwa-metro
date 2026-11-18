import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/congestion/congestion_source.dart';
import 'package:tsugiwa_metro/data/congestion/estimate_congestion.dart';

import 'trip_logic_test.dart' as t;

void main() {
  final city = t.loadTokyo();
  final ginza = city.timetables['tokyo.ginza']!;
  DateTime at(int h, int m, {int day = 18}) => DateTime(2026, 11, day, h, m); // 18th = Wednesday

  test('last train: minutes left, then the day is over', () {
    final last = ginza.lastTrainMin; // minutes after midnight, may be past 24:00
    final lastClock = at(0, 0).add(Duration(minutes: last));
    expect(ginza.minutesToLastTrain(lastClock.subtract(const Duration(minutes: 35))), 35);
    expect(ginza.minutesToLastTrain(at(12, 0))! > 60, isTrue);
    expect(ginza.endedFor(lastClock.add(const Duration(minutes: 5))), isTrue);
    expect(ginza.minutesToLastTrain(lastClock.add(const Duration(minutes: 5))), isNull);
    // Early morning before the first train is not "ended for today".
    expect(ginza.endedFor(at(4, 30)), isFalse);
  });

  test('crowding estimate: rush hour on busy lines, quiet at night', () {
    expect(EstimateCongestionSource.levelAt('tokyo.tozai', at(8, 15)), CongestionLevel.packed);
    expect(EstimateCongestionSource.levelAt('tokyo.ginza', at(8, 15)), CongestionLevel.crowded);
    expect(EstimateCongestionSource.levelAt('tokyo.ginza', at(14, 0)), CongestionLevel.normal);
    expect(EstimateCongestionSource.levelAt('tokyo.ginza', at(23, 30)), CongestionLevel.relaxed);
    expect(EstimateCongestionSource.levelAt('tokyo.skyliner', at(8, 15)), CongestionLevel.normal);
    // Saturday morning rush hour does not exist.
    expect(EstimateCongestionSource.levelAt('tokyo.tozai', at(8, 15, day: 21)).index, lessThan(3));
  });
}
