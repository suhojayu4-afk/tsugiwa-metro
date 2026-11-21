import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/localized_text.dart';
import 'package:tsugiwa_metro/data/models/route_map.dart';
import 'package:tsugiwa_metro/features/route_map/map_seasons.dart';

void main() {
  Map<String, dynamic> read(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final map = RouteMapData.fromJson(read('assets/cities/tokyo/map.json'), const {});
  final seasons = MapSeasons.fromJson(read('assets/cities/tokyo/seasons.json'), landmarks: map.landmarks);
  // Noon in Japan.
  DateTime jst(int y, int m, int d, [int h = 12]) => DateTime.utc(y, m, d, h - 9);
  Set<String> active(DateTime t) => {for (final s in seasons.activeAt(t)) s.id};

  test('each season only in its days (Japan time, both ends included)', () {
    expect(active(jst(2027, 1, 1)), {'hatsumode'});
    expect(active(jst(2027, 1, 7)), {'hatsumode'});
    expect(active(jst(2027, 1, 8)), isEmpty);
    // 31 Dec 15:00 UTC is already New Year's Day in Japan.
    expect(active(DateTime.utc(2026, 12, 31, 15)), {'hatsumode'});
    expect(active(DateTime.utc(2026, 12, 31, 14, 59)), isEmpty);
    expect(active(jst(2027, 3, 19)), isEmpty);
    expect(active(jst(2027, 3, 20)), {'sakura'});
    expect(active(jst(2027, 4, 10)), {'sakura'});
    expect(active(jst(2027, 4, 11)), isEmpty);
    expect(active(jst(2027, 7, 14)), isEmpty);
    expect(active(jst(2027, 7, 15)), {'hanabi'});
    expect(active(jst(2027, 8, 31)), {'hanabi'});
    expect(active(jst(2027, 9, 1)), isEmpty);
    expect(active(jst(2026, 10, 31)), isEmpty);
    expect(active(jst(2026, 11, 1)), {'koyo'});
    expect(active(jst(2026, 11, 19)), {'koyo'});
    // Autumn leaves and the illuminations overlap for three weeks.
    expect(active(jst(2026, 11, 20)), {'koyo', 'illumination'});
    expect(active(jst(2026, 12, 10)), {'koyo', 'illumination'});
    expect(active(jst(2026, 12, 11)), {'illumination'});
    expect(active(jst(2026, 12, 25)), {'illumination'});
    expect(active(jst(2026, 12, 26)), isEmpty);
    expect(active(jst(2026, 6, 1)), isEmpty);
  });

  test('a window over New Year wraps round', () {
    const w = SeasonWindow(id: 'x', from: (12, 28), to: (1, 3), name: LocalizedText({'ja': 'x'}));
    expect(w.contains(DateTime(2026, 12, 30)), isTrue);
    expect(w.contains(DateTime(2027, 1, 3)), isTrue);
    expect(w.contains(DateTime(2027, 1, 4)), isFalse);
    expect(w.contains(DateTime(2026, 12, 27)), isFalse);
  });

  test('every season has spots; every spot is named and of a known season', () {
    final ids = {for (final s in seasons.seasons) s.id};
    expect(ids, {'hatsumode', 'sakura', 'hanabi', 'koyo', 'illumination'});
    for (final id in ids) {
      expect(seasons.spots.where((s) => s.season.id == id).length, greaterThanOrEqualTo(5), reason: id);
    }
    final raw = (read('assets/cities/tokyo/seasons.json')['spots'] as List).cast<Map<String, dynamic>>();
    expect(seasons.spots.length, raw.length);
    for (final s in seasons.spots) {
      for (final lang in ['ja', 'ko', 'en']) {
        expect(s.name.values[lang], isNotEmpty, reason: '${s.name.ja} $lang');
        expect(s.season.name.values[lang], isNotEmpty);
      }
    }
    // Spots tied to a landmark found it.
    for (final j in raw.where((j) => j['landmark'] != null)) {
      final s = seasons.spots.firstWhere((s) => s.name.ja == (j['name'] as Map)['ja'] && s.season.id == j['season']);
      expect(s.onLandmark, isTrue, reason: '${j['landmark']}');
    }
  });

  test('every spot projects inside the map, and next to its real place', () {
    final bounds = Offset.zero & map.size;
    final b = map.contentBounds;
    final drawn = Rect.fromLTRB(b.min.dx, b.min.dy, b.max.dx, b.max.dy).inflate(350); // where the map can pan
    const proj = SeasonProjection();
    for (final s in seasons.spots) {
      expect(bounds.contains(s.position), isTrue, reason: '${s.name.ja} ${s.position}');
      expect(drawn.contains(s.position), isTrue, reason: '${s.name.ja} ${s.position}');
      // A landmark is moved off the lines a little, never far.
      expect((proj.toMap(s.lat, s.lng) - s.position).distance, lessThan(260), reason: s.name.ja);
    }
  });

  test('the projection matches the map: stations land on (or near) their stops', () {
    const proj = SeasonProjection();
    final stations = (jsonDecode(File('assets/cities/tokyo/stations.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    final geo = {
      for (final s in stations) s['id'] as String: ((s['geo'] as Map)['lat'] as num, (s['geo'] as Map)['lng'] as num),
    };
    var close = 0, all = 0;
    for (final id in [
      'tokyo.tokyo',
      'tokyo.shinjuku',
      'tokyo.shibuya',
      'tokyo.ueno',
      'tokyo.ikebukuro',
      'tokyo.shinagawa',
    ]) {
      final (lat, lng) = geo[id]!;
      final at = proj.toMap(lat.toDouble(), lng.toDouble());
      final stop = map.stopsOf(id).first.position;
      all++;
      if ((at - stop).distance < 90) close++;
    }
    expect(close, all);
  });

  test('every picture the painter uses exists', () {
    for (final p in MapSeasons.images) {
      expect(File(p).existsSync(), isTrue, reason: p);
    }
  });

  test('a tap finds the spot under the finger', () {
    final spots = seasons.spotsAt(jst(2027, 4, 1));
    final ueno = spots.firstWhere((s) => s.name.ja == '上野恩賜公園');
    final m = Matrix4.identity()..scaleByDouble(1, 1, 1, 1);
    expect(seasonSpotAt(spots, m, ueno.position.translate(5, 5))?.name.ja, '上野恩賜公園');
    expect(seasonSpotAt(spots, m, ueno.position.translate(300, 300)), isNull);
    // Too far out: nothing to tap.
    final far = Matrix4.identity()..scaleByDouble(0.05, 0.05, 1, 1);
    expect(seasonSpotAt(spots, far, ueno.position * 0.05), isNull);
  });
}
