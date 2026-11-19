import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/core/pixel/scene_events.dart' show yellowTrainSightings;
import 'package:tsugiwa_metro/data/achievements.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';

import 'platform_features_test.dart' show loadTokyo;

void main() {
  final city = loadTokyo();
  final catalog = MyCatalog.fromJson(
    jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every badge has its picture and a unique id', () {
    expect({for (final b in badges) b.id}.length, badges.length);
    for (final b in badges) {
      expect(File(b.icon).existsSync(), isTrue, reason: b.id);
    }
  });

  test('badges come from the rides, stamps and lines', () async {
    final s = MyStore()..lines = {for (final l in city.lines) l.id: l.stations};
    await s.load(catalog: catalog);
    expect(earnedBadges(city, s), isEmpty);
    final y = city.line('tokyo.yamanote');
    // A week of rides, Mon 2026-11-16 … Sun 11-22: one before 5:30, one after midnight.
    for (var d = 16; d <= 22; d++) {
      await s.rewardTrip(
        y.stations.skip(d).take(4).toList(),
        now: DateTime(2026, 11, d, d == 16 ? 5 : (d == 17 ? 0 : 8), 20),
        ridden: d == 18 ? ['tokyo.yamanote', 'tokyo.ginza', 'tokyo.marunouchi'] : [y.id],
      );
    }
    final got = earnedBadges(city, s);
    expect(got, containsAll(['first', 'early', 'lastTrain', 'transfer', 'streak7', 'stamps10']));
    expect(got, isNot(contains('rides10')));
    expect(got, isNot(contains('weekend'))); // only 2 weekend rides
    await s.rewardTrip(y.stations, now: DateTime(2026, 11, 23, 9), ridden: [y.id]);
    expect(earnedBadges(city, s), containsAll(['line1', 'yamanote', 'long']));
  });

  test('seeing the yellow train once gives its badge, kept after a restart', () async {
    final s = MyStore()..lines = {for (final l in city.lines) l.id: l.stations};
    await s.load(catalog: catalog);
    await RareSightings.attach();
    expect(earnedBadges(city, s), isNot(contains('yellow')));
    yellowTrainSightings.value++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(earnedBadges(city, s), contains('yellow'));
    expect((await SharedPreferences.getInstance()).getBool('badges.yellowTrain'), isTrue);
  });
}
