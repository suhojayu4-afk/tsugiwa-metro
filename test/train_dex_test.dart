import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';
import 'package:tsugiwa_metro/data/train_dex.dart';

import 'platform_features_test.dart' show loadTokyo;

void main() {
  final city = loadTokyo();

  test('every line maps to a kind, and every kind but the yellow train has lines', () {
    final byType = linesByType(city);
    expect(byType.values.fold<int>(0, (n, l) => n + l.length), city.lines.length);
    for (final t in trainTypes) {
      if (t.bySighting) {
        expect(byType[t.id], isEmpty, reason: t.id);
      } else {
        expect(byType[t.id], isNotEmpty, reason: t.id);
      }
    }
    expect(trainTypeOfLine(city.line('tokyo.yamanote')).id, 'jr_commuter');
    expect(trainTypeOfLine(city.line('tokyo.ginza')).id, 'subway_classic');
    expect(trainTypeOfLine(city.line('tokyo.hakone_tozan')).id, 'mountain');
    expect(trainTypeOfLine(city.line('tokyo.toden_arakawa')).id, 'tram');
  });

  test('kinds have unique ids, three languages and a picture', () {
    expect(trainTypes.map((t) => t.id).toSet().length, trainTypes.length);
    expect(trainTypes.length, inInclusiveRange(12, 18));
    for (final t in trainTypes) {
      for (final lang in ['ja', 'ko', 'en']) {
        expect(t.name.values[lang], isNotEmpty, reason: '${t.id} $lang');
        expect(t.flavor.values[lang], isNotEmpty, reason: '${t.id} $lang');
      }
      expect(File(t.art).existsSync(), isTrue, reason: t.art);
    }
    expect(trainType(yellowTypeId).rarity, DexRarity.legendary);
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/art/train_dex/'));
  });

  test('riding collects kinds with the first day; the yellow train by sighting', () async {
    SharedPreferences.setMockInitialValues({});
    final store = MyStore();
    await store.load(
      catalog: MyCatalog.fromJson(
        jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
      ),
    );
    expect(collected(store, city, yellow: false), isEmpty);
    final yamanote = city.line('tokyo.yamanote');
    final keihin = city.line('tokyo.keihin_tohoku');
    final ginza = city.line('tokyo.ginza');
    await store.rewardTrip(yamanote.stations.take(3).toList(), now: DateTime(2026, 11, 2, 8), ridden: [yamanote.id]);
    await store.rewardTrip(
      ginza.stations.take(3).toList(),
      now: DateTime(2026, 11, 5, 8),
      ridden: [keihin.id, ginza.id, 'tokyo.no_such_line'],
    );
    final got = collected(store, city, yellow: false);
    expect(got, {'jr_commuter': '2026-11-02', 'subway_classic': '2026-11-05'});
    expect(collected(store, city, yellow: true)[yellowTypeId], '');
  });
}
