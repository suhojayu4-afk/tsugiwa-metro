import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';

/// The station scenes of Osaka, Fukuoka, Sendai and Sapporo
/// (tools/gen_city_scenes.py, tools/add_city_scenes.py): each belongs to a
/// station that exists in its city, and shows there once owned.
void main() {
  final catalog = MyCatalog.fromJson(
    jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
  );

  // scene → (city, station)
  const places = {
    'osaka_umeda': ('osaka', 'osaka.osaka'),
    'osaka_castle': ('osaka', 'osaka.osakajokoen'),
    'osaka_shinsekai': ('osaka', 'osaka.shin-imamiya'),
    'fukuoka_nakasu': ('fukuoka', 'fukuoka.nakasu-kawabata'),
    'fukuoka_momochi': ('fukuoka', 'fukuoka.nishijin'),
    'sendai_aoba': ('sendai', 'sendai.sendai'),
    'sendai_matsushima': ('sendai', 'sendai.matsushima-kaigan'),
    'sapporo_odori': ('sapporo', 'sapporo.odori'),
    'sapporo_otaru': ('sapporo', 'sapporo.otaru'),
  };
  // The picture each city shows while no station scene of its own is owned.
  const cityDefault = {
    'osaka': 'osaka_umeda',
    'fukuoka': 'fukuoka_nakasu',
    'sendai': 'sendai_aoba',
    'sapporo': 'sapporo_odori',
  };

  Map<DayPart, String> pictures(String scene) => {
    for (final p in DayPart.values) p: 'assets/art/cities/scenes/${scene}_${p.name}.webp',
  };

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every city scene is in the shop with its three pictures, each one moving', () {
    for (final e in places.entries) {
      final item = catalog.item('scene.${e.key}');
      expect(item.slot, MySlot.scene);
      expect(item.station, e.value.$2);
      expect(item.price, greaterThan(0));
      expect(item.images, pictures(e.key));
      for (final path in item.images.values) {
        expect(File(path).existsSync(), isTrue, reason: path);
        expect(File(path.replaceFirst('.webp', '_anim.webp')).existsSync(), isTrue, reason: path);
      }
    }
  });

  test('each scene\'s station is a station of its city', () {
    for (final e in places.entries) {
      final (city, station) = e.value;
      final file = File('assets/cities/$city/stations.json');
      if (!file.existsSync()) continue; // the city's data is not in yet
      final raw = jsonDecode(file.readAsStringSync());
      final list = (raw is List ? raw : (raw as Map<String, dynamic>)['stations'] as List).cast<Map<String, dynamic>>();
      expect(list.map((s) => s['id']), contains(station), reason: e.key);
    }
  });

  test('in its city a scene shows at its station once owned; elsewhere the city\'s own picture stays', () async {
    for (final e in places.entries) {
      final (city, station) = e.value;
      SharedPreferences.setMockInitialValues({});
      final store = MyStore(unlimited: true);
      await store.load(catalog: catalog);
      store.cityId = city;
      store.cityScene = pictures(cityDefault[city]!);
      // Not owned yet: the city's own picture, at that station too.
      expect(store.look.images, store.cityScene, reason: e.key);
      expect(store.lookFor(station).images, store.cityScene, reason: e.key);
      // Owned: that station shows its scene.
      expect(await store.buyWithCoins('scene.${e.key}'), BuyResult.ok);
      expect(store.lookFor(station).images, pictures(e.key), reason: e.key);
      // A Tokyo scene equipped does not replace the city's picture.
      await store.buyWithCoins('scene.tokyo');
      await store.equip('scene.tokyo');
      expect(store.look.images, store.cityScene, reason: e.key);
      // Its own scene equipped does.
      await store.equip('scene.${e.key}');
      expect(store.look.images, pictures(e.key), reason: e.key);
    }
  });
}
