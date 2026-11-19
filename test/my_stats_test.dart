import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_stats.dart';
import 'package:tsugiwa_metro/data/my_store.dart';

import 'platform_features_test.dart' show loadTokyo;

void main() {
  final city = loadTokyo();
  final catalog = MyCatalog.fromJson(
    jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<MyStore> fresh() async {
    final s = MyStore()..lines = {for (final l in city.lines) l.id: l.stations};
    await s.load(catalog: catalog);
    return s;
  }

  test('trips are logged for the ride report and survive a restart', () async {
    final a = await fresh();
    await a.rewardTrip(
      ['tokyo.tokyo', 'tokyo.kanda', 'tokyo.akihabara'],
      now: DateTime(2026, 11, 19, 7, 40),
      ridden: ['tokyo.yamanote'],
    );
    final b = MyStore();
    await b.load(catalog: catalog);
    expect(b.trips.single.day, '2026-11-19');
    expect(b.trips.single.minute, 7 * 60 + 40);
    expect(b.trips.single.lines, ['tokyo.yamanote']);
  });

  test('invite code: one per phone, a friend\'s gives coins once, never your own', () async {
    final s = await fresh();
    expect(MyStore.validInvite(s.inviteCode), isTrue);
    final again = MyStore();
    await again.load(catalog: catalog);
    expect(again.inviteCode, s.inviteCode);
    expect(await s.useInvite(s.inviteCode), InviteResult.own);
    expect(await s.useInvite('abc'), InviteResult.invalid);
    final before = s.coins;
    final friend = s.inviteCode == 'ACDEFG' ? 'GFEDCA' : 'ACDEFG';
    expect(await s.useInvite(friend.toLowerCase()), InviteResult.ok);
    expect(s.coins, before + MyStore.inviteCoins);
    expect(await s.useInvite(friend), InviteResult.used);
  });

  test('stats: level and title grow with stamps; this month counts km and the busiest line', () async {
    final s = await fresh();
    var st = MyStats.of(city, s, now: DateTime(2026, 11, 19));
    expect(st.level, 1);
    expect(st.title.ja, 'はじめての乗客');
    final yamanote = city.line('tokyo.yamanote');
    await s.rewardTrip(yamanote.stations.take(8).toList(), now: DateTime(2026, 11, 3, 0, 40), ridden: [yamanote.id]);
    await s.rewardTrip(yamanote.stations.take(3).toList(), now: DateTime(2026, 11, 4, 5, 10), ridden: [yamanote.id]);
    await s.rewardTrip(['tokyo.shibuya'], now: DateTime(2026, 10, 30, 9), ridden: [yamanote.id]);
    st = MyStats.of(city, s, now: DateTime(2026, 11, 19));
    expect(st.level, greaterThan(1));
    expect(st.title.ja, 'となり駅の旅人');
    expect(st.month.trips, 2); // October's trip is not this month
    expect(st.month.km, greaterThan(5));
    expect(st.month.topLine, yamanote.id);
    // 5:10 is the earliest, 0:40 (after midnight) the latest.
    expect(MonthRides.clock(st.month.earliest!), '05:10');
    expect(MonthRides.clock(st.month.latest!), '00:40');
    await s.rewardTrip(yamanote.stations, now: DateTime(2026, 11, 20), ridden: [yamanote.id]);
    st = MyStats.of(city, s, now: DateTime(2026, 11, 20));
    expect(st.title.ja, '${yamanote.name.ja}マスター');
    expect(st.lineProgress.first.lineId, yamanote.id);
  });
}
