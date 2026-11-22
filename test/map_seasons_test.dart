import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/localized_text.dart';
import 'package:tsugiwa_metro/data/models/route_map.dart';
import 'package:tsugiwa_metro/features/route_map/map_seasons.dart';
import 'package:tsugiwa_metro/features/route_map/route_map_screen.dart';

import 'trip_logic_test.dart' show loadTokyo;

void main() {
  Map<String, dynamic> read(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final map = RouteMapData.fromJson(read('assets/cities/tokyo/map.json'), const {});
  final seasons = MapSeasons.fromJson(read('assets/cities/tokyo/seasons.json'), landmarks: map.landmarks);
  // The same spots with room found for them on the map (as the app shows them).
  final stationList = (jsonDecode(File('assets/cities/tokyo/stations.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  // A name's width in ems: the widest of the languages, Latin letters half an em.
  final ems = {
    for (final st in stationList)
      st['id'] as String: (st['name'] as Map).values.fold<double>(
        1,
        (m, v) => math.max(m, (v as String).runes.fold<double>(0, (w, c) => w + (c < 0x2000 ? 0.55 : 1))),
      ),
  };
  final placed = MapSeasons.fromJson(read('assets/cities/tokyo/seasons.json'), map: map, nameEms: (id) => ems[id] ?? 4);
  // Zooms from all of Kanto to the closest, between the steps where pictures and names change size.
  const zooms = [0.115, 0.14, 0.2, 0.23, 0.26, 0.3, 0.36, 0.45, 0.6, 0.8, 1.0, 1.4, 2.0, 3.0, 4.0];
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
    for (final s in [...seasons.spots, ...placed.spots]) {
      expect(bounds.contains(s.position), isTrue, reason: '${s.name.ja} ${s.position}');
      expect(drawn.contains(s.position), isTrue, reason: '${s.name.ja} ${s.position}');
      // A landmark is moved off the lines a little, never far.
      expect((proj.toMap(s.lat, s.lng) - s.origin).distance, lessThan(260), reason: s.name.ja);
    }
    // Room is found near the real place, and something is left to draw there.
    for (final s in placed.spots) {
      expect((s.position - s.origin).distance, lessThanOrEqualTo(170), reason: s.name.ja);
      expect(s.scale, inInclusiveRange(0.3, 1.0), reason: s.name.ja);
      expect(SeasonPainter.boxes(s, 1.0), isNotEmpty, reason: s.name.ja);
      if (const {SeasonKind.sakura, SeasonKind.momiji, SeasonKind.icho, SeasonKind.mixed}.contains(s.kind)) {
        expect(s.items!.length, inInclusiveRange(1, s.count), reason: s.name.ja);
        for (final o in s.items!) {
          expect(o.distance, lessThan(190), reason: '${s.name.ja}: a tree far from its cluster');
        }
      }
    }
  });

  // What the map draws over the ground, straight from the map data (not the
  // placer's own grid): every line segment, and each station's dots.
  final segments = <(Offset, Offset)>[
    for (final line in map.lines)
      for (var i = 0; i + 1 < line.path.length + (line.closed ? 1 : 0); i++)
        (line.path[i], line.path[(i + 1) % line.path.length]),
  ];
  // The stations as the map draws them (id, the box round its stops, how many lines).
  final dots = [
    for (final MapEntry(key: id, value: stops) in map.stations.entries)
      (
        id,
        stops.fold(
          Rect.fromPoints(stops.first.position, stops.first.position),
          (Rect r, x) => r.expandToInclude(Rect.fromPoints(x.position, x.position)),
        ),
        stops.length,
      ),
  ];
  bool segmentInRect(Offset a, Offset b, Rect r) {
    if (r.contains(a) || r.contains(b)) return true;
    double cross(Offset o, Offset p, Offset q) => (p.dx - o.dx) * (q.dy - o.dy) - (p.dy - o.dy) * (q.dx - o.dx);
    bool meet(Offset c, Offset d) =>
        a != b && cross(a, b, c) * cross(a, b, d) <= 0 && cross(c, d, a) * cross(c, d, b) <= 0;
    return meet(r.topLeft, r.topRight) ||
        meet(r.topRight, r.bottomRight) ||
        meet(r.bottomRight, r.bottomLeft) ||
        meet(r.bottomLeft, r.topLeft);
  }

  // A small tolerance, in map units (a pixel or less on screen at most zooms).
  const slack = 1.5;

  test('no seasonal picture lies on a line stroke or a station dot: every season, spot and zoom', () {
    var boxes = 0;
    for (final z in zooms) {
      final half = mapLineWidth(z) / 2 / z, r = mapStationRadius(z) / z;
      for (final spot in placed.spots) {
        if (SeasonPainter.fadeOf(spot, z) <= 0) continue;
        for (final box in SeasonPainter.boxes(spot, z)) {
          boxes++;
          final why = '${spot.season.id} ${spot.name.ja} at zoom $z: $box';
          expect(box.width > 0 && box.height > 0, isTrue, reason: why);
          final stroke = box.inflate(half - slack);
          for (final (a, b) in segments) {
            if (math.min(a.dx, b.dx) > stroke.right || math.max(a.dx, b.dx) < stroke.left) continue;
            if (math.min(a.dy, b.dy) > stroke.bottom || math.max(a.dy, b.dy) < stroke.top) continue;
            expect(segmentInRect(a, b, stroke), isFalse, reason: 'on a line ($a - $b): $why');
          }
          for (final (id, at, lines) in dots) {
            // As the map draws them: far out only transfer stations, then only the big ones.
            if (z < 0.3 && lines == 1 || z < 0.12 && !mapMajorStations.contains(id)) continue;
            if ((at.center.dx - box.center.dx).abs() > 600 || (at.center.dy - box.center.dy).abs() > 600) continue;
            if (lines > 1) {
              // One pill round its stops on every line.
              expect(at.inflate(r + 2 / z - slack).overlaps(box), isFalse, reason: 'on the pill of $id: $why');
            } else {
              final c = at.center;
              final dx = math.max(math.max(box.left - c.dx, c.dx - box.right), 0.0);
              final dy = math.max(math.max(box.top - c.dy, c.dy - box.bottom), 0.0);
              expect(math.sqrt(dx * dx + dy * dy), greaterThan(r - slack), reason: 'on the dot of $id: $why');
            }
          }
        }
      }
    }
    expect(boxes, greaterThan(1500));
  });

  test('no seasonal picture lies under a station name, from the zoom the names read at', () {
    final ob = placed.obstacles!;
    for (final z in zooms) {
      for (final spot in placed.spots) {
        if (SeasonPainter.fadeOf(spot, z) <= 0) continue;
        for (final box in SeasonPainter.boxes(spot, z)) {
          // Further out only the big stations' names, which are always shown.
          expect(
            ob.labelsIn(box.deflate(slack), z, onlyMajor: z < MapObstacles.namesFrom),
            isEmpty,
            reason: '${spot.season.id} ${spot.name.ja} at zoom $z',
          );
        }
      }
    }
  });

  test('the soft glows on the ground stop short of the lines', () {
    for (final spot in placed.spots) {
      final z = spot.keepSize ? 0.115 : SeasonPlacer.lowZoom;
      final at = switch (spot.kind) {
        SeasonKind.shrine ||
        SeasonKind.temple => spot.onLandmark ? spot.origin : spot.position.translate(0, -16 * spot.scale),
        _ => spot.position,
      };
      expect(spot.clear, lessThanOrEqualTo(140), reason: spot.name.ja);
      final half = mapLineWidth(z) / 2 / z;
      for (final (a, b) in segments) {
        final ab = b - a, l2 = ab.distanceSquared;
        final t = l2 == 0 ? 0.0 : (((at.dx - a.dx) * ab.dx + (at.dy - a.dy) * ab.dy) / l2).clamp(0.0, 1.0);
        expect((at - (a + ab * t)).distance - half, greaterThan(spot.clear - slack), reason: spot.name.ja);
      }
    }
  });

  test('spots shown together do not stand on each other', () {
    final all = placed.spots;
    for (var i = 0; i < all.length; i++) {
      for (var j = i + 1; j < all.length; j++) {
        if (!all[i].season.overlaps(all[j].season)) continue;
        for (final a in SeasonPainter.boxes(all[i], 0.6)) {
          for (final b in SeasonPainter.boxes(all[j], 0.6)) {
            expect(a.overlaps(b), isFalse, reason: '${all[i].name.ja} / ${all[j].name.ja}');
          }
        }
      }
    }
  });

  test('every spot can be tapped on its picture, clear of the stations (a station wins a tap near it)', () {
    // Off the pictures a station wins within a finger's reach; on a picture only on or by its dot.
    expect(stationWinsTap(25, 1), isTrue);
    expect(stationWinsTap(25, 1, onPicture: true), isFalse);
    expect(stationWinsTap(mapStationRadius(1) + 7, 1, onPicture: true), isTrue);
    for (final season in placed.seasons) {
      // Any day of the season, with whatever else is on the map that day.
      final day = DateTime.utc(2027, season.from.$1, season.from.$2, 3);
      final spots = placed.spotsAt(day);
      expect(spots.where((s) => s.season.id == season.id), isNotEmpty);
      for (final spot in spots) {
        for (final z in [0.45, 0.6, 1.0, 2.0]) {
          final m = Matrix4.identity()..scaleByDouble(z, z, 1, 1);
          var found = false;
          search:
          for (final box in SeasonPainter.boxes(spot, z)) {
            for (var fx = 0.1; fx < 1; fx += 0.2) {
              for (var fy = 0.1; fy < 1; fy += 0.2) {
                final p = Offset(box.left + box.width * fx, box.top + box.height * fy);
                // On or right by a station's dot the station opens instead.
                if (map.allStops.any((x) => stationWinsTap((x.position - p).distance * z, z, onPicture: true))) {
                  continue;
                }
                if (seasonSpotAt(spots, m, p * z, exact: true) == spot) {
                  found = true;
                  break search;
                }
              }
            }
          }
          expect(found, isTrue, reason: '${season.id} ${spot.name.ja} at zoom $z');
        }
      }
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
    // On the map: on one of its trees, wherever they found room.
    final onMap = placed.spotsAt(jst(2027, 4, 1));
    final park = onMap.firstWhere((s) => s.name.ja == '上野恩賜公園');
    expect(seasonSpotAt(onMap, m, SeasonPainter.boxes(park, 1).first.center)?.name.ja, '上野恩賜公園');
    expect(seasonSpotAt(spots, m, ueno.position.translate(300, 300)), isNull);
    // Too far out: nothing to tap.
    final far = Matrix4.identity()..scaleByDouble(0.05, 0.05, 1, 1);
    expect(seasonSpotAt(spots, far, ueno.position * 0.05), isNull);
  });

  test('landmarks with cherry trees wear the season: pink only while they bloom', () {
    for (final p in MapSeasons.landmarkArt) {
      expect(File(p).existsSync(), isTrue, reason: p);
    }
    const ueno = 'assets/art/landmarks/ueno.png', pagoda = 'assets/art/landmarks/chureito.png';
    expect(map.landmarks.map((l) => l.image), containsAll([ueno, pagoda]));
    expect(MapSeasons.landmarkArtAt(jst(2027, 4, 1)), isEmpty);
    expect(MapSeasons.landmarkArtAt(jst(2026, 11, 22))[ueno], 'assets/art/map_seasons/ueno_koyo.webp');
    expect(MapSeasons.landmarkArtAt(jst(2026, 11, 22))[pagoda], 'assets/art/map_seasons/chureito_koyo.webp');
    expect(MapSeasons.landmarkArtAt(jst(2026, 7, 1))[ueno], 'assets/art/map_seasons/ueno_green.webp');
    expect(MapSeasons.landmarkArtAt(jst(2027, 1, 2))[pagoda], 'assets/art/map_seasons/chureito_green.webp');
    // The same days as the map's own trees change.
    for (final day in [jst(2027, 3, 19), jst(2027, 3, 20), jst(2027, 4, 15), jst(2027, 4, 16), jst(2026, 11, 9)]) {
      expect(MapSeasons.landmarkArtAt(day).isEmpty, RouteMapData.seasonOf(day) == 'spring');
    }
  });

  test('map names: the bracket that tells two stations apart is not written on the map', () {
    expect(mapStationName('小川町（千代田区）'), '小川町');
    expect(mapStationName('小川町'), '小川町');
    expect(mapStationName('明治神宮前〈原宿〉'), '明治神宮前〈原宿〉');
    expect(mapStationName('Ogawamachi (Chiyoda)'), 'Ogawamachi');
    expect(mapStationName('오가와마치 (지요다구)'), '오가와마치');
    expect(mapStationName('Ogawamachi(x)'), 'Ogawamachi(x)');
    expect(mapStationName('（仮）'), '（仮）');
    final city = loadTokyo();
    // No name is left empty, and the two 小川町 are far from each other on the map.
    for (final st in city.stations.values) {
      for (final name in st.name.values.values) {
        expect(mapStationName(name), isNotEmpty, reason: st.id);
      }
    }
    final a = map.stopsOf('tokyo.ogawamachi').first.position;
    final b = map.stopsOf('tokyo.ogawamachi_hachiko').first.position;
    expect((a - b).distance, greaterThan(1500));
    // Widths in ems: the widest language; Latin letters half an em.
    expect(stationNameEms(city, 'tokyo.ogawamachi'), closeTo('Ogawamachi'.length * 0.55, 0.01));
    for (final lang in ['ja', 'ko', 'en']) {
      expect(mapStationName(city.station('tokyo.ogawamachi').name.of(lang)), isNot(contains('）')));
      expect(mapStationName(city.station('tokyo.ogawamachi').name.of(lang)), isNot(contains(')')));
    }
    expect(stationNameEms(city, 'tokyo.tokyo'), greaterThanOrEqualTo(2));
  });

  test('stickers shrink with the map, fade out far out and sit beside the station, not on it', () {
    expect(mapStickerAlpha(0.12), 0);
    expect(mapStickerAlpha(0.3), 1);
    expect(mapStickerSize(0.3), lessThanOrEqualTo(15));
    expect(mapStickerSize(4), 34);
    var last = 0.0;
    for (var z = 0.05; z <= 4; z += 0.05) {
      final size = mapStickerSize(z);
      expect(size, inInclusiveRange(13, 34));
      expect(size, greaterThanOrEqualTo(last));
      last = size;
      final r = mapStationRadius(z);
      for (final below in [false, true]) {
        // One dot, and a transfer station's pill.
        for (final stops in [Rect.zero, const Rect.fromLTWH(0, 0, 14, 6)]) {
          final at = mapStickerCentre(stops, r, Size(size, size), below: below);
          final sticker = Rect.fromCenter(center: at, width: size, height: size);
          expect(sticker.overlaps(stops.inflate(r * 0.7)), isFalse, reason: 'zoom $z');
          // Beside it: no further than its own size away.
          expect((sticker.center - stops.center).distance, lessThan(size + r + stops.longestSide));
          expect(sticker.center.dy < stops.center.dy, !below);
        }
      }
    }
  });

  test('the map buttons always fit the screen: smaller, then in two columns', () {
    expect(mapControlsLayout(700, 8), (size: 46.0, gap: 10.0, columns: 1));
    expect(mapControlsLayout(430, 8), (size: 40.0, gap: 8.0, columns: 1));
    for (var h = 60.0; h < 900; h += 7) {
      for (final n in [7, 8]) {
        final l = mapControlsLayout(h, n);
        final perColumn = (n / l.columns).ceil();
        expect(perColumn * l.size + (perColumn - 1) * l.gap, lessThanOrEqualTo(math.max(h, l.size)), reason: '$h $n');
        expect(l.columns, lessThanOrEqualTo(n));
      }
    }
    // A short screen (360 x 560 less the bars): one column still; landscape: two.
    expect(mapControlsLayout(560 - 84 - 20, 8).columns, 1);
    expect(mapControlsLayout(360 - 84 - 20, 8).columns, 2);
  });

  testWidgets('the painter draws inside the boxes the placement keeps clear', (tester) async {
    await tester.runAsync(() async {
      final images = <String, ui.Image>{};
      for (final p in MapSeasons.images) {
        final codec = await ui.instantiateImageCodec(File(p).readAsBytesSync());
        images[p] = (await codec.getNextFrame()).image;
      }
      const size = 360;
      for (final z in [0.3, 0.6, 1.0, 2.5]) {
        for (final spot in placed.spots) {
          if (SeasonPainter.fadeOf(spot, z) < 1) continue;
          // The spot in the middle of a small picture, by day, nothing moving.
          final m = Matrix4.identity()
            ..translateByDouble(size / 2 - spot.position.dx * z, size / 2 - spot.position.dy * z, 0, 1)
            ..scaleByDouble(z, z, 1, 1);
          final rec = ui.PictureRecorder();
          final canvas = Canvas(rec, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
          for (final sky in [false, true]) {
            SeasonPainter(
              spots: [spot],
              images: images,
              matrix: ValueNotifier(m),
              clock: const AlwaysStoppedAnimation(0),
              still: true,
              sky: sky,
            ).paint(canvas, Size(size.toDouble(), size.toDouble()));
          }
          final img = await rec.endRecording().toImage(size, size);
          final data = (await img.toByteData())!;
          final boxes = [
            for (final b in SeasonPainter.boxes(spot, z))
              Rect.fromLTRB(
                b.left * z,
                b.top * z,
                b.right * z,
                b.bottom * z,
              ).shift(Offset(m.storage[12], m.storage[13])).inflate(1.5),
          ];
          var solid = 0;
          for (var y = 0; y < size; y++) {
            for (var x = 0; x < size; x++) {
              // Solid paint only: the soft glows are held back another way.
              if (data.getUint8((y * size + x) * 4 + 3) < 150) continue;
              solid++;
              final at = Offset(x + 0.5, y + 0.5);
              if (!boxes.any((b) => b.contains(at))) {
                fail('${spot.season.id} ${spot.name.ja} at zoom $z paints outside its boxes at $at');
              }
            }
          }
          expect(solid, greaterThan(8), reason: '${spot.season.id} ${spot.name.ja} at zoom $z draws nothing');
          img.dispose();
        }
      }
    });
  });
}
