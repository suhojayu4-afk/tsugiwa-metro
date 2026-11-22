// The attendant's tips: the data (tips.json, attendant_tips.json) and how
// guideTips picks and orders them.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsugiwa_metro/core/localized_text.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_ui.dart';
import 'package:tsugiwa_metro/data/congestion/congestion_source.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';
import 'package:tsugiwa_metro/features/guide/guide_data.dart';
import 'package:tsugiwa_metro/features/guide/guide_tips.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';

import 'trip_logic_test.dart' show loadTokyo;

const langs = ['ja', 'ko', 'en'];

/// Width of a line in half-width characters (a kanji, kana or Hangul = 2).
int halfWidths(String s) => s.runes.fold(0, (n, r) => n + (r < 0x2000 ? 1 : 2));

/// Longest line the bubble takes, in half-widths: three lines of about 32.
const maxHalfWidths = {'ja': 84, 'ko': 84, 'en': 84};

/// Text width of the bubble on a 360dp phone (the narrowest common one):
/// 360 - 40 (list) - 50 (attendant) - 42 (padding) - 2 (border), and 10 spare
/// because the phone's own font is not the test's.
const bubbleWidth = 216.0;

void main() {
  final city = loadTokyo();
  Object read(String f) => jsonDecode(File('assets/cities/tokyo/$f').readAsStringSync()) as Object;
  final data = GuideData.fromJson(
    exits: read('exits.json') as Map<String, dynamic>,
    courses: read('courses.json') as List<dynamic>,
    tips: read('tips.json') as Map<String, dynamic>,
    pool: read('attendant_tips.json') as List<dynamic>,
  );

  /// A time in Japan as the instant guideTips takes.
  DateTime jst(int y, int mo, int d, [int h = 12, int mi = 0]) => DateTime.utc(y, mo, d, h - 9, mi);

  List<GuideTip> tipsAt(
    DateTime now, {
    String? from = 'tokyo.shibuya',
    String? to = 'tokyo.ueno',
    WeatherNow? weather,
    CongestionLevel? crowd,
    bool withRoute = true,
  }) => guideTips(
    city: city,
    data: data,
    now: now,
    lang: 'ja',
    route: withRoute && from != null && to != null ? RouteFinder(city).find(from, to) : null,
    fromId: from,
    toId: to,
    weather: weather,
    crowd: crowd,
    stamped: (_) => true,
    stayed: (_) => true,
  );

  /// Every line the attendant can say from the data, with the station name
  /// in front of a station's tip as the card shows it.
  List<({String where, LocalizedText text})> allLines() => [
    for (final e in data.stationTips.entries)
      for (final t in e.value)
        (
          where: e.key,
          text: LocalizedText({
            'ja': '${city.station(e.key).name.of('ja')}：${t.of('ja')}',
            'ko': '${city.station(e.key).name.of('ko')}: ${t.of('ko')}',
            'en': '${city.station(e.key).name.of('en')}: ${t.of('en')}',
          }),
        ),
    for (final p in data.pool) (where: p.cat, text: p.text),
  ];

  test('counts', () {
    final cats = <String, int>{};
    for (final p in data.pool) {
      cats[p.cat] = (cats[p.cat] ?? 0) + 1;
    }
    final stationLines = data.stationTips.values.fold(0, (n, l) => n + l.length);
    // ignore: avoid_print
    print(
      'guide tips: ${data.stationTips.length} stations, $stationLines station tips, '
      '${data.pool.length} general tips $cats',
    );
    final longest = {
      for (final l in langs) l: allLines().map((x) => halfWidths(x.text.of(l))).reduce((a, b) => a > b ? a : b),
    };
    // ignore: avoid_print
    print('longest line in half-widths (station name included): $longest');
    expect(data.stationTips.length, greaterThanOrEqualTo(80));
    expect(data.pool.length, greaterThanOrEqualTo(150));
    for (final c in ['greet', 'manners', 'howto', 'trivia', 'season', 'weather', 'crowd', 'app']) {
      expect(cats[c] ?? 0, greaterThanOrEqualTo(10), reason: c);
    }
    expect(cats.length, 8, reason: 'a category the rotation does not know: $cats');
  });

  test('station tips are for real stations, two or more words in each language', () {
    final onMap = {
      for (final l in read('lines.json') as List) ...((l as Map<String, dynamic>)['stations'] as List).cast<String>(),
    };
    for (final e in data.stationTips.entries) {
      expect(city.stations.containsKey(e.key), isTrue, reason: e.key);
      expect(onMap.contains(e.key), isTrue, reason: '${e.key} is on no line');
      expect(e.value.length, inInclusiveRange(1, 4), reason: e.key);
    }
    for (final id in ['tokyo.tokyo', 'tokyo.shinjuku', 'tokyo.yokohama', 'tokyo.narita_airport', 'tokyo.maihama']) {
      expect(data.stationTips[id]!.length, greaterThanOrEqualTo(2), reason: id);
    }
  });

  test('every tip has ja, ko and en, is short enough, and no line is said twice', () {
    for (final lang in langs) {
      final seen = <String>{};
      for (final x in allLines()) {
        expect(x.text.values.keys.toSet(), langs.toSet(), reason: x.where);
        final s = x.text.values[lang]!;
        expect(s.trim(), s, reason: s);
        expect(s.length, greaterThan(3), reason: '${x.where} $lang');
        expect(halfWidths(s), lessThanOrEqualTo(maxHalfWidths[lang]!), reason: '$lang too long: $s');
        expect(seen.add(s), isTrue, reason: 'twice: $s');
      }
    }
    // Korean and English are their own text, not Japanese left in.
    final kana = RegExp('[ぁ-んァ-ヶ]');
    for (final x in allLines()) {
      expect(kana.hasMatch(x.text.of('ko')), isFalse, reason: x.text.of('ko'));
      // 回送, 番線, 公園口: a sign's own letters may be quoted in English.
      expect(kana.hasMatch(x.text.of('en').replaceAll(RegExp('モハ|クハ'), '')), isFalse, reason: x.text.of('en'));
      expect(RegExp('[가-힣]').hasMatch(x.text.of('ko')), isTrue, reason: x.text.of('ko'));
      expect(RegExp('[가-힣ぁ-ん]').hasMatch(x.text.of('en')), isFalse, reason: x.text.of('en'));
    }
  });

  testWidgets('every tip fits the three lines of the bubble', (tester) async {
    await tester.runAsync(() async {
      for (final f in ['DotGothic16-Regular.ttf', 'Galmuri11.ttf']) {
        final font = FontLoader(f.startsWith('Dot') ? 'DotGothic16' : 'Galmuri11')
          ..addFont(rootBundle.load('assets/fonts/$f'));
        await font.load();
      }
    });
    var worst = 0.0;
    for (final lang in langs) {
      for (final x in allLines()) {
        final p = TextPainter(
          text: TextSpan(
            text: x.text.of(lang),
            style: pixelStyle(size: 14).copyWith(
              fontFamily: lang == 'ko' ? 'Galmuri11' : 'DotGothic16',
              fontFamilyFallback: [lang == 'ko' ? 'DotGothic16' : 'Galmuri11'],
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 3,
        )..layout(maxWidth: bubbleWidth);
        expect(p.didExceedMaxLines, isFalse, reason: '$lang does not fit: ${x.text.of(lang)}');
        if (p.computeLineMetrics().length == 3) worst = worst < p.width ? p.width : worst;
        p.dispose();
      }
    }
    expect(worst, lessThanOrEqualTo(bubbleWidth));
  });

  test('pool lines know their hours, dates, weather and crowd', () {
    PoolTip tip({(int, int)? hours, (int, int)? days, String? wx, String? crowd, String? day, String? need}) => PoolTip(
      TipKind.help,
      const LocalizedText({'ja': 'x'}),
      cat: 'howto',
      hours: hours,
      days: days,
      wx: wx,
      crowd: crowd,
      day: day,
      need: need,
    );
    TipMoment at({
      int hour = 12,
      int weekday = 3,
      int md = 1122,
      WeatherKind? wx,
      bool later = false,
      double? temp,
      CongestionLevel? crowd,
      bool route = false,
      bool changes = false,
      bool through = false,
    }) => TipMoment(
      hour: hour,
      weekday: weekday,
      monthDay: md,
      weather: wx,
      wetLater: later,
      tempC: temp,
      crowd: crowd,
      hasRoute: route,
      changes: changes,
      through: through,
    );

    // Hours: the end is not included; a window may pass midnight.
    expect(tip(hours: (7, 9)).fits(at(hour: 7)), isTrue);
    expect(tip(hours: (7, 9)).fits(at(hour: 9)), isFalse);
    expect(tip(hours: (7, 9)).fits(at(hour: 12)), isFalse);
    expect(tip(hours: (23, 4)).fits(at(hour: 0)), isTrue);
    expect(tip(hours: (23, 4)).fits(at(hour: 23)), isTrue);
    expect(tip(hours: (23, 4)).fits(at(hour: 4)), isFalse);
    // Dates: both ends included; a window may pass New Year.
    expect(tip(days: (320, 410)).fits(at(md: 320)), isTrue);
    expect(tip(days: (320, 410)).fits(at(md: 410)), isTrue);
    expect(tip(days: (320, 410)).fits(at(md: 411)), isFalse);
    expect(tip(days: (1230, 103)).fits(at(md: 1231)), isTrue);
    expect(tip(days: (1230, 103)).fits(at(md: 102)), isTrue);
    expect(tip(days: (1230, 103)).fits(at(md: 104)), isFalse);
    // Days of the week.
    expect(tip(day: 'wd').fits(at(weekday: 5)), isTrue);
    expect(tip(day: 'wd').fits(at(weekday: 6)), isFalse);
    expect(tip(day: 'we').fits(at(weekday: 7)), isTrue);
    expect(tip(day: '5').fits(at(weekday: 5)), isTrue);
    expect(tip(day: '5').fits(at(weekday: 4)), isFalse);
    // Weather: nothing when it is not known.
    for (final wx in ['rain', 'snow', 'wet', 'later', 'hot', 'cold', 'sunny', 'cloudy']) {
      expect(tip(wx: wx).fits(at()), isFalse, reason: wx);
    }
    expect(tip(wx: 'rain').fits(at(wx: WeatherKind.rain)), isTrue);
    expect(tip(wx: 'rain').fits(at(wx: WeatherKind.sunny)), isFalse);
    expect(tip(wx: 'rain').fits(at(wx: WeatherKind.snow)), isFalse);
    expect(tip(wx: 'wet').fits(at(wx: WeatherKind.snow)), isTrue);
    expect(tip(wx: 'later').fits(at(wx: WeatherKind.cloudy, later: true)), isTrue);
    expect(tip(wx: 'later').fits(at(wx: WeatherKind.rain, later: true)), isFalse);
    expect(tip(wx: 'hot').fits(at(wx: WeatherKind.sunny, temp: 33)), isTrue);
    expect(tip(wx: 'hot').fits(at(wx: WeatherKind.sunny, temp: 24)), isFalse);
    expect(tip(wx: 'cold').fits(at(wx: WeatherKind.cloudy, temp: 2)), isTrue);
    expect(tip(wx: 'cold').fits(at(wx: WeatherKind.cloudy)), isFalse);
    expect(tip(wx: 'sunny').fits(at(wx: WeatherKind.cloudy)), isFalse);
    // Crowd and route.
    expect(tip(crowd: 'busy').fits(at(crowd: CongestionLevel.packed)), isTrue);
    expect(tip(crowd: 'busy').fits(at(crowd: CongestionLevel.normal)), isFalse);
    expect(tip(crowd: 'busy').fits(at()), isFalse);
    expect(tip(crowd: 'calm').fits(at(crowd: CongestionLevel.relaxed)), isTrue);
    expect(tip(need: 'route').fits(at()), isFalse);
    expect(tip(need: 'route').fits(at(route: true)), isTrue);
    expect(tip(need: 'transfer').fits(at(route: true)), isFalse);
    expect(tip(need: 'transfer').fits(at(route: true, changes: true)), isTrue);
    expect(tip(need: 'through').fits(at(route: true, through: true)), isTrue);

    // Every condition written in the file is one the code knows.
    for (final p in data.pool) {
      expect(p.wx, anyOf(isNull, isIn(['rain', 'snow', 'wet', 'later', 'hot', 'cold', 'sunny', 'cloudy'])));
      expect(p.crowd, anyOf(isNull, isIn(['busy', 'calm'])));
      expect(p.need, anyOf(isNull, isIn(['route', 'transfer', 'through'])));
      expect(p.day, anyOf(isNull, matches(RegExp(r'^(wd|we|[1-7]+)$'))));
      if (p.hours != null) {
        expect(p.hours!.$1, inInclusiveRange(0, 23));
        expect(p.hours!.$2, inInclusiveRange(1, 24));
      }
      for (final d in [?p.days?.$1, ?p.days?.$2]) {
        expect(d ~/ 100, inInclusiveRange(1, 12));
        expect(d % 100, inInclusiveRange(1, 31));
      }
      if (p.cat == 'season') expect(p.days, isNotNull, reason: p.text.ja);
      if (p.cat == 'weather') expect(p.wx, isNotNull, reason: p.text.ja);
      if (p.cat == 'crowd') expect(p.crowd, isNotNull, reason: p.text.ja);
      if (p.cat == 'greet') expect(p.hours, isNotNull, reason: p.text.ja);
    }
    // Some greeting at every hour of a weekday and of a weekend.
    for (final weekday in [2, 6]) {
      for (var h = 0; h < 24; h++) {
        final n = data.pool.where((p) => p.cat == 'greet' && p.fits(at(hour: h, weekday: weekday))).length;
        expect(n, greaterThanOrEqualTo(2), reason: 'greetings at $h:00, weekday $weekday');
      }
    }
  });

  test('only what fits now is said: no rain on a clear day, no rush at noon, seasons in their window', () {
    Iterable<PoolTip> pool(List<GuideTip> tips) => tips.whereType<PoolTip>();
    const clear = WeatherNow(kind: WeatherKind.sunny, tempC: 14, rainChance: 0);
    const rain = WeatherNow(kind: WeatherKind.rain, tempC: 14, forecastKind: WeatherKind.rain);

    // Wednesday 18 November 2026, noon, clear and calm.
    final noon = tipsAt(jst(2026, 11, 18), weather: clear, crowd: CongestionLevel.relaxed);
    expect(pool(noon).where((p) => ['rain', 'snow', 'wet', 'later', 'hot', 'cold'].contains(p.wx)), isEmpty);
    expect(pool(noon).where((p) => p.wx == 'sunny'), isNotEmpty);
    expect(pool(noon).where((p) => p.crowd == 'busy'), isEmpty);
    expect(pool(noon).where((p) => p.crowd == 'calm'), isNotEmpty);
    expect(noon.where((t) => t.text.ja.contains(RegExp('(朝|夕方)のラッシュ'))), isEmpty);
    expect(noon.where((t) => t.text.ja.contains('おはよう') || t.text.ja.contains('こんばんは')), isEmpty);
    expect(noon.where((t) => t.text.ja.contains('こんにちは')), isNotEmpty);
    expect(noon.where((t) => t.text.ja.contains('紅葉')), isNotEmpty);
    expect(noon.where((t) => t.text.ja.contains('桜の季節') || t.text.ja.contains('梅雨')), isEmpty);
    expect(noon.where((t) => t.text.ja.contains('終電まで')), isEmpty);

    // The same day in the rain, in the morning rush, crowded.
    final rush = tipsAt(jst(2026, 11, 18, 8), weather: rain, crowd: CongestionLevel.packed);
    expect(rush.first.kind, TipKind.warn);
    expect(pool(rush).where((p) => p.wx == 'rain'), isNotEmpty);
    expect(pool(rush).where((p) => p.wx == 'sunny' || p.wx == 'later'), isEmpty);
    expect(pool(rush).where((p) => p.crowd == 'busy'), isNotEmpty);
    expect(pool(rush).where((p) => p.crowd == 'calm'), isEmpty);
    expect(rush.where((t) => t.text.ja.contains('朝のラッシュ')), isNotEmpty);
    expect(rush.where((t) => t.text.ja.contains('こんにちは') || t.text.ja.contains('こんばんは')), isEmpty);

    // Weather not known: no weather lines at all.
    expect(pool(tipsAt(jst(2026, 11, 18))).where((p) => p.cat == 'weather'), isEmpty);

    // Seasons: cherry blossoms on 1 April, the rainy season on 20 June, heat in August, New Year.
    bool says(List<GuideTip> tips, String word) => tips.any((t) => t.text.ja.contains(word));
    final april = tipsAt(jst(2027, 4, 1));
    expect(says(april, '桜の季節'), isTrue);
    expect(says(april, '花粉'), isTrue);
    expect(says(april, '紅葉') || says(april, '梅雨の季節') || says(april, '台風'), isFalse);
    final june = tipsAt(jst(2027, 6, 20));
    expect(says(june, '梅雨の季節'), isTrue);
    expect(says(june, '桜の季節') || says(june, '花火'), isFalse);
    final august = tipsAt(jst(2027, 8, 20), weather: const WeatherNow(kind: WeatherKind.sunny, tempC: 34));
    expect(says(august, '花火大会'), isTrue);
    expect(says(august, '台風の季節'), isTrue);
    expect(pool(august).where((p) => p.wx == 'hot'), isNotEmpty);
    expect(says(august, '初詣') || says(august, '着ぶくれ'), isFalse);
    final newYear = tipsAt(jst(2027, 1, 2));
    expect(says(newYear, '初詣'), isTrue);
    expect(says(newYear, 'あけまして'), isTrue);
    expect(says(newYear, '大みそか'), isFalse);
    expect(says(tipsAt(jst(2026, 12, 31)), '大みそか'), isTrue);
    // Everything from the pool fits the moment it was picked for.
    final then = TipMoment.at(
      DateTime(2027, 8, 20, 12),
      weather: const WeatherNow(kind: WeatherKind.sunny, tempC: 34),
      hasRoute: true,
      changes: true,
      through: true,
    );
    expect(pool(august).where((p) => !p.fits(then)), isEmpty);
  });

  test('tips of the start AND the destination station, with the name in front', () {
    final tips = tipsAt(jst(2026, 11, 18), from: 'tokyo.shinagawa', to: 'tokyo.maihama');
    final ja = [for (final t in tips) t.text.ja];
    expect(ja.where((s) => s.startsWith('品川：')).length, data.stationTips['tokyo.shinagawa']!.length);
    expect(ja.where((s) => s.startsWith('舞浜：')).length, data.stationTips['tokyo.maihama']!.length);
    expect(tips.firstWhere((t) => t.text.ja.startsWith('舞浜：')).text.of('ko'), startsWith('마이하마: '));
    expect(tips.firstWhere((t) => t.text.ja.startsWith('舞浜：')).text.of('en'), startsWith('Maihama: '));
    // No other station's tip slips in (but where trains are changed may).
    final names = {for (final id in data.stationTips.keys) '${city.station(id).name.ja}：'};
    final route = RouteFinder(city).find('tokyo.shinagawa', 'tokyo.maihama')!;
    final onTheWay = {
      for (final l in route.legs) ...[
        city.station(l.stationIds.first).name.ja,
        city.station(l.stationIds.last).name.ja,
      ],
    };
    for (final s in ja) {
      final n = names.where(s.startsWith);
      if (n.isNotEmpty) expect(onTheWay.contains(n.first.replaceAll('：', '')), isTrue, reason: s);
    }
    // Only a start: its tips; nothing chosen: none.
    final one = tipsAt(jst(2026, 11, 18), from: 'tokyo.asakusa', to: null);
    expect(one.where((t) => t.text.ja.startsWith('浅草：')), isNotEmpty);
    final none = tipsAt(jst(2026, 11, 18), from: null, to: null);
    expect(none.where((t) => names.any(t.text.ja.startsWith)), isEmpty);
    expect(none.length, greaterThan(60));
  });

  test('rotation: warnings first, no tip twice in a row, categories mixed, the same every time', () {
    const rain = WeatherNow(kind: WeatherKind.rain, tempC: 9);
    final situations = <String, List<GuideTip>>{
      'noon': tipsAt(jst(2026, 11, 18)),
      'no stations': tipsAt(jst(2026, 11, 18), from: null, to: null),
      'last train in the rain': tipsAt(jst(2026, 11, 19, 0), weather: rain, crowd: CongestionLevel.crowded),
      'night, trains over': tipsAt(jst(2026, 11, 19, 2), from: 'tokyo.kamakura', to: null),
    };
    for (final s in situations.entries) {
      final tips = s.value;
      expect(tips.length, greaterThan(50), reason: s.key);
      // The card shows tips[i % length]: 50 turns and once round the whole list.
      for (var i = 0; i < tips.length + 50; i++) {
        final a = tips[i % tips.length], b = tips[(i + 1) % tips.length];
        expect(a.key == b.key, isFalse, reason: '${s.key}: twice in a row at $i: ${a.text.ja}');
      }
      // Nothing comes back within the round, except a warning from the head.
      final count = <String, int>{};
      for (final t in tips) {
        count[t.key] = (count[t.key] ?? 0) + 1;
      }
      for (final t in tips) {
        if (count[t.key]! > 1) expect(t.kind, TipKind.warn, reason: '${s.key}: ${t.text.ja}');
      }
      // Never three general lines of one category in a row in the first 50.
      final cats = [for (final t in tips.take(50)) t is PoolTip ? t.cat : null];
      for (var i = 2; i < cats.length; i++) {
        final same = cats[i] != null && cats[i] == cats[i - 1] && cats[i] == cats[i - 2];
        expect(same, isFalse, reason: '${s.key}: three ${cats[i]} lines in a row at $i');
      }
      expect(cats.whereType<String>().toSet().length, greaterThanOrEqualTo(5), reason: s.key);
      // A greeting closes the round.
      expect(tips.last, isA<PoolTip>().having((p) => p.cat, 'cat', 'greet'), reason: s.key);
    }
    final late = situations['last train in the rain']!;
    expect(late.first.key, 'last');
    expect(late.first.kind, TipKind.warn);
    expect(late[1].kind, TipKind.warn);
    // The warnings come back while the rest goes round.
    expect(late.where((t) => t.key == 'last').length, greaterThan(3));
    expect(late.skip(2).take(9).where((t) => t.key == 'last'), isEmpty);

    // The same day and stations: the same order, and the very same list while nothing changes.
    List<String> keys(List<GuideTip> t) => [for (final x in t) x.key];
    final a = tipsAt(jst(2026, 11, 18, 12, 5));
    expect(identical(a, tipsAt(jst(2026, 11, 18, 12, 40))), isTrue);
    final other = tipsAt(jst(2026, 11, 18, 12, 5), from: 'tokyo.ikebukuro', to: 'tokyo.ginza');
    expect(identical(a, other), isFalse);
    expect(keys(tipsAt(jst(2026, 11, 18, 12, 5))), keys(a));
    expect(keys(tipsAt(jst(2026, 11, 18, 12, 5))), keys(situations['noon']!));
    // Another day or another pair of stations: another order of the general lines.
    List<String> general(List<GuideTip> t) => [
      for (final x in t.whereType<PoolTip>())
        if (x.cat == 'manners') x.key,
    ];
    expect(general(tipsAt(jst(2026, 11, 19))), isNot(general(a)));
    expect(general(tipsAt(jst(2026, 11, 19))).toSet(), general(a).toSet());
    expect(general(other), isNot(general(a)));
  });

  test('without the pool (not loaded yet) there is still a greeting', () {
    final bare = guideTips(city: city, data: const GuideData(), now: jst(2026, 11, 18, 8), lang: 'ja');
    expect(bare.single.text.ja, contains('おはよう'));
    expect(
      guideTips(city: city, data: const GuideData(), now: jst(2026, 11, 18, 21), lang: 'ja').single.text.ja,
      contains('おつかれさま'),
    );
  });
}
