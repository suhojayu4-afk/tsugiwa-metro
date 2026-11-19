import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/models/route_map.dart';
import 'package:tsugiwa_metro/features/platform/departure_board.dart';
import 'package:tsugiwa_metro/features/route_map/map_trains.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';

import 'trip_logic_test.dart' show loadTokyo;

void main() {
  Map<String, dynamic> read(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final map = RouteMapData.fromJson(read('assets/cities/tokyo/map.json'), read('assets/cities/tokyo/tips.json'));
  final city = loadTokyo();
  final everything = const Offset(-1e6, -1e6) & const Size(2e6, 2e6);

  test('daytime: trains run on the lines; after the last train, none', () {
    final sim = TrainSim(map, city);
    // 12:00 and 02:30 in Japan.
    final noon = sim.trainsIn(everything, DateTime.utc(2026, 11, 18, 3));
    final night = sim.trainsIn(everything, DateTime.utc(2026, 11, 18, 17, 30));
    expect(noon.length, greaterThan(800));
    expect(night, isEmpty);
    // The Yamanote Line, every 4 minutes round a 60-minute loop, both ways.
    final yamanote = noon.where((t) => t.run.line.id == 'tokyo.yamanote').length;
    expect(yamanote, inInclusiveRange(24, 36));
    // Every train is on its line.
    for (final t in noon.take(300)) {
      final p = t.run.geo.at(t.s);
      expect(t.run.mapLine.bounds.inflate(1).contains(p), isTrue);
    }
  });

  test('a train moves smoothly and waits at stations', () {
    final sim = TrainSim(map, city);
    final t0 = DateTime.utc(2026, 11, 18, 3);
    var stopped = 0, moved = 0;
    final before = {
      for (final t in sim.trainsIn(everything, t0).where((t) => t.run.line.id == 'tokyo.chuo_rapid'))
        t.s.toStringAsFixed(3): t,
    };
    final after = sim.trainsIn(everything, t0.add(const Duration(milliseconds: 500)));
    for (final t in before.values) {
      if (t.stopped) stopped++;
    }
    for (final t in after.where((t) => t.run.line.id == 'tokyo.chuo_rapid')) {
      if (!before.containsKey(t.s.toStringAsFixed(3))) moved++;
    }
    expect(stopped, greaterThan(0));
    expect(moved, greaterThan(0));
  });

  test('a route is drawn along its lines, with start, changes and end', () {
    final route = RouteFinder(city).find('tokyo.shibuya', 'tokyo.asakusa')!;
    final on = RouteOnMap.build(map, city, route)!;
    expect(on.legs.length, route.legs.length);
    expect(on.stops.first.kind, RouteStopKind.start);
    expect(on.stops.first.stationId, 'tokyo.shibuya');
    expect(on.stops.last.kind, RouteStopKind.end);
    expect(on.stops.last.stationId, 'tokyo.asakusa');
    for (final id in ['tokyo.shibuya', 'tokyo.asakusa']) {
      expect(on.bounds.inflate(2).contains(map.stopsOf(id).first.position), isTrue);
    }
  });

  test('every landmark has a note and stations that exist', () {
    final info = read('assets/cities/tokyo/landmarks.json');
    for (final lm in map.landmarks) {
      final key = lm.image.split('/').last.replaceAll('.png', '');
      expect(info[key], isNotNull, reason: key);
      for (final s in (info[key] as Map<String, dynamic>)['stations'] as List) {
        expect(city.stations.containsKey(s), isTrue, reason: '$key: $s');
      }
    }
  });

  test('the departure board shows the trains the map draws: one stands at the station then', () {
    final sim = TrainSim(map, city);
    final noon = DateTime.utc(2026, 11, 18, 3);
    for (final d in nextDepartures(city, 'tokyo.shinjuku', noon, count: 6)) {
      // A moment before it leaves, that line's train is stopped at Shinjuku.
      final at = noon.add(Duration(seconds: d.sec - (12 * 60 - 240) * 60 - 3));
      final stop = map.lineOf(d.line.id)!.stops['tokyo.shinjuku']!.position;
      final there = sim
          .trainsIn(everything, at)
          .where((t) => t.run.line.id == d.line.id && t.stopped && (t.run.geo.at(t.s) - stop).distance < 1);
      expect(there, isNotEmpty, reason: '${d.line.id} ${d.clock}');
    }
  });
}
