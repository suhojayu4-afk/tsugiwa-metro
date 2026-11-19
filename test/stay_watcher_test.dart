import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/features/trip/location_source.dart';
import 'package:tsugiwa_metro/features/trip/stay_watcher.dart';
import 'package:tsugiwa_metro/features/trip/trip_estimator.dart';

import 'trip_logic_test.dart' show loadTokyo;

void main() {
  final city = loadTokyo();
  final shibuya = city.station('tokyo.shibuya');

  GpsFix at(double lat, double lng, DateTime t) => GpsFix(lat: lat, lng: lng, accuracyM: 10, time: t);

  test('5 minutes near a station gives one gold stamp; underground gaps count, leaving resets', () {
    var now = DateTime(2026, 11, 19, 12);
    final got = <String>[];
    final w = StayWatcher(city: city, location: const NoLocationSource(), onStay: got.add, clock: () => now);
    w.seen(at(shibuya.lat, shibuya.lng, now));
    expect(w.station, 'tokyo.shibuya');
    now = now.add(const Duration(minutes: 3));
    w.seen(null); // underground: no fix, still there
    expect(got, isEmpty);
    now = now.add(const Duration(minutes: 2, seconds: 1));
    w.seen(null);
    expect(got, ['tokyo.shibuya']);
    // Not twice for the same visit.
    now = now.add(const Duration(minutes: 6));
    w.seen(at(shibuya.lat, shibuya.lng, now));
    expect(got, ['tokyo.shibuya']);
  });

  test('passing through for less than 5 minutes gives nothing', () {
    var now = DateTime(2026, 11, 19, 12);
    final got = <String>[];
    final w = StayWatcher(city: city, location: const NoLocationSource(), onStay: got.add, clock: () => now);
    w.seen(at(shibuya.lat, shibuya.lng, now));
    now = now.add(const Duration(minutes: 4));
    // Far away (Tokyo Station area is 6 km off).
    final tokyo = city.station('tokyo.tokyo');
    w.seen(at(tokyo.lat, tokyo.lng, now));
    now = now.add(const Duration(minutes: 2));
    w.seen(null);
    expect(got, isEmpty);
    expect(w.station, 'tokyo.tokyo');
  });
}
