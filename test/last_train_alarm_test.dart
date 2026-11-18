import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/last_train_alarm.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';

import 'trip_logic_test.dart' as t;

void main() {
  final city = t.loadTokyo();

  String id(String ja) => city.stations.values.firstWhere((s) => s.name.ja == ja).id;

  test('one line: the last departure is that line\'s last train', () {
    final route = RouteFinder(city).find(id('渋谷'), id('浅草'))!;
    final lines = {for (final l in route.legs) l.lineId};
    final dep = lastDepartureMin(city, route)!;
    if (lines.length == 1) expect(dep, city.timetables[lines.first]!.lastTrainMin);
    expect(dep, greaterThan(22 * 60));
  });

  test('with a change: earlier, so the second last train is still caught', () {
    final route = RouteFinder(city).find(id('渋谷'), id('東陽町'))!;
    expect(route.legs.length, greaterThan(1));
    final dep = lastDepartureMin(city, route)!;
    final first = city.timetables[route.legs.first.lineId]!.lastTrainMin;
    final second = city.timetables[route.legs[1].lineId]!.lastTrainMin;
    expect(dep, lessThanOrEqualTo(first));
    expect(dep, lessThan(second));
  });

  test('after one last train: another way that still works, or none', () {
    final from = id('渋谷'), to = id('上野');
    final first = RouteFinder(city).find(from, to)!;
    final dep = lastDepartureMin(city, first)!;
    // Before its last departure nothing is missed.
    expect(missedLines(city, first, dep - 10), isEmpty);
    // Just after it, something is missed; any other way found must still work.
    final late = dep + 1;
    expect(missedLines(city, first, late), isNotEmpty);
    final alt = stillPossible(city, from, to, late);
    if (alt != null) {
      expect(missedLines(city, alt.route, late), isEmpty);
      expect(alt.avoid, isNotEmpty);
      expect(alt.lastDep, greaterThanOrEqualTo(late));
    }
    // Far past every last train: no way at all.
    expect(stillPossible(city, from, to, 27 * 60), isNull);
  });
}
