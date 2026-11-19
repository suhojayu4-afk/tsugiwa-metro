import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';

import '../../core/localized_text.dart';

/// Which side of the stop its name is drawn on.
enum LabelSide { left, right, top, bottom }

LabelSide _side(String? s) => switch (s) {
  'l' => LabelSide.left,
  'r' => LabelSide.right,
  't' => LabelSide.top,
  _ => LabelSide.bottom,
};

class MapStop {
  const MapStop(this.stationId, this.position, this.label, [this.lineId = '']);
  final String stationId;
  final Offset position;
  final LabelSide label;

  /// The line this stop is on.
  final String lineId;
}

class MapLine {
  MapLine({required this.lineId, required this.path, required this.closed, required this.stops})
    : bounds = _boundsOf(path);
  final String lineId;
  final List<Offset> path;
  final bool closed;
  final Map<String, MapStop> stops;

  /// Box round the whole line (to skip lines off screen).
  final Rect bounds;

  static Rect _boundsOf(List<Offset> pts) {
    if (pts.isEmpty) return Rect.zero;
    var minX = pts.first.dx, minY = pts.first.dy, maxX = minX, maxY = minY;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

/// Square pictures of the ground, loaded only when on screen: tile (x, y)
/// is `dir/prefix{x}_{y}.png`, [size] pixels of [scale] map units, its
/// top-left at [origin] + (x, y) * size * scale. Used from zoom [from] on.
class MapTileSet {
  MapTileSet({
    required this.dir,
    required this.prefix,
    required this.origin,
    required this.scale,
    required this.size,
    required this.from,
    required this.have,
  }) : area = _areaOf(origin, size * scale, have);

  final String dir;
  final String prefix;
  final Offset origin;
  final double scale;
  final int size;
  final double from;
  final Set<String> have;

  /// What the tiles cover, in map units.
  final Rect area;

  double get span => size * scale;

  String? asset(int x, int y) => have.contains('${x}_$y') ? '$dir/$prefix${x}_$y.png' : null;

  static Rect _areaOf(Offset origin, double span, Set<String> have) {
    var mx = 0, my = 0;
    for (final h in have) {
      final xy = h.split('_');
      mx = int.parse(xy[0]) > mx ? int.parse(xy[0]) : mx;
      my = int.parse(xy[1]) > my ? int.parse(xy[1]) : my;
    }
    return Rect.fromLTWH(origin.dx, origin.dy, (mx + 1) * span, (my + 1) * span);
  }
}

class MapLandmark {
  const MapLandmark({required this.image, required this.position, required this.name, this.frames = 1});
  final String image;

  /// More than 1: [image] holds that many frames side by side (it moves).
  final int frames;

  /// Where the building stands (bottom centre of the picture).
  final Offset position;
  final LocalizedText name;
}

/// The schematic route map of one city (`assets/cities/<city>/map.json`,
/// built by tools/build_map.py). Flat map: straight / 45° lines on a pixel
/// terrain; only the landmarks are 3D pixel art.
class RouteMapData {
  RouteMapData({
    required this.size,
    required this.terrainImage,
    this.terrainOrigin = Offset.zero,
    this.terrainScale = 2,
    this.tileSets = const [],
    this.outer,
    required this.lines,
    required this.landmarks,
    required this.tips,
    this.decor = const [],
    this.glints = const [],
    this.areas = const {},
  });

  final Size size;
  final String terrainImage;

  /// Where the detailed terrain picture's top-left sits (map units) and map
  /// units per picture pixel. It covers the Tokyo area; the rest of Kanto is
  /// in [outer].
  final Offset terrainOrigin;
  final double terrainScale;

  /// Finer ground pictures in tiles, coarse to fine (all Kanto, then Tokyo):
  /// [terrainImage] is only a small overview for the far zooms.
  final List<MapTileSet> tileSets;

  /// The detailed Tokyo area (the finest tiles), or the overview's area.
  Rect get detailArea => tileSets.isEmpty
      ? terrainOrigin & Size(size.width, size.height)
      : tileSets.reduce((a, b) => a.scale <= b.scale ? a : b).area;

  /// Pale, coarse land and sea around the map: image, where its top-left
  /// sits in map units, and map units per pixel.
  final ({String image, Offset origin, double scale})? outer;
  final List<MapLine> lines;
  final List<MapLandmark> landmarks;

  /// Small scenery (trees, houses, boats), shown only when zoomed in:
  /// picture and the spot it stands on.
  final List<({String image, Offset position, int frames})> decor;

  /// Spots on open water where a little light glint twinkles.
  final List<Offset> glints;

  /// Neighbourhood (e.g. 銀座, may be missing) and ward / city (中央区) of each
  /// station, from OpenStreetMap.
  final Map<String, ({LocalizedText? town, LocalizedText? ward})> areas;

  /// 「銀座 · 中央区」 for the station card, or null when unknown.
  String? areaOf(String stationId, String lang) {
    final a = areas[stationId];
    if (a == null) return null;
    final parts = [?a.town?.of(lang), ?a.ward?.of(lang)];
    return parts.isEmpty ? null : parts.toSet().join(' · ');
  }

  /// Season for the scenery, by the date in Japan: cherry blossom from
  /// 20 March to 15 April, red maples from 10 November to 10 December.
  static String seasonOf(DateTime now) {
    final jp = now.toUtc().add(const Duration(hours: 9));
    final m = jp.month, d = jp.day;
    if ((m == 3 && d >= 20) || (m == 4 && d <= 15)) return 'spring';
    if ((m == 11 && d >= 10) || (m == 12 && d <= 10)) return 'autumn';
    return 'other';
  }

  /// Station hints (exits, transfers, nearby sights), by station id.
  final Map<String, List<LocalizedText>> tips;

  /// Every place a station is drawn (one per line it is on).
  late final List<MapStop> allStops = [for (final l in lines) ...l.stops.values];

  late final Map<String, List<MapStop>> _byStation = () {
    final out = <String, List<MapStop>>{};
    for (final s in allStops) {
      (out[s.stationId] ??= []).add(s);
    }
    return out;
  }();

  List<MapStop> stopsOf(String stationId) => _byStation[stationId] ?? const [];

  /// Each station once, with all its stops (in line order).
  Map<String, List<MapStop>> get stations => _byStation;

  /// Bounding box of everything drawn, for "show the whole map".
  ({Offset min, Offset max}) get contentBounds {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    void add(Offset p) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }

    for (final l in lines) {
      l.path.forEach(add);
    }
    for (final lm in landmarks) {
      add(lm.position);
      add(lm.position.translate(0, -70));
    }
    return (min: Offset(minX, minY), max: Offset(maxX, maxY));
  }

  static Offset _pt(Object? p) {
    if (p is List) {
      return Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
    }
    final m = p as Map<String, dynamic>;
    return Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
  }

  factory RouteMapData.fromJson(Map<String, dynamic> map, Map<String, dynamic> tips, {DateTime? now}) {
    final size = map['size'] as List;
    final season = seasonOf(now ?? DateTime.now());
    return RouteMapData(
      size: Size((size[0] as num).toDouble(), (size[1] as num).toDouble()),
      terrainImage: (map['terrain'] as Map<String, dynamic>)['image'] as String,
      terrainOrigin: switch ((map['terrain'] as Map<String, dynamic>)['origin']) {
        final List<dynamic> o => _pt(o),
        _ => Offset.zero,
      },
      terrainScale: ((map['terrain'] as Map<String, dynamic>)['scale'] as num? ?? 2).toDouble(),
      tileSets: [
        for (final t in ((map['terrain'] as Map<String, dynamic>)['sets'] as List? ?? const [])
            .cast<Map<String, dynamic>>())
          MapTileSet(
            dir: t['dir'] as String,
            prefix: t['prefix'] as String? ?? '',
            origin: _pt(t['origin']),
            scale: (t['scale'] as num).toDouble(),
            size: t['size'] as int,
            from: (t['from'] as num? ?? 0).toDouble(),
            have: {for (final h in t['have'] as List) h as String},
          ),
      ],
      outer: switch ((map['terrain'] as Map<String, dynamic>)['outer']) {
        final Map<String, dynamic> o => (
          image: o['image'] as String,
          origin: _pt(o['origin']),
          scale: (o['scale'] as num).toDouble(),
        ),
        _ => null,
      },
      lines: [
        for (final l in (map['lines'] as List).cast<Map<String, dynamic>>())
          MapLine(
            lineId: l['id'] as String,
            closed: l['closed'] as bool? ?? false,
            path: [for (final p in l['path'] as List) _pt(p)],
            stops: {
              for (final e in (l['stops'] as Map<String, dynamic>).entries)
                e.key: MapStop(
                  e.key,
                  _pt(e.value),
                  _side((e.value as Map<String, dynamic>)['label'] as String?),
                  l['id'] as String,
                ),
            },
          ),
      ],
      glints: [for (final g in map['glints'] as List? ?? const []) _pt(g)],
      decor: [
        for (final d in (map['decor'] as List? ?? const []).cast<Map<String, dynamic>>())
          (
            image: ((d['seasons'] as Map<String, dynamic>?)?[season] as String?) ?? d['image'] as String,
            position: _pt(d),
            frames: d['frames'] as int? ?? 1,
          ),
      ],
      landmarks: [
        for (final lm in (map['landmarks'] as List).cast<Map<String, dynamic>>())
          MapLandmark(
            image: lm['image'] as String,
            frames: lm['frames'] as int? ?? 1,
            position: _pt(lm),
            name: LocalizedText.fromJson(lm['name'] as Map<String, dynamic>),
          ),
      ],
      areas: {
        for (final e in (map['areas'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: (
            town: switch ((e.value as Map<String, dynamic>)['town']) {
              final Map<String, dynamic> t when (t['ja'] as String? ?? '').isNotEmpty => LocalizedText.fromJson(t),
              _ => null,
            },
            ward: switch ((e.value as Map<String, dynamic>)['ward']) {
              final Map<String, dynamic> t when (t['ja'] as String? ?? '').isNotEmpty => LocalizedText.fromJson(t),
              _ => null,
            },
          ),
      },
      tips: {
        for (final e in tips.entries)
          e.key: [for (final t in (e.value as List).cast<Map<String, dynamic>>()) LocalizedText.fromJson(t)],
      },
    );
  }

  static final _cache = <String, Future<RouteMapData>>{};

  static Future<RouteMapData> load(String cityId) => _cache[cityId] ??= () async {
    // Decoded off the UI thread (map.json is large).
    final map = await compute(jsonDecode, await rootBundle.loadString('assets/cities/$cityId/map.json'));
    Map<String, dynamic> tips = const {};
    try {
      tips = jsonDecode(await rootBundle.loadString('assets/cities/$cityId/tips.json')) as Map<String, dynamic>;
    } catch (_) {
      // No tips for this city yet.
    }
    return RouteMapData.fromJson(map as Map<String, dynamic>, tips);
  }();
}
