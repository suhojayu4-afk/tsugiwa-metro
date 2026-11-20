import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/features/my_room/eki_in_book.dart';

import 'platform_features_test.dart' show loadTokyo;

void main() {
  test('kanji numbers and 和暦 dates', () {
    expect(kanjiNumber(8), '八');
    expect(kanjiNumber(10), '十');
    expect(kanjiNumber(21), '二十一');
    expect(kanjiNumber(30), '三十');
    expect(kanjiNumber(2026), '二千二十六');
    expect(ekiInWareki(DateTime(2026, 11, 21)), '令和八年十一月二十一日');
    expect(ekiInWareki(DateTime(2019, 5, 1)), '令和元年五月一日');
    expect(ekiInWareki(DateTime(2018, 1, 10)), '平成三十年一月十日');
  });

  test('vertical columns', () {
    expect(ekiInColumns('渋谷').columns, ['渋谷']);
    expect(ekiInColumns('高輪ゲートウェイ').columns, ['高輪ゲートウェイ']);
    expect(ekiInColumns('とうきょうスカイツリー').columns, ['とうきょうス', 'カイツリー']);
    expect(ekiInColumns('元町・中華街').columns, ['元町・中華街']);
    expect(ekiInColumns('羽田空港第1・第2ターミナル').columns, ['羽田空港第1・', '第2ターミナル']);
    final c = ekiInColumns('小川町（千代田区）');
    expect(c.columns, ['小川町']);
    expect(c.note, '千代田区');
  });

  test('emblems from the name, steady otherwise', () {
    expect(ekiInMotif('桜木町', 'a'), EkiInMotif.sakura);
    expect(ekiInMotif('日本橋', 'a'), EkiInMotif.bridge);
    expect(ekiInMotif('渋谷', 'a'), EkiInMotif.hill);
    expect(ekiInMotif('品川', 'a'), EkiInMotif.river);
    expect(ekiInMotif('とうきょうスカイツリー', 'a'), EkiInMotif.tower);
    expect(ekiInMotif('浅草', 'tokyo.asakusa'), ekiInMotif('浅草', 'tokyo.asakusa'));
  });

  test('pages in visit order with a gold page when a line is finished', () {
    final city = loadTokyo();
    final ginza = city.line('tokyo.ginza');
    final stamps = {
      for (final (i, s) in ginza.stations.indexed) s: '2026-11-${(1 + i).toString().padLeft(2, '0')}',
      'tokyo.shinagawa': '2026-10-01',
      'nowhere': '2026-10-01',
    };
    final pages = ekiInEntries(city, stamps);
    expect(pages.length, ginza.stations.length + 2);
    expect(pages.first.station!.id, 'tokyo.shinagawa');
    expect(pages.first.number, 1);
    expect(pages.last.isLineComplete, isTrue);
    expect(pages.last.line.id, 'tokyo.ginza');
    expect(pages.last.mark, EkiInMark.complete);
    expect(pages.last.day, DateTime(2026, 11, ginza.stations.length));
    // Not finished: no gold page.
    final fewer = Map.of(stamps)..remove(ginza.stations.first);
    expect(ekiInEntries(city, fewer).where((e) => e.isLineComplete), isEmpty);
  });
}
