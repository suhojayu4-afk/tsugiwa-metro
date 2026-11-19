import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';
import 'package:tsugiwa_metro/data/sticker_marks.dart';

void main() {
  final catalog = MyCatalog.fromJson(
    jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sticker packs: the basic four are free, a bought pack adds its stickers', () async {
    for (final pack in catalog.inSlot(MySlot.sticker)) {
      for (final s in pack.stickers) {
        expect(File('assets/art/stickers/$s.png').existsSync(), isTrue, reason: '${pack.id}: $s');
      }
    }
    final store = MyStore(unlimited: true);
    await store.load(catalog: catalog);
    expect(ownedStickers(store), ['sakura', 'heart', 'star', 'sparkle']);
    expect(await store.buyWithCoins('sticker.cat'), BuyResult.ok);
    expect(ownedStickers(store), containsAll(['cat', 'hanko', 'ticket', 'train']));
  });

  test('stickers stuck on stations survive a restart and come off again', () async {
    final a = StickerMarks();
    await a.load();
    await a.put('tokyo.shinjuku', 'cat');
    await a.put('tokyo.tokyo', 'heart');
    final b = StickerMarks();
    await b.load();
    expect(b.at('tokyo.shinjuku'), 'cat');
    await b.put('tokyo.tokyo', null);
    final c = StickerMarks();
    await c.load();
    expect(c.marks, {'tokyo.shinjuku': 'cat'});
  });
}
