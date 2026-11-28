import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/features/trip/location_source.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';
import 'package:tsugiwa_metro/features/trip/trip_controller.dart';
import 'package:tsugiwa_metro/features/trip/trip_estimator.dart';
import 'package:tsugiwa_metro/features/trip/trip_plan.dart';
import 'package:tsugiwa_metro/platform/live_status_bridge.dart';

import 'tottori_city_test.dart' show loadTottori;

/// Fixes the test hands in.
class FakeLocation implements LocationSource {
  final fixes = StreamController<GpsFix>.broadcast();
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<GpsFix?> currentFix() async => null;
  @override
  Stream<GpsFix> watch({GpsPower power = GpsPower.precise, bool background = false}) => fixes.stream;
  @override
  Stream<double> heading() => const Stream.empty();
}

void main() {
  final city = loadTottori();
  final jst = DateTime(2026, 11, 24, 10, 5); // a Tuesday
  final route = RouteFinder(city).find('tottori.tottori', 'tottori.yonago', at: jst)!;
  final plan = TripPlan.build(city, route, jst);

  GpsFix at(double lat, double lng, [double acc = 20]) => GpsFix(lat: lat, lng: lng, accuracyM: acc, time: jst);

  test('between two stations, GPS puts the trip that far along the run', () {
    final a = plan.stops[2], b = plan.stops[3];
    final sa = city.station(a.stationId), sb = city.station(b.stationId);
    final mid = at((sa.lat + sb.lat) / 2, (sa.lng + sb.lng) / 2);
    final e = gpsElapsed(plan, city, mid, 0)!;
    expect(e, greaterThan(a.departSec));
    expect(e, lessThan(b.arriveSec));
    final s = estimateTrip(plan, e, jst);
    expect(s.currentIndex, 2);
    expect(s.atStation, isFalse);
    expect(s.nextIndex, 3);
    expect(s.remainingStops, plan.lastIndex - 2);
  });

  test('far from the route, GPS is not used', () {
    expect(gpsElapsed(plan, city, at(35.0, 134.0), 0), isNull);
  });

  testWidgets('started away from the station: distance, walk, and the train waits', (tester) async {
    final loc = FakeLocation();
    var now = DateTime(2026, 11, 24, 1, 5); // 10:05 JST
    final c = TripController(
      city: city,
      plan: plan,
      lang: 'ko',
      location: loc,
      bridge: const NoopLiveStatusBridge(),
      clock: () => now,
    );
    c.start();
    await tester.pump();
    final origin = city.station(plan.stops.first.stationId);
    // About 1 km south of the station.
    loc.fixes.add(at(origin.lat - 0.009, origin.lng));
    await tester.pump();
    expect(c.approaching, isTrue);
    expect(c.toStationM, closeTo(1000, 50));
    expect(c.walkMin, greaterThanOrEqualTo(15));

    // Long past the departure, still walking: the trip waits at the first station.
    for (var i = 0; i < 5; i++) {
      now = now.add(Duration(seconds: plan.stops.first.departSec ~/ 2 + 120));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(c.snapshot.currentIndex, 0);
    expect(c.snapshot.atStation, isTrue);

    // At the station: the walk is over.
    loc.fixes.add(at(origin.lat, origin.lng));
    await tester.pump();
    expect(c.approaching, isFalse);
    c.cancel();
    c.dispose();
  });

  testWidgets('started on board: no walk card, the next stop follows GPS', (tester) async {
    final loc = FakeLocation();
    final now = DateTime(2026, 11, 24, 1, 5);
    final c = TripController(
      city: city,
      plan: plan,
      lang: 'ko',
      location: loc,
      bridge: const NoopLiveStatusBridge(),
      clock: () => now,
    );
    c.start();
    await tester.pump();
    final a = city.station(plan.stops[3].stationId), b = city.station(plan.stops[4].stationId);
    loc.fixes.add(at(a.lat * 0.3 + b.lat * 0.7, a.lng * 0.3 + b.lng * 0.7));
    await tester.pump();
    expect(c.approaching, isFalse);
    expect(c.snapshot.currentIndex, 3);
    expect(c.snapshot.nextIndex, 4);
    expect(c.toNextM, isNotNull);
    c.cancel();
    c.dispose();
  });
}
