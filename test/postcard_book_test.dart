import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';
import 'package:tsugiwa_metro/features/album/postcard_book.dart';
import 'package:tsugiwa_metro/features/album/postcard_view.dart';

import 'platform_features_test.dart' show loadTokyo;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<MyStore> myStore() async {
    final my = MyStore();
    await my.load(
      catalog: MyCatalog.fromJson(
        jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
      ),
    );
    return my;
  }

  test('one postcard per station per day; a stay makes it gold', () async {
    SharedPreferences.setMockInitialValues({});
    final my = await myStore();
    final book = PostcardBook();
    await book.load(my);
    final morning = DateTime(2026, 11, 20, 9);
    await my.rewardTrip(['a', 'b'], now: morning);
    final c = await book.add(my: my, station: 'b', from: 'a', weather: WeatherKind.rain, now: morning);
    expect(c.first, isTrue);
    expect(c.weather, WeatherKind.rain);
    await book.add(my: my, station: 'b', gold: true, now: morning.add(const Duration(hours: 3)));
    expect(book.cards, hasLength(1));
    expect(book.cards.single.gold, isTrue);
    expect(book.cards.single.from, 'a');
    await book.add(my: my, station: 'b', now: morning.add(const Duration(days: 1)));
    expect(book.cards, hasLength(2));
    expect(book.cards.first.first, isFalse, reason: 'second visit');
  });

  test('saved and loaded; memo; on this day', () async {
    SharedPreferences.setMockInitialValues({});
    final my = await myStore();
    final book = PostcardBook();
    await book.load(my);
    final c = await book.add(my: my, station: 'x', now: DateTime(2025, 11, 23, 15));
    await book.add(my: my, station: 'y', now: DateTime(2026, 11, 23, 10));
    await book.setMemo(c.id, '  おだんご  ');
    final again = PostcardBook();
    await again.load(my);
    expect(again.cards.map((c) => c.station), ['y', 'x']);
    expect(again.cards.last.memo, 'おだんご');
    expect(again.onThisDay(DateTime(2026, 11, 23)).map((c) => c.station), ['x']);
  });

  test('past trips become postcards the first time', () async {
    SharedPreferences.setMockInitialValues({});
    final my = await myStore();
    await my.rewardTrip(['a', 'b', 'c'], now: DateTime(2026, 10, 1, 8), ridden: ['l1']);
    await my.rewardTrip(['c', 'a'], now: DateTime(2026, 10, 2, 18));
    final book = PostcardBook();
    await book.load(my);
    expect(book.cards.map((c) => c.station), ['a', 'c']);
    expect(book.cards.last.from, 'a');
    expect(book.cards.last.line, 'l1');
    expect(book.cards.last.first, isTrue);
  });

  test('messages in each language, stable per card', () {
    final city = loadTokyo();
    final id = city.stations.keys.first;
    final c = Postcard(id: 42, station: id, day: '2026-11-20', minute: 20 * 60, weather: WeatherKind.rain, first: true);
    for (final lang in ['ja', 'ko', 'en']) {
      final m = postcardMessage(city, c, lang);
      expect(m.split('\n'), hasLength(3));
      expect(m, postcardMessage(city, c, lang));
      expect(m, contains(city.station(id).name.of(lang)));
    }
  });
}
