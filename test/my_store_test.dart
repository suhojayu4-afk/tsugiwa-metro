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
    expect(b.look.overlays, ['assets/art/decor/lanterns.png']);
    expect(b.look.images[DayPart.night], 'assets/art/scenes/tokyo_night.png');
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
