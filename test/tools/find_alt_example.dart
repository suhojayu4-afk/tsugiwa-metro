import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/last_train_alarm.dart';
import 'package:tsugiwa_metro/data/models/timetable.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';

import '../trip_logic_test.dart' as t;

void main() {
  test('print', () {
    final city = t.loadTokyo();
    String id(String ja) => city.stations.values.firstWhere((s) => s.name.ja == ja).id;
    for (final (a, b) in [('東京', '上野'), ('渋谷', '上野'), ('渋谷', '浅草'), ('新宿', '東京'), ('池袋', '銀座')]) {
      final r = RouteFinder(city).find(id(a), id(b))!;
      final dep = lastDepartureMin(city, r)!;
      final alt = stillPossible(city, id(a), id(b), dep + 1);
      // ignore: avoid_print
      print('$a→$b first ${r.legs.map((l) => l.lineId).join(",")} last ${LineTimetable.clock(dep)} | alt ${alt == null ? "none" : "${alt.route.legs.map((l) => l.lineId).join(",")} by ${LineTimetable.clock(alt.lastDep)}"}');
    }
  });
}
