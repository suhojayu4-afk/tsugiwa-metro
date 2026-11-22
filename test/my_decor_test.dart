import 'dart:convert';
import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';

/// Size of a lossless WebP picture (as tools/art_io.py saves them), read
/// from its header: 14 bits of width − 1, then 14 bits of height − 1.
(int, int) _size(String path) {
  final b = File(path).readAsBytesSync();
  expect(String.fromCharCodes(b.sublist(12, 16)), 'VP8L', reason: path);
  final bits = b[21] | b[22] << 8 | b[23] << 16 | b[24] << 24;
  return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1);
}

void main() {
  final catalog = MyCatalog.fromJson(
    jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final index = DecorIndex.fromJson(
    jsonDecode(File('assets/art/decor/index.json').readAsStringSync()) as Map<String, dynamic>,
  );

  /// Every platform picture the app can show, as the scene loader names it
  /// (an animated picture stands for its still one).
  List<String> platformPictures() {
    final out = <String>[];
    for (final dir in [
      'assets/art',
      'assets/art/scenes',
      'assets/art/scenes_season',
      'assets/art/crowd',
      'assets/art/weather',
      'assets/art/tottori',
      'assets/art/tottori/scenes',
    ]) {
      for (final f in Directory(dir).listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (!name.endsWith('.webp') || name.endsWith('_anim.webp')) continue;
        if (dir == 'assets/art' && !RegExp(r'^scene_(day|evening|night)\.webp$').hasMatch(name)) continue;
        if (dir == 'assets/art/tottori' && !name.startsWith('rural_')) continue;
        out.add('$dir/$name');
      }
    }
    return out;
  }

  test('catalog: ids are unique, every item has its three names, every overlay exists', () {
    final ids = [for (final i in catalog.items) i.id];
    expect(ids.toSet().length, ids.length);
    for (final item in catalog.items) {
      expect(item.id.split('.').first, item.slot.name, reason: item.id);
      for (final lang in ['ja', 'ko', 'en']) {
        expect(item.name.values[lang]?.trim(), isNotEmpty, reason: '${item.id} $lang');
      }
      if (item.overlay != null) {
        expect(File(item.overlay!).existsSync(), isTrue, reason: '${item.id}: ${item.overlay}');
      }
    }
    // Enough to choose from in the decoration slots.
    expect(catalog.inSlot(MySlot.platform).length, greaterThanOrEqualTo(12));
    expect(catalog.inSlot(MySlot.roof).length, greaterThanOrEqualTo(5));
    expect(catalog.inSlot(MySlot.effect).length, greaterThanOrEqualTo(5));
  });

  testWidgets('overlays are whole-scene layers that stay clear of the train, the door and the sign', (tester) async {
    await tester.runAsync(() async {
      for (final item in catalog.items.where((i) => i.overlay != null)) {
        final bytes = File(item.overlay!).readAsBytesSync();
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        expect((image.width, image.height), (SceneArt.width, SceneArt.height), reason: item.id);
        final data = (await image.toByteData())!;
        var left = image.width, top = image.height, bottom = 0;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            if (data.getUint8((y * image.width + x) * 4 + 3) == 0) continue;
            if (x < left) left = x;
            if (y < top) top = y;
            if (y > bottom) bottom = y;
          }
        }
        image.dispose();
        expect(bottom, greaterThan(0), reason: '${item.id} is empty');
        if (item.slot == MySlot.platform) {
          // Right of the queue at the door (feet at 268-281) and of the train,
          // on the floor at the wall (its foot is on rows 117-124 there), and
          // below the hanging station sign.
          expect(left, greaterThanOrEqualTo(290), reason: item.id);
          expect(bottom, inInclusiveRange(118, 132), reason: item.id);
          expect(top, greaterThan(40), reason: item.id);
        } else {
          // Roof things: right of the train's face, above people's heads.
          expect(left, greaterThan(SceneArt.trainRect.right), reason: item.id);
          expect(bottom, lessThan(92), reason: item.id);
        }
      }
    });
  });

  test('head marks and sky things: a small picture each, and a free "none" to take them off', () {
    for (final slot in [MySlot.mark, MySlot.sky]) {
      final items = catalog.inSlot(slot);
      expect(items.where((i) => i.free && i.sprite == null), hasLength(1), reason: slot.name);
      expect(items.where((i) => i.sprite != null), isNotEmpty, reason: slot.name);
      for (final item in items.where((i) => i.sprite != null)) {
        expect(File(item.sprite!).existsSync(), isTrue, reason: '${item.id}: ${item.sprite}');
        expect(item.price, greaterThan(0), reason: item.id);
      }
    }
    // A head mark fits on every train's face, between its sides.
    for (final art in [null, 'assets/art/shinkansen', 'assets/art/tottori/diesel', 'assets/art/tottori/sl']) {
      final at = SceneArt.markOf(art);
      expect(at.dx, inInclusiveRange(20, 55), reason: '$art');
      expect(at.dy, inInclusiveRange(30, 85), reason: '$art');
    }
  });

  testWidgets('a look with a head mark and balloons loads and paints', (tester) async {
    await tester.runAsync(() async {
      final look = SceneLook(headMark: catalog.item('mark.sakura').sprite, skyArt: catalog.item('sky.balloon').sprite);
      expect(look, isNot(const SceneLook()));
      final art = await loadSceneArt(look, DayPart.day);
      expect(art.mark, isNotNull);
      expect(art.skies, hasLength(2));
      final img = await renderSceneImage(look: look, part: DayPart.day, lineColor: const Color(0xFF80C241), scale: 1);
      expect((img.width, img.height), (SceneArt.width, SceneArt.height));
      // Underground there is no sky to float in.
      final under = await loadSceneArt(look.withUnderground(true), DayPart.day);
      expect(under.skies, isEmpty);
      expect(under.mark, isNotNull);
    });
  });

  test('every drawn effect in the catalog is one the scene knows', () {
    final source = File('lib/core/pixel/scene_ambience.dart').readAsStringSync();
    for (final item in catalog.items.where((i) => i.effect != null)) {
      expect(source.contains("effects.contains('${item.effect}')"), isTrue, reason: '${item.id}: ${item.effect}');
    }
  });

  test('seasonal decorations are only sold in their season', () {
    bool sold(String id, int month, int day) => catalog.item(id).onSale(DateTime(2026, month, day));
    final windows = {
      'platform.kadomatsu': ((12, 26), (1, 15), (2, 1)),
      'platform.koinobori': ((4, 20), (5, 10), (6, 1)),
      'platform.tanabata': ((6, 20), (7, 7), (7, 8)),
      'platform.pumpkin': ((10, 1), (10, 31), (11, 1)),
      'platform.xmastree': ((11, 15), (12, 25), (12, 26)),
      'roof.furin': ((6, 15), (8, 31), (9, 1)),
      'roof.fuji': ((4, 15), (5, 15), (5, 16)),
    };
    for (final e in windows.entries) {
      final (first, last, after) = e.value;
      expect(catalog.item(e.key).season, isNotNull, reason: e.key);
      expect(sold(e.key, first.$1, first.$2), isTrue, reason: '${e.key} first day');
      expect(sold(e.key, last.$1, last.$2), isTrue, reason: '${e.key} last day');
      expect(sold(e.key, after.$1, after.$2), isFalse, reason: '${e.key} after');
    }
    // The New Year pines are sold across the year end.
    expect(sold('platform.kadomatsu', 1, 1), isTrue);
    expect(sold('platform.kadomatsu', 12, 25), isFalse);
    // Everyday things are always there.
    for (final id in ['platform.vending', 'platform.bench', 'platform.clock', 'roof.lanterns', 'effect.snow']) {
      expect(catalog.item(id).season, isNull, reason: id);
    }
  });

  test('every platform picture has its people mask or none on purpose, and its platform shift', () async {
    final pictures = platformPictures();
    expect(pictures.length, greaterThan(250));
    final names = {for (final p in pictures) DecorIndex.pictureName(p)};
    // A catalog scene's pictures are among them (also the seasonal ones).
    for (final item in catalog.items.where((i) => i.slot == MySlot.scene)) {
      for (final image in item.images.values) {
        expect(names, contains(DecorIndex.pictureName(image)), reason: item.id);
      }
    }
    for (final p in pictures) {
      final name = DecorIndex.pictureName(p);
      // Measured by the tool: decorations stand on this picture's floor.
      expect(index.shifts, contains(name), reason: 'run tools/make_decor_masks.py: $name');
      expect(index.shifts[name], inInclusiveRange(-2, 12), reason: name);
      final mask = index.maskFor(p);
      final file = File('${DecorIndex.maskFolder}/$name');
      // Listed = the file is there; not listed = nobody stands there, the
      // decoration is drawn as it is (the fallback), and no stale file.
      expect(file.existsSync(), mask != null, reason: name);
    }
    // No mask without its picture (a renamed or removed picture).
    for (final f in Directory(DecorIndex.maskFolder).listSync().whereType<File>()) {
      expect(names, contains(f.uri.pathSegments.last), reason: f.path);
    }
    expect(index.masks.difference(names), isEmpty);
  });

  test('a mask has one frame per frame of its picture', () async {
    for (final scene in ['assets/art/scene_day', 'assets/art/scenes/tokyo_night', 'assets/art/scenes/ginza_evening']) {
      final (_, animHeight) = _size('${scene}_anim.webp');
      final mask = index.maskFor('${scene}_anim.webp');
      expect(mask, isNotNull, reason: scene);
      final (width, height) = _size(mask!);
      expect(width, SceneArt.width);
      expect(height, animHeight, reason: scene);
    }
    final (_, h) = _size(index.maskFor('assets/art/weather/tokyo_day_rain.webp')!);
    expect(h, SceneArt.height);
  });

  test('the platform shift: station pictures as drawn, weather and crowd pictures ten rows lower', () {
    const far = Offset(226, 99);
    expect(index.shiftFor('assets/art/scenes/tokyo_day_anim.webp', far), inInclusiveRange(-1, 1));
    expect(index.shiftFor('assets/art/scene_evening_anim.webp', far), inInclusiveRange(-1, 1));
    expect(index.shiftFor('assets/art/crowd/tokyo_day_packed.webp', far), 10);
    // The snow pictures' rails are hidden (their meeting point in
    // vanishing.json is off): the tool measured the platform itself.
    expect(index.shiftFor('assets/art/weather/standard_day_snow.webp', const Offset(225.7, 89)), 10);
    expect(index.shiftFor('assets/art/scenes_season/sakura_day.webp', far), 10);
    // A picture the tool has not seen: from the rails' meeting point.
    expect(const DecorIndex().shiftFor('assets/art/weather/new_day_rain.webp', far), 10);
    expect(const DecorIndex().shiftFor('assets/art/scenes/new_day.webp', const Offset(226, 89.4)), 0);
    expect(const DecorIndex().maskFor('assets/art/scenes/new_day.webp'), isNull);
  });

  test('lit overlays have their lights picture', () {
    expect(index.lights, isNotEmpty);
    for (final overlay in index.lights) {
      expect(File(overlay).existsSync(), isTrue, reason: overlay);
      expect(File(index.lightsFor(overlay)!).existsSync(), isTrue, reason: overlay);
    }
    expect(index.lightsFor('assets/art/decor/bench.webp'), isNull);
    expect(index.lightsFor('assets/art/decor/vending.webp'), 'assets/art/decor/vending_lit.webp');
  });

  testWidgets('a decorated scene loads its mask, shift and lights and paints', (tester) async {
    await tester.runAsync(() async {
      DecorIndex.resetCache();
      for (final (sky, part, shift) in [
        (null, DayPart.day, 0),
        ('rain', DayPart.night, 10),
        ('packed', DayPart.evening, 10),
      ]) {
        final look = SceneLook(
          images: catalog.item('scene.tokyo').images,
          overlays: const ['assets/art/decor/vending.webp', 'assets/art/decor/lanterns.webp'],
          effects: const {'snow', 'leaves', 'bubbles', 'garland'},
        );
        final art = await loadSceneArt(look, part, sky: sky);
        expect(art.front, isNotNull, reason: '$sky');
        expect((art.decorShift - shift).abs(), lessThanOrEqualTo(1), reason: '$sky');
        expect(art.overlayLights.length, 2);
        expect(art.overlayLights.every((l) => (l != null) == (part != DayPart.day)), isTrue, reason: '$sky');
        final image = await renderSceneImage(
          look: look,
          part: part,
          lineColor: const Color(0xFF80C241),
          sky: sky,
          scale: 1,
        );
        expect((image.width, image.height), (SceneArt.width, SceneArt.height));
      }
      // Nothing equipped: no mask is loaded.
      final plain = await loadSceneArt(const SceneLook(), DayPart.day);
      expect(plain.front, isNull);
      expect(plain.overlayLights, isEmpty);
    });
  });
}
