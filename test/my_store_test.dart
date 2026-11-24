import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';

void main() {
  final catalog = MyCatalog.fromJson(
    jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('catalog: every picture exists and every slot has a free start item', () {
    for (final item in catalog.items) {
      for (final path in [...item.images.values, ?item.overlay]) {
        expect(File(path).existsSync(), isTrue, reason: '${item.id}: $path');
      }
    }
    for (final slot in MySlot.values) {
      expect(catalog.inSlot(slot).where((i) => i.free), isNotEmpty, reason: slot.name);
    }
    // Shibuya is the free station; the other four cost coins or money.
    expect(catalog.item('scene.shibuya').free, isTrue);
    for (final s in ['tokyo', 'shinjuku', 'asakusa', 'ginza']) {
      final item = catalog.item('scene.$s');
      expect(item.price, greaterThan(0));
      expect(item.priceYen, isNotNull);
      expect(item.images.keys, containsAll(DayPart.values));
    }
  });

  test('coins from trips: per trip, first visits, first trip of the day', () async {
    final store = MyStore();
    await store.load(catalog: catalog);
    final day = DateTime(2026, 11, 18, 9);
    final r1 = await store.rewardTrip(['a', 'b', 'c'], now: day);
    expect(r1.total, 10 + 3 * 20 + 5);
    final r2 = await store.rewardTrip(['b', 'c', 'd'], now: day);
    expect(r2.total, 10 + 20); // only d is new, not the first trip today
    expect(store.coins, r1.total + r2.total);
  });

  test('coins from riding have a daily limit, smaller when the location did not confirm the ride', () async {
    final rules = catalog.rules;
    final day = DateTime(2026, 11, 24, 9);
    // Confirmed rides: ten a day pay, the eleventh does not; the next day pays again.
    final a = MyStore(unlimited: false);
    await a.load(catalog: catalog);
    for (var i = 0; i < MyStore.coinTripsPerDay; i++) {
      final r = await a.rewardTrip(['s$i', 't$i'], now: day);
      expect(r.trip, rules.perTrip, reason: 'trip $i');
      expect(r.limited, isFalse);
    }
    final over = await a.rewardTrip(['x', 'y'], now: day);
    expect(over.total, 0);
    expect(over.limited, isTrue);
    // ... but its stations are stamped all the same.
    expect(a.stamped('x'), isTrue);
    expect((await a.rewardTrip(['x', 'z'], now: day.add(const Duration(days: 1)))).trip, rules.perTrip);

    // Unconfirmed rides: three a day pay, and first-visit coins for ten stations.
    SharedPreferences.setMockInitialValues({});
    final b = MyStore(unlimited: false);
    await b.load(catalog: catalog);
    final first = await b.rewardTrip([for (var i = 0; i < 14; i++) 'n$i'], now: day, confirmed: false);
    expect(first.newStations, MyStore.unconfirmedNewStationsPerDay * rules.firstVisit);
    expect(first.limited, isTrue);
    expect(first.stamped, hasLength(14));
    expect((await b.rewardTrip(['p', 'q'], now: day, confirmed: false)).newStations, 0);
    expect((await b.rewardTrip(['r', 's'], now: day, confirmed: false)).trip, rules.perTrip);
    expect((await b.rewardTrip(['t', 'u'], now: day, confirmed: false)).total, 0);
    // A confirmed ride the same day still pays in full.
    final real = await b.rewardTrip(['v', 'w'], now: day);
    expect(real.trip, rules.perTrip);
    expect(real.newStations, 2 * rules.firstVisit);
    // The count survives a restart.
    final again = MyStore(unlimited: false);
    await again.load(catalog: catalog);
    expect((await again.rewardTrip(['y1', 'y2'], now: day, confirmed: false)).total, 0);
  });

  test('endless coins are a build switch that is off unless a test build asks for it', () {
    expect(unlimitedCoins, isFalse);
    expect(MyStore().unlimited, isFalse);
  });

  test('test builds: unlimited coins, buying costs nothing', () async {
    final store = MyStore(unlimited: true);
    await store.load(catalog: catalog);
    final item = catalog.items.firstWhere((i) => i.price > 0 && i.unlock == null);
    expect(await store.buyWithCoins(item.id), BuyResult.ok);
    expect(store.owns(item.id), isTrue);
    expect(store.coins, unlimitedCoinsShown);
  });

  test('buying, equipping and the look survive a restart', () async {
    final a = MyStore();
    await a.load(catalog: catalog);
    expect(await a.buyWithCoins('scene.tokyo'), BuyResult.notEnoughCoins);
    await a.addCoins(1200);
    expect(await a.buyWithCoins('scene.tokyo'), BuyResult.ok);
    await a.equip('scene.tokyo');
    await a.addCoins(200);
    expect(await a.buyWithCoins('roof.lanterns'), BuyResult.ok);
    await a.equip('roof.lanterns');
    expect(a.coins, 1200 - 1000 + 200 - 150);

    final b = MyStore();
    await b.load(catalog: catalog);
    expect(b.equipped(MySlot.scene), 'scene.tokyo');
    expect(b.look.overlays, ['assets/art/decor/lanterns.webp']);
    expect(b.look.images[DayPart.night], 'assets/art/scenes/tokyo_night.webp');
    expect(b.coins, a.coins);
  });

  test('stamp book: first visit day is kept, finishing a line gives its reward', () async {
    final store = MyStore()
      ..lines = {
        'tokyo.ginza': ['a', 'b', 'c'],
        'other': ['c', 'd'],
      };
    await store.load(catalog: catalog);
    expect(store.owns('train.lemon'), isFalse);
    expect(await store.buyWithCoins('train.lemon'), BuyResult.notEnoughCoins); // not for sale

    final r1 = await store.rewardTrip(['a', 'b'], now: DateTime(2026, 11, 18, 9));
    expect(r1.stamped, ['a', 'b']);
    expect(r1.completedLines, isEmpty);
    expect(store.lineProgress('tokyo.ginza'), (done: 2, total: 3));

    final r2 = await store.rewardTrip(['b', 'c'], now: DateTime(2026, 11, 19, 9));
    expect(r2.stamped, ['c']);
    expect(r2.completedLines, ['tokyo.ginza']);
    expect(r2.unlocked, ['train.lemon']);
    expect(store.owns('train.lemon'), isTrue);
    expect(store.stamps['a'], '2026-11-18');
    expect(store.stamps['c'], '2026-11-19');

    // Already complete: not given again.
    final r3 = await store.rewardTrip(['a'], now: DateTime(2026, 11, 20, 9));
    expect(r3.completedLines, isEmpty);
  });

  test('station sign is trimmed to its limits and survives a restart', () async {
    final a = MyStore();
    await a.load(catalog: catalog);
    await a.setPlate(const PlateText(name: ' さくらさくら駅前 ', kana: 'さくらさくらざかまえ'));
    final b = MyStore();
    await b.load(catalog: catalog);
    expect(b.plate.name, 'さくらさくら');
    expect(b.plate.kana, 'さくらさくらざか');
    expect(b.plateStyle.colors, PlateStyle.basic.colors);
    await b.addCoins(400);
    await b.buyWithCoins('plate.full');
    await b.equip('plate.full');
    expect(b.plateStyle.colors.length, 4);
  });

  test('scene of the departure station: shown only when owned', () async {
    final store = MyStore();
    await store.load(catalog: catalog);
    expect(store.sceneForStation('tokyo.shinjuku')?.id, 'scene.shinjuku');
    expect(store.sceneForStation('tokyo.kanda'), isNull);
    // Not owned yet: the equipped scene stays.
    expect(store.lookFor('tokyo.shinjuku').key, store.look.key);
    // Shibuya is free, so leaving from Shibuya shows Shibuya.
    expect(store.lookFor('tokyo.shibuya').images, catalog.item('scene.shibuya').images);
    await store.addCoins(1000);
    await store.buyWithCoins('scene.shinjuku');
    expect(store.lookFor('tokyo.shinjuku').images, catalog.item('scene.shinjuku').images);
  });
}
