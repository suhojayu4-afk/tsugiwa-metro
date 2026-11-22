import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/features/my_room/my_room_screen.dart';

void main() {
  final catalog = MyCatalog.fromJson(
    jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final seasonal = [
    for (final i in catalog.items)
      // (Decorations have seasons too: test/my_decor_test.dart.)
      if (i.season != null && i.slot == MySlot.scene) i,
  ];

  test('seasonal scenes: three of them, with every picture and its vanishing point', () {
    expect(seasonal.map((i) => i.id), containsAll(['scene.sakura', 'scene.hanabi', 'scene.xmas']));
    final vanishing = jsonDecode(File('assets/art/vanishing.json').readAsStringSync()) as Map<String, dynamic>;
    for (final item in seasonal) {
      expect(item.slot, MySlot.scene);
      expect(item.price, inInclusiveRange(800, 1200), reason: item.id);
      expect(item.images.keys, containsAll(DayPart.values), reason: item.id);
      for (final path in item.images.values) {
        expect(path, startsWith('assets/art/scenes_season/'));
        expect(File(path).existsSync(), isTrue, reason: '${item.id}: $path');
        expect(vanishing.containsKey(path.split('/').last), isTrue, reason: 'vanishing point of $path');
      }
    }
  });

  test('onSale: inside, outside and at the edges of the window', () {
    final sakura = catalog.item('scene.sakura');
    expect(sakura.onSale(DateTime(2027, 3, 14)), isFalse);
    expect(sakura.onSale(DateTime(2027, 3, 15)), isTrue);
    expect(sakura.onSale(DateTime(2027, 4, 10, 23, 59)), isTrue);
    expect(sakura.onSale(DateTime(2027, 4, 30, 23, 59)), isTrue);
    expect(sakura.onSale(DateTime(2027, 5, 1)), isFalse);

    final hanabi = catalog.item('scene.hanabi');
    expect(hanabi.onSale(DateTime(2027, 7, 14)), isFalse);
    expect(hanabi.onSale(DateTime(2027, 7, 15)), isTrue);
    expect(hanabi.onSale(DateTime(2027, 8, 31)), isTrue);
    expect(hanabi.onSale(DateTime(2027, 9, 1)), isFalse);

    final xmas = catalog.item('scene.xmas');
    expect(xmas.onSale(DateTime(2026, 11, 30)), isFalse);
    expect(xmas.onSale(DateTime(2026, 12, 1)), isTrue);
    expect(xmas.onSale(DateTime(2026, 12, 25)), isTrue);
    expect(xmas.onSale(DateTime(2026, 12, 26)), isFalse);

    // Items without a season are always on sale.
    expect(catalog.item('scene.tokyo').onSale(DateTime(2027, 6, 1)), isTrue);
  });

  test('a window can wrap the year end', () {
    final item = MyItem.fromJson({
      'id': 'x',
      'slot': 'scene',
      'name': {'ja': 'x'},
      'season': {'from': '12-20', 'to': '01-10'},
    });
    expect(item.onSale(DateTime(2026, 12, 19)), isFalse);
    expect(item.onSale(DateTime(2026, 12, 20)), isTrue);
    expect(item.onSale(DateTime(2026, 12, 31)), isTrue);
    expect(item.onSale(DateTime(2027, 1, 1)), isTrue);
    expect(item.onSale(DateTime(2027, 1, 10)), isTrue);
    expect(item.onSale(DateTime(2027, 1, 11)), isFalse);
  });

  test('shop: off-season items are hidden unless owned', () {
    final scenes = catalog.inSlot(MySlot.scene);
    final summer = DateTime(2027, 8, 1);
    final ids = shopItems(scenes, (_) => false, summer).map((i) => i.id);
    expect(ids, contains('scene.hanabi'));
    expect(ids, isNot(contains('scene.sakura')));
    expect(ids, isNot(contains('scene.xmas')));
    expect(ids, containsAll(['scene.shibuya', 'scene.tokyo']));

    final owned = shopItems(scenes, (id) => id == 'scene.xmas', summer).map((i) => i.id);
    expect(owned, contains('scene.xmas'));
    expect(owned, isNot(contains('scene.sakura')));
  });
}
