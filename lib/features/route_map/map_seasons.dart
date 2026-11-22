import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable, compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../../core/localized_text.dart';
import '../../data/models/route_map.dart';

/// Seasonal decorations on the route map (季節イベント), shown only in their
/// days in Japan: 初詣 crowds and a warm glow at the big shrines and temples,
/// cherry trees with drifting petals at the hanami spots, fireworks over the
/// fireworks festivals, red and golden trees in autumn and twinkling lights
/// for the winter illuminations. Spots: `assets/cities/<city>/seasons.json`.

/// What is drawn at a spot.
enum SeasonKind { shrine, temple, sakura, hanabi, momiji, icho, mixed, lights }

/// A season's days (month-day in Japan, both ends included).
class SeasonWindow {
  const SeasonWindow({required this.id, required this.from, required this.to, required this.name});

  final String id;
  final (int month, int day) from;
  final (int month, int day) to;
  final LocalizedText name;

  /// Is [jst] (a date in Japan) inside? Windows over New Year work too.
  bool contains(DateTime jst) {
    final d = jst.month * 100 + jst.day;
    final a = from.$1 * 100 + from.$2, b = to.$1 * 100 + to.$2;
    return a <= b ? d >= a && d <= b : d >= a || d <= b;
  }

  /// Can both be on the map on the same day?
  bool overlaps(SeasonWindow o) =>
      contains(DateTime(2001, o.from.$1, o.from.$2)) || o.contains(DateTime(2001, from.$1, from.$2));

  static (int, int) _md(String s) {
    final p = s.split('-');
    return (int.parse(p[0]), int.parse(p[1]));
  }

  factory SeasonWindow.fromJson(Map<String, dynamic> j) => SeasonWindow(
    id: j['id'] as String,
    from: _md(j['from'] as String),
    to: _md(j['to'] as String),
    name: LocalizedText.fromJson(j['name'] as Map<String, dynamic>),
  );
}

/// One seasonal place on the map.
class SeasonSpot {
  const SeasonSpot({
    required this.season,
    required this.kind,
    required this.name,
    required this.lat,
    required this.lng,
    required this.position,
    Offset? origin,
    this.onLandmark = false,
    this.count = 4,
    this.seed = 0,
    this.items,
    this.scale = 1,
    this.keepSize = true,
    this.clear = double.infinity,
    this.crowd,
    this.landmark,
  }) : origin = origin ?? position;

  final SeasonWindow season;
  final SeasonKind kind;
  final LocalizedText name;
  final double lat, lng;

  /// Where its pictures stand, in map units: the real place ([origin]) moved
  /// to the nearest room free of lines, stations and names ([SeasonPlacer]).
  final Offset position;

  /// The real place (by the landmark's picture when [onLandmark]).
  final Offset origin;

  /// A landmark picture already stands here (the trees and crowds gather round it).
  final bool onLandmark;

  /// That landmark's picture (asset path), if any.
  final String? landmark;

  /// Trees in the cluster (as asked for; fewer are drawn where room is tight).
  final int count;

  /// Fixed per spot: the layout and colours vary, but never between frames.
  final int seed;

  /// Where its trees (or little lit trees) stand, in map units from
  /// [position]; null = the usual layout ([SeasonPainter.treeSpots]).
  final List<Offset>? items;

  /// Its pictures drawn smaller (1 = full size) where room is tight.
  final double scale;

  /// Far out it may keep a readable size on screen (nothing near it);
  /// otherwise it shrinks with the map and is shown from a nearer zoom.
  final bool keepSize;

  /// Room round it free of lines and stations, in map units (for the glow).
  final double clear;

  /// 初詣: where the crowd and lanterns stand, in map units from [position].
  final Offset? crowd;

  /// 「お花見 · 上野恩賜公園」 for the snackbar.
  String label(String lang) => '${season.name.of(lang)} · ${name.of(lang)}';

  SeasonSpot placed({
    required Offset position,
    List<Offset>? items,
    double scale = 1,
    bool keepSize = false,
    double clear = double.infinity,
    Offset? crowd,
  }) => SeasonSpot(
    season: season,
    kind: kind,
    name: name,
    lat: lat,
    lng: lng,
    position: position,
    origin: origin,
    onLandmark: onLandmark,
    landmark: landmark,
    count: count,
    seed: seed,
    items: items,
    scale: scale,
    keepSize: keepSize,
    clear: clear,
    crowd: crowd,
  );
}

/// The map's projection from tools/build_map.py (each axis spread on its
/// own: wide in the centre, squeezed further out), then shifted by [origin].
class SeasonProjection {
  const SeasonProjection({
    this.center = const (35.686, 139.760),
    this.kmLng = 90.9,
    this.kmLat = 111.0,
    this.units = 150,
    this.power = 0.75,
    this.far = 30,
    this.soft = 0.15,
    this.origin = const Offset(-7575.606, -6899.726),
  });

  final (double lat, double lng) center;
  final double kmLng, kmLat, units, power, far, soft;
  final Offset origin;

  double _spread(double t) {
    final a = t.abs();
    final farRate = power * math.pow(far + soft, power - 1);
    final s = a <= far
        ? math.pow(a + soft, power) - math.pow(soft, power)
        : math.pow(far + soft, power) - math.pow(soft, power) + (a - far) * farRate;
    return (t < 0 ? -s : s) * units;
  }

  Offset toMap(double lat, double lng) =>
      Offset(_spread((lng - center.$2) * kmLng), _spread((center.$1 - lat) * kmLat)) - origin;

  factory SeasonProjection.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num).toDouble();
    final c = j['center'] as List, o = j['origin'] as List;
    return SeasonProjection(
      center: ((c[0] as num).toDouble(), (c[1] as num).toDouble()),
      kmLng: d('kmLng'),
      kmLat: d('kmLat'),
      units: d('units'),
      power: d('power'),
      far: d('far'),
      soft: d('soft'),
      origin: Offset((o[0] as num).toDouble(), (o[1] as num).toDouble()),
    );
  }
}

/// On-screen sizes of the map's lines and station dots at zoom [s], as the
/// map's overlay painter draws them (and as the seasonal pictures keep clear of).
double mapLineWidth(double s) => (5.5 * s).clamp(2.0, 7.0);
double mapStationRadius(double s) => (6.5 * s).clamp(2.2, 8.5);

/// Stations whose names are always shown, even fully zoomed out.
const mapMajorStations = {
  'tokyo.tokyo',
  'tokyo.shinjuku',
  'tokyo.shibuya',
  'tokyo.ikebukuro',
  'tokyo.shinagawa',
  'tokyo.ueno',
  'tokyo.asakusa',
  'tokyo.akihabara',
  'tokyo.ginza',
  'tokyo.shimbashi',
  'tokyo.kanda',
};

class _ObStation {
  _ObStation(this.id, this.pts, this.box, this.labelAt, this.side, this.ems);
  final String id;
  final List<Offset> pts;
  final Rect box;
  final Offset labelAt;
  final LabelSide side;

  /// Width of its name in ems (the widest of the app's languages).
  final double ems;
  bool get transfer => pts.length > 1;
  bool get major => mapMajorStations.contains(id);
}

/// What the seasonal pictures must not cover: the map's line strokes,
/// station dots and pills, station names (estimated boxes) and the landmark
/// and scenery pictures. Built once from the map; all in map units, sized
/// as drawn at a given zoom.
class MapObstacles {
  MapObstacles(RouteMapData map, {double Function(String stationId)? nameEms}) {
    for (final line in map.lines) {
      final pts = [...line.path, if (line.closed && line.path.isNotEmpty) line.path.first];
      for (var i = 0; i + 1 < pts.length; i++) {
        final a = pts[i], b = pts[i + 1];
        // Long runs in pieces, so each lies in few cells.
        final n = math.max(1, ((b - a).distance / _cell).ceil());
        for (var k = 0; k < n; k++) {
          final p = Offset.lerp(a, b, k / n)!, q = Offset.lerp(a, b, (k + 1) / n)!;
          _put(_segs, Rect.fromPoints(p, q), (p, q));
        }
      }
    }
    for (final MapEntry(key: id, value: stops) in map.stations.entries) {
      if (stops.isEmpty) continue;
      var box = Rect.fromPoints(stops.first.position, stops.first.position);
      for (final x in stops) {
        box = box.expandToInclude(Rect.fromPoints(x.position, x.position));
      }
      // As the overlay painter: a transfer station's name stands by its right-hand stop.
      final at = stops.length > 1
          ? stops.firstWhere((x) => x.label == LabelSide.right, orElse: () => stops.first)
          : stops.first;
      _put(
        _stations,
        box,
        _ObStation(id, [for (final x in stops) x.position], box, at.position, at.label, nameEms?.call(id) ?? 4),
      );
    }
    for (final lm in map.landmarks) {
      if (lm.giant) continue;
      final k = lm.ground ? lm.unit : 1.1, p = lm.position;
      final r = Rect.fromLTWH(p.dx - 26 * k, p.dy - 52 * k, 52 * k, 52 * k);
      _put(_solids, r, (r, lm.image));
    }
    for (final d in map.decor) {
      // (Seasonal trees may stand among the map's own trees.)
      if (RegExp(r'/(green|sakura|momiji)_').hasMatch(d.image)) continue;
      final r = Rect.fromLTWH(d.position.dx - 22, d.position.dy - 38, 44, 44);
      _put(_solids, r, (r, d.image));
    }
  }

  static const _cell = 128.0;
  final _segs = <int, List<(Offset, Offset)>>{};
  final _stations = <int, List<_ObStation>>{};
  final _solids = <int, List<(Rect, String)>>{};

  static void _put<T>(Map<int, List<T>> grid, Rect r, T v) {
    final x1 = (r.right / _cell).floor(), y1 = (r.bottom / _cell).floor();
    for (var x = (r.left / _cell).floor(); x <= x1; x++) {
      for (var y = (r.top / _cell).floor(); y <= y1; y++) {
        (grid[x * 100003 + y] ??= []).add(v);
      }
    }
  }

  static bool _any<T>(Map<int, List<T>> grid, Rect r, bool Function(T) test) {
    final x1 = (r.right / _cell).floor(), y1 = (r.bottom / _cell).floor();
    for (var x = (r.left / _cell).floor(); x <= x1; x++) {
      for (var y = (r.top / _cell).floor(); y <= y1; y++) {
        final l = grid[x * 100003 + y];
        if (l == null) continue;
        for (final v in l) {
          if (test(v)) return true;
        }
      }
    }
    return false;
  }

  /// Does segment [a]-[b] pass through [r]? (Liang-Barsky.)
  static bool segmentHitsRect(Offset a, Offset b, Rect r) {
    var t0 = 0.0, t1 = 1.0;
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    bool clip(double p, double q) {
      if (p == 0) return q >= 0;
      final t = q / p;
      if (p < 0) {
        if (t > t1) return false;
        if (t > t0) t0 = t;
      } else {
        if (t < t0) return false;
        if (t < t1) t1 = t;
      }
      return true;
    }

    return clip(-dx, a.dx - r.left) && clip(dx, r.right - a.dx) && clip(-dy, a.dy - r.top) && clip(dy, r.bottom - a.dy);
  }

  static double _cross(Offset o, Offset a, Offset b) => (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);

  static double _toSegment(Offset p, Offset a, Offset b) {
    final ab = b - a, l2 = ab.distanceSquared;
    if (l2 == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / l2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  static double _toRect(Offset p, Rect r) {
    final dx = math.max(math.max(r.left - p.dx, p.dx - r.right), 0.0);
    final dy = math.max(math.max(r.top - p.dy, p.dy - r.bottom), 0.0);
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Is a line within [pad] of [r]?
  bool linesHit(Rect r, double pad) {
    final q = r.inflate(pad);
    return _any(_segs, q, (seg) => segmentHitsRect(seg.$1, seg.$2, q));
  }

  /// Does the straight way from [a] to [b] cross a line?
  bool crosses(Offset a, Offset b) => _any(_segs, Rect.fromPoints(a, b), (seg) {
    final (c, d) = seg;
    return _cross(a, b, c) * _cross(a, b, d) < 0 && _cross(c, d, a) * _cross(c, d, b) < 0;
  });

  /// A station's dot is drawn at zoom [s] (far out only transfer stations, then only the big ones).
  static bool _dotShown(_ObStation st, double s) => !(s < 0.3 && !st.transfer) && !(s < 0.12 && !st.major);

  /// Is a station dot or pill, as drawn at zoom [s], within [pad] of [r]?
  bool stationsHit(Rect r, double s, [double pad = 0]) {
    final rad = (mapStationRadius(s) + 1.5) / s + pad, pill = (mapStationRadius(s) + 3.5) / s + pad;
    return _any(_stations, r.inflate(pill), (st) {
      if (!_dotShown(st, s)) return false;
      if (st.transfer) return st.box.inflate(pill).overlaps(r);
      return _toRect(st.pts.first, r) < rad;
    });
  }

  /// A station's name is drawn at zoom [s] (when there is room for it).
  static bool _nameShown(_ObStation st, double s) => st.major || s >= (st.transfer ? 0.32 : 0.6);

  /// Where the station's name is drawn at zoom [s] (an estimate from the
  /// name's length; the overlay painter lays the real text out the same way).
  static Rect _labelRect(_ObStation st, double s) {
    final font = (11 + 7 * (s - 0.4)).clamp(11.0, 19.0) * (st.major ? 1.15 : 1);
    final gap = mapStationRadius(s) + (st.transfer ? 10 : 6);
    final w = st.ems * font + 4, main = font * 1.3 + 4, h = main + (s > 0.9 ? font * 0.8 : 0);
    final r = switch (st.side) {
      LabelSide.right => Rect.fromLTWH(gap - 2, -main / 2, w, h),
      LabelSide.left => Rect.fromLTWH(-gap - w + 2, -main / 2, w, h),
      LabelSide.top => Rect.fromLTWH(-w / 2, -gap - h + 2, w, h),
      LabelSide.bottom => Rect.fromLTWH(-w / 2, gap - 2, w, h),
    };
    return Rect.fromLTRB(r.left / s, r.top / s, r.right / s, r.bottom / s).shift(st.labelAt);
  }

  /// The station names shown at zoom [s] that reach into [window].
  List<Rect> labelsIn(Rect window, double s, {bool onlyMajor = false}) {
    final out = <Rect>{};
    // A name reaches up to about 14 ems from its stop.
    _any(_stations, window.inflate((14 * 22 + 20) / s), (st) {
      if (onlyMajor && !st.major || !_nameShown(st, s)) return false;
      final r = _labelRect(st, s);
      if (r.overlaps(window)) out.add(r);
      return false;
    });
    return out.toList();
  }

  /// Is a landmark or scenery picture on [r]? ([except]: that picture is fine.)
  bool solidsHit(Rect r, {String? except}) => _any(_solids, r, (v) => v.$2 != except && v.$1.overlaps(r));

  /// Does a picture box [r] keep clear of the lines, station dots and names
  /// as drawn at zoom [s]? Names count from the zoom the scenery reads at;
  /// further out only the big stations' names, which are always shown.
  bool clearAt(Rect r, double s, {bool names = true}) =>
      !linesHit(r, mapLineWidth(s) / 2 / s) &&
      !stationsHit(r, s) &&
      !(names && labelsIn(r, s, onlyMajor: s < namesFrom).isNotEmpty);

  /// From this zoom on the pictures keep clear of every station name shown.
  static const namesFrom = 0.6;

  /// Free room round [p] at zoom [s]: how far to the nearest line stroke or
  /// station dot, up to [max].
  double clearance(Offset p, double max, double s) {
    var best = max;
    final half = mapLineWidth(s) / 2 / s, rad = (mapStationRadius(s) + 1.5) / s;
    final pill = (mapStationRadius(s) + 3.5) / s;
    final q = Rect.fromCircle(center: p, radius: max);
    _any(_segs, q, (seg) {
      best = math.min(best, _toSegment(p, seg.$1, seg.$2) - half);
      return false;
    });
    _any(_stations, q.inflate(pill), (st) {
      if (!_dotShown(st, s)) return false;
      best = math.min(best, st.transfer ? _toRect(p, st.box.inflate(pill)) : (p - st.pts.first).distance - rad);
      return false;
    });
    return math.max(best, 0);
  }
}

/// Finds each seasonal spot room on the map: the nearest place to its real
/// position where its pictures cover no line, station or name at any zoom
/// they are shown at, with fewer or smaller pictures where room is tight.
/// One placer per group of seasons that can be on the map together: later
/// spots also keep clear of the earlier ones.
class SeasonPlacer {
  SeasonPlacer(this.ob);
  final MapObstacles ob;
  final _taken = <Rect>[];

  /// A spot that shrinks with the map starts to show just above this zoom.
  static const lowZoom = 0.225;

  /// Zooms the placement is checked at (the pictures and the names change size between them).
  static const zooms = [0.3, 0.45, 0.6, 0.8, 1.0, 1.4, 2.0, 4.0];

  /// Far-out zooms a spot that keeps its size on screen must be clear at too.
  static const farZooms = [0.115, 0.16, lowZoom, 0.26];

  static const _step = 8.0;

  /// Cells round the real place, nearest first.
  static final _rings = <int, List<(int, int, double)>>{};
  static List<(int, int, double)> _ring(double radius) => _rings[radius.round()] ??= () {
    final n = (radius / _step).floor();
    return [
      for (var x = -n; x <= n; x++)
        for (var y = -n; y <= n; y++)
          if (math.sqrt(x * x + y * y) * _step <= radius) (x, y, math.sqrt(x * x + y * y) * _step),
    ]..sort((a, b) => a.$3.compareTo(b.$3));
  }();

  /// Cells of a cluster round its first tree, nearest first (clusters are wider than deep).
  static final _clump = () {
    double e(int x, int y) => math.sqrt(x * x + (y / 0.62) * (y / 0.62));
    return [
      for (var x = -11; x <= 11; x++)
        for (var y = -7; y <= 7; y++)
          if ((x != 0 || y != 0) && e(x, y) * _step <= 88) (x, y, e(x, y) * _step),
    ]..sort((a, b) => a.$3.compareTo(b.$3));
  }();

  /// Names near the spot at each zoom (kept while one spot is placed), and all of them.
  Map<double, List<Rect>> _namesAt = const {};
  List<Rect> _names = const [];

  void _collectNames(Offset origin) {
    final window = Rect.fromCircle(center: origin, radius: 420);
    _namesAt = {
      for (final z in [...farZooms, ...zooms]) z: ob.labelsIn(window, z, onlyMajor: z < MapObstacles.namesFrom),
    };
    _names = [for (final z in _all) ..._namesAt[z]!];
  }

  /// Quick test of a picture box at its usual size (the exact test at every zoom is [clear]).
  bool _free(Rect box, {String? except}) {
    if (ob.linesHit(box, mapLineWidth(lowZoom) / 2 / lowZoom + 1)) return false;
    if (ob.stationsHit(box, lowZoom, 1) || ob.stationsHit(box, 0.3, 1)) return false;
    for (final r in _names) {
      if (r.overlaps(box)) return false;
    }
    for (final r in _taken) {
      if (r.overlaps(box)) return false;
    }
    return !ob.solidsHit(box, except: except);
  }

  /// Exact: every picture of [c], as drawn at each zoom of [at], is clear.
  bool clear(SeasonSpot c, List<double> at) {
    for (final z in at) {
      final names = _namesAt[z]!;
      for (final box in SeasonPainter.boxes(c, z)) {
        final r = box.inflate(1);
        if (!ob.clearAt(r, z, names: false) || names.any(r.overlaps)) return false;
      }
    }
    return true;
  }

  static const _all = [lowZoom, ...zooms];

  SeasonSpot place(SeasonSpot spot) {
    _collectNames(spot.origin);
    var c = switch (spot.kind) {
      SeasonKind.sakura ||
      SeasonKind.momiji ||
      SeasonKind.icho ||
      SeasonKind.mixed => spot.onLandmark ? _treesRound(spot) : _trees(spot),
      SeasonKind.lights => _lights(spot),
      SeasonKind.shrine || SeasonKind.temple => _shrine(spot),
      SeasonKind.hanabi => _fireworks(spot),
    };
    // Nothing near it even far out (the countryside): it may keep its size on screen there.
    final keep = _with(c, keepSize: true);
    if (clear(keep, farZooms)) c = keep;
    // Room for the glow on the ground.
    final glowAt = switch (c.kind) {
      SeasonKind.shrine || SeasonKind.temple => c.onLandmark ? c.origin : c.position.translate(0, -16 * c.scale),
      _ => c.position,
    };
    c = _with(c, clearRoom: ob.clearance(glowAt, 140, c.keepSize ? farZooms.first : lowZoom));
    _taken.addAll([for (final r in SeasonPainter.boxes(c, 0.6)) r.inflate(4)]);
    return c;
  }

  static SeasonSpot _with(SeasonSpot c, {bool? keepSize, double? clearRoom}) => c.placed(
    position: c.position,
    items: c.items,
    scale: c.scale,
    keepSize: keepSize ?? c.keepSize,
    clear: clearRoom ?? c.clear,
    crowd: c.crowd,
  );

  /// The nearest place to the real one, within [radius], where [fits]
  /// (trying each size of [sizes] = (scale, cost) and taking the cheapest:
  /// distance + cost).
  SeasonSpot? _nearest(
    SeasonSpot spot,
    List<(double, double)> sizes,
    (SeasonSpot, double)? Function(Offset at, double k) fits,
  ) => _within(spot, near, sizes, fits) ?? _within(spot, far, sizes, fits);

  /// How far from its real place a spot may stand, in map units (about
  /// 600 m in central Tokyo): smaller or fewer pictures come before a longer
  /// move, and only a spot with no room at all goes as far as [far].
  static const near = 90.0, far = 170.0;

  SeasonSpot? _within(
    SeasonSpot spot,
    double radius,
    List<(double, double)> sizes,
    (SeasonSpot, double)? Function(Offset at, double k) fits,
  ) {
    SeasonSpot? best;
    var bestCost = double.infinity;
    for (final (k, pen) in sizes) {
      for (final (x, y, d) in _ring(radius)) {
        if (d + pen >= bestCost) break;
        final got = fits(spot.origin + Offset(x * _step, y * _step), k);
        if (got == null) continue;
        final cost = d + pen + got.$2;
        if (cost < bestCost && clear(got.$1, _all)) {
          best = got.$1;
          bestCost = cost;
        }
      }
    }
    return best;
  }

  static Rect _treeBox(Offset base, double k) =>
      Rect.fromLTRB(base.dx - 32 * k, base.dy - 48 * k, base.dx + 32 * k, base.dy + 16 * k).inflate(1);

  /// A cluster of trees: the first tree as near the real place as it fits,
  /// the others packed round it wherever each has room.
  SeasonSpot _trees(SeasonSpot spot) =>
      _treesWithin(spot, near) ??
      _treesWithin(spot, far) ??
      spot.placed(position: spot.origin, items: const [], scale: 0.5);

  SeasonSpot? _treesWithin(SeasonSpot spot, double radius) {
    SeasonSpot? best;
    var bestCost = double.infinity;
    for (final (k, pen) in const [(1.0, 0.0), (0.8, 12.0), (0.65, 30.0), (0.5, 55.0)]) {
      final memo = <int, bool>{};
      bool free(int x, int y) =>
          memo[(x + 512) * 1024 + y + 512] ??= _free(_treeBox(spot.origin + Offset(x * _step, y * _step), k));
      final gap = 36 * k;
      for (final (x, y, d) in _ring(radius)) {
        if (d + pen >= bestCost) break;
        if (!free(x, y)) continue;
        final at = spot.origin + Offset(x * _step, y * _step);
        final chosen = <(int, int)>[(0, 0)];
        for (final (jx, jy, e) in _clump) {
          if (chosen.length >= spot.count || e > 88 * k + 8) break;
          if (chosen.any((c) {
            final dx = (c.$1 - jx) * _step, dy = (c.$2 - jy) * _step / 0.62;
            return dx * dx + dy * dy < gap * gap;
          })) {
            continue;
          }
          if (!free(x + jx, y + jy)) continue;
          chosen.add((jx, jy));
        }
        // Fewer trees cost a little; a lone tree where a grove was asked for costs more.
        final cost = d + pen + 14.0 * (spot.count - chosen.length) + (chosen.length < math.min(2, spot.count) ? 40 : 0);
        if (cost >= bestCost) continue;
        final c = spot.placed(
          position: at,
          items: [for (final (jx, jy) in chosen) Offset(jx * _step, jy * _step)]..sort((a, b) => a.dy.compareTo(b.dy)),
          scale: k,
        );
        if (!clear(c, _all)) continue;
        best = c;
        bestCost = cost;
      }
    }
    return best;
  }

  /// Trees round a landmark: each as near its usual place in the ring as it fits.
  SeasonSpot _treesRound(SeasonSpot spot) {
    SeasonSpot? best;
    var bestCost = double.infinity;
    for (final (k, pen) in const [(1.0, 0.0), (0.8, 12.0), (0.65, 30.0), (0.5, 55.0)]) {
      final chosen = <Offset>[];
      var moved = 0.0;
      for (final want in SeasonPainter.treeSpots(spot)) {
        for (final (x, y, d) in _ring(64)) {
          final off = want + Offset(x * _step, y * _step);
          // Not on the landmark's own picture.
          if (math.sqrt(off.dx * off.dx + (off.dy / 0.62) * (off.dy / 0.62)) < 66) continue;
          if (chosen.any((c) => (c - off).distance < 36 * k)) continue;
          if (!_free(_treeBox(spot.origin + off, k), except: spot.landmark)) continue;
          chosen.add(off);
          moved += d;
          break;
        }
      }
      final cost = pen + 14.0 * (spot.count - chosen.length) + (chosen.isEmpty ? 80 : moved / chosen.length);
      if (cost >= bestCost) continue;
      final c = spot.placed(position: spot.origin, items: chosen..sort((a, b) => a.dy.compareTo(b.dy)), scale: k);
      if (!clear(c, _all)) continue;
      best = c;
      bestCost = cost;
    }
    return best ?? spot.placed(position: spot.origin, items: const [], scale: 0.65);
  }

  /// The big fir where it fits, and those of its avenue trees that do.
  SeasonSpot _lights(SeasonSpot spot) {
    final avenue = SeasonPainter.avenue(spot.seed);
    return _nearest(spot, const [(1.0, 0.0), (0.8, 20.0), (0.65, 45.0), (0.5, 70.0)], (at, k) {
          // The fir, and the way down to its foot.
          if (!_free(Rect.fromLTRB(at.dx - 20 * k, at.dy - 58 * k, at.dx + 20 * k, at.dy))) return null;
          final items = <Offset>[];
          for (final o in avenue) {
            final p = at + o * k;
            if (_free(Rect.fromCircle(center: p, radius: 7 * k)) &&
                _free(Rect.fromCircle(center: at + o * (k / 2), radius: 7 * k)) &&
                !ob.crosses(at, p)) {
              items.add(o * k);
            }
          }
          return (spot.placed(position: at, items: items, scale: k), 5.0 * (avenue.length - items.length));
        }) ??
        spot.placed(position: spot.origin, items: const [], scale: 0.5);
  }

  static const _crowdSizes = [(1.0, 0.0), (0.8, 20.0), (0.65, 45.0), (0.5, 70.0)];

  /// The lanterns and the crowd under them, hung from [o].
  static List<Rect> _crowdBoxes(Offset o, double k) {
    final q = 1.5 * k;
    return [
      Rect.fromLTRB(o.dx - 19 * q, o.dy - 2 * q, o.dx + 19 * q, o.dy + 3.5 * q).inflate(1),
      Rect.fromLTRB(o.dx - 15.5 * q, o.dy + 3 * q, o.dx + 15.5 * q, o.dy + 15.5 * q).inflate(1),
    ];
  }

  SeasonSpot _shrine(SeasonSpot spot) {
    if (!spot.onLandmark) {
      // The little shrine with its crowd in front, as one group.
      return _nearest(spot, _crowdSizes, (at, k) {
            if (!_free(_treeBox(at, k))) return null;
            final crowd = Offset(0, 6 * k);
            if (_crowdBoxes(at + crowd, k).any((r) => !_free(r))) return null;
            return (spot.placed(position: at, scale: k, crowd: crowd), 0.0);
          }) ??
          spot.placed(position: spot.origin, scale: 0.5, crowd: Offset.infinite);
    }
    // By a landmark: the far-out gate icon near it, and the crowd in front of it.
    final icon =
        _nearest(spot, _crowdSizes, (at, k) {
          final box = Rect.fromLTRB(at.dx - 27 * k, at.dy - 42 * k, at.dx + 27 * k, at.dy + 6 * k);
          if (!_free(box, except: spot.landmark)) return null;
          return (spot.placed(position: at, scale: k, crowd: Offset.infinite), 0.0);
        }) ??
        spot.placed(position: spot.origin, scale: 0.65, crowd: Offset.infinite);
    for (final (k, _) in _crowdSizes) {
      if (k > icon.scale) continue;
      for (final (x, y, _) in _ring(120)) {
        final o = spot.origin + Offset(x * _step, y * _step + 2);
        if (_crowdBoxes(o, k).any((r) => !_free(r))) continue;
        final c = icon.placed(position: icon.position, scale: k, crowd: o - icon.position);
        if (clear(c, _all)) return c;
      }
    }
    return icon;
  }

  /// The (day) fireworks picture over the river: smaller where the map is crowded.
  SeasonSpot _fireworks(SeasonSpot spot) =>
      _nearest(spot, const [(1.0, 0.0), (0.75, 14.0), (0.55, 32.0), (0.4, 50.0), (0.3, 65.0), (0.22, 85.0)], (at, k) {
        final c = spot.placed(position: at, scale: k);
        if (SeasonPainter.boxes(c, 0.6).any((r) => !_free(r))) return null;
        return (c, 0.0);
      }) ??
      spot.placed(position: spot.origin, scale: 0.22);
}

/// All the seasons and their spots of one city.
class MapSeasons {
  MapSeasons({this.seasons = const [], List<SeasonSpot> spots = const [], this.obstacles}) : _raw = spots;

  static final empty = MapSeasons();

  final List<SeasonWindow> seasons;

  /// The spots at their real places, and (with the map) what they must keep clear of.
  final List<SeasonSpot> _raw;
  final MapObstacles? obstacles;

  /// Each spot with room found for it on the map, worked out once, a group
  /// of seasons at a time when one of them is first shown.
  late final List<SeasonSpot?> _placed = List.filled(_raw.length, null);

  void _place(bool Function(SeasonWindow) wanted) {
    final ob = obstacles;
    for (final first in seasons) {
      if (!wanted(first)) continue;
      // The seasons that can be on the map together with it.
      final group = <SeasonWindow>{first};
      for (var grew = true; grew;) {
        grew = false;
        for (final s in seasons) {
          if (!group.contains(s) && group.any((g) => g.overlaps(s))) grew = group.add(s);
        }
      }
      SeasonPlacer? placer;
      for (var i = 0; i < _raw.length; i++) {
        if (_placed[i] != null || !group.contains(_raw[i].season)) continue;
        _placed[i] = ob == null ? _raw[i] : (placer ??= SeasonPlacer(ob)).place(_raw[i]);
      }
    }
  }

  /// Every spot of every season.
  List<SeasonSpot> get spots {
    _place((_) => true);
    return [for (var i = 0; i < _raw.length; i++) _placed[i] ?? _raw[i]];
  }

  /// The pictures the painter may need (small; all loaded with the map).
  static const images = [
    'assets/art/map_decor/sakura_a.png',
    'assets/art/map_decor/sakura_b.png',
    'assets/art/map_decor/sakura_c.png',
    'assets/art/map_decor/momiji_a.png',
    'assets/art/map_decor/momiji_b.png',
    'assets/art/map_decor/momiji_c.png',
    'assets/art/map_seasons/icho_a.webp',
    'assets/art/map_seasons/icho_b.webp',
    'assets/art/map_decor/shrine_a.png',
    'assets/art/map_decor/temple_a.png',
  ];

  /// Landmark pictures with cherry trees in them, for the rest of the year:
  /// the same picture with the trees in summer green and in autumn colours
  /// (tools/make_landmark_seasons.py).
  static const _greenArt = {
    'assets/art/landmarks/ueno.png': 'assets/art/map_seasons/ueno_green.webp',
    'assets/art/landmarks/chureito.png': 'assets/art/map_seasons/chureito_green.webp',
  };
  static const _koyoArt = {
    'assets/art/landmarks/ueno.png': 'assets/art/map_seasons/ueno_koyo.webp',
    'assets/art/landmarks/chureito.png': 'assets/art/map_seasons/chureito_koyo.webp',
  };

  /// Every such picture (loaded with the map).
  static final landmarkArt = [..._greenArt.values, ..._koyoArt.values];

  /// Which landmark pictures are drawn with another one at [now] (picture →
  /// picture): none while the cherry trees bloom, the autumn ones while the
  /// leaves are red, the green ones otherwise - the same days as the map's
  /// own trees change ([RouteMapData.seasonOf]).
  static Map<String, String> landmarkArtAt(DateTime now) => switch (RouteMapData.seasonOf(now)) {
    'spring' => const {},
    'autumn' => _koyoArt,
    _ => _greenArt,
  };

  /// [landmarks]: the map's landmarks, for spots that stand by one. With
  /// [map] every spot is moved clear of the map's lines, stations and names
  /// ([nameEms]: how wide a station's name is, in ems).
  factory MapSeasons.fromJson(
    Map<String, dynamic> json, {
    List<MapLandmark> landmarks = const [],
    RouteMapData? map,
    double Function(String stationId)? nameEms,
  }) {
    if (map != null) landmarks = map.landmarks;
    final proj = json['projection'] is Map<String, dynamic>
        ? SeasonProjection.fromJson(json['projection'] as Map<String, dynamic>)
        : const SeasonProjection();
    final seasons = [for (final s in (json['seasons'] as List).cast<Map<String, dynamic>>()) SeasonWindow.fromJson(s)];
    final byId = {for (final s in seasons) s.id: s};
    final spots = <SeasonSpot>[];
    for (final j in (json['spots'] as List).cast<Map<String, dynamic>>()) {
      final season = byId[j['season']];
      if (season == null) continue;
      final lat = (j['lat'] as num).toDouble(), lng = (j['lng'] as num).toDouble();
      final lmName = j['landmark'] as String?;
      final lm = lmName == null
          ? null
          : landmarks.where((l) => l.image.endsWith('/$lmName.png') || l.image.endsWith('/$lmName.webp')).firstOrNull;
      final name = LocalizedText.fromJson(j['name'] as Map<String, dynamic>);
      spots.add(
        SeasonSpot(
          season: season,
          kind: SeasonKind.values.byName(j['kind'] as String),
          name: name,
          lat: lat,
          lng: lng,
          position: lm?.position ?? proj.toMap(lat, lng),
          onLandmark: lm != null,
          landmark: lm?.image,
          count: j['count'] as int? ?? 4,
          seed: _hash('${name.ja}${season.id}'),
        ),
      );
    }
    return MapSeasons(
      seasons: seasons,
      spots: spots,
      obstacles: map == null ? null : MapObstacles(map, nameEms: nameEms),
    );
  }

  /// Small stable hash (String.hashCode may differ between runs).
  static int _hash(String s) {
    var h = 17;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return h;
  }

  static final _cache = <String, Future<MapSeasons>>{};

  /// The city's seasons (none when it has no seasons.json).
  /// Room for every spot is found off the UI thread ([nameEms]: how wide
  /// each station's name is on the map, in ems, by station id).
  static Future<MapSeasons> load(String cityId, RouteMapData map, {Map<String, double> nameEms = const {}}) =>
      _cache[cityId] ??= () async {
        try {
          final raw = await rootBundle.loadString('assets/cities/$cityId/seasons.json');
          try {
            return await compute(_placeAll, (raw, map, nameEms));
          } catch (_) {
            // No second isolate here: work it out in place.
            return _placeAll((raw, map, nameEms));
          }
        } catch (_) {
          return empty;
        }
      }();

  static MapSeasons _placeAll((String, RouteMapData, Map<String, double>) a) {
    final all = MapSeasons.fromJson(
      jsonDecode(a.$1) as Map<String, dynamic>,
      map: a.$2,
      nameEms: (id) => a.$3[id] ?? 4,
    );
    // Only the placed spots go back (not the grid they were placed with).
    return MapSeasons(seasons: all.seasons, spots: all.spots);
  }

  /// The date in Japan.
  static DateTime japan(DateTime now) => now.toUtc().add(const Duration(hours: 9));

  /// For previews on a device: `--dart-define=MAP_SEASON_DATE=2026-04-01`.
  static const _forced = String.fromEnvironment('MAP_SEASON_DATE');

  /// Now (or the forced preview day, at noon in Japan).
  static DateTime now() {
    final f = DateTime.tryParse(_forced);
    return f == null ? DateTime.now() : DateTime.utc(f.year, f.month, f.day, 3);
  }

  List<SeasonWindow> activeAt(DateTime now) {
    final jst = japan(now);
    return [
      for (final s in seasons)
        if (s.contains(jst)) s,
    ];
  }

  /// The spots shown at [now], each where it has room on the map.
  List<SeasonSpot> spotsAt(DateTime now) {
    final jst = japan(now);
    if (!seasons.any((s) => s.contains(jst))) return const [];
    _place((s) => s.contains(jst));
    return [
      for (var i = 0; i < _raw.length; i++)
        if (_raw[i].season.contains(jst)) _placed[i] ?? _raw[i],
    ];
  }
}

/// A tap [px] screen pixels from the nearest station at zoom [s] opens that
/// station: always when on or right by its dot; within a finger's reach of
/// it too, unless the finger is exactly on a seasonal picture ([onPicture];
/// the pictures never lie on a dot, so there the two do not compete).
bool stationWinsTap(double px, double s, {bool onPicture = false}) => px < (onPicture ? mapStationRadius(s) + 8 : 26);

/// The seasonal spot under [screen]: on one of its pictures (with a finger's
/// slack, or none when [exact]), or within a finger's reach of its middle;
/// null when none.
SeasonSpot? seasonSpotAt(List<SeasonSpot> spots, Matrix4 m, Offset screen, {bool exact = false}) {
  final s = m.storage[0];
  final world = MatrixUtils.transformPoint(Matrix4.inverted(m), screen);
  SeasonSpot? best;
  var bestD = 30.0;
  for (final spot in spots) {
    if (SeasonPainter.fadeOf(spot, s) <= 0) continue;
    final p = MatrixUtils.transformPoint(m, spot.position);
    var d = exact ? double.infinity : (p - screen).distance;
    if (spot.kind == SeasonKind.hanabi && !exact) {
      // The bursts are up in the sky above the river.
      d = math.min(d, (p.translate(0, -SeasonPainter.burstRadius(s) * spot.scale * 1.25) - screen).distance);
    }
    for (final box in SeasonPainter.boxes(spot, s)) {
      if (box.inflate(exact ? 0 : 8 / s).contains(world)) d = math.min(d, (box.center - world).distance * s * 0.5);
    }
    if (d < bestD) {
      bestD = d;
      best = spot;
    }
  }
  return best;
}

/// Draws the seasonal spots, in screen space like the moving scenery; repaints
/// with the map and the clock. Two layers: the ground one (glows, trees,
/// crowds, lights) lies under the lines and landmarks; the [sky] one
/// (fireworks, drifting petals) above them, below the names. Every picture
/// of the ground layer stays inside the spot's [boxes], which [SeasonPlacer]
/// keeps clear of the lines, stations and names.
class SeasonPainter extends CustomPainter {
  SeasonPainter({
    required this.spots,
    required this.images,
    required this.matrix,
    required this.clock,
    this.night = false,
    this.still = false,
    this.sky = false,
  }) : super(repaint: Listenable.merge([matrix, clock]));

  final List<SeasonSpot> spots;
  final Map<String, ui.Image> images;
  final ValueListenable<Matrix4> matrix;

  /// 0..1 over a few seconds, repeating (the map's twinkle clock).
  final Animation<double> clock;
  final bool night;

  /// Reduce motion: no petals or bursts moving, fireworks stay small icons.
  final bool still;

  /// The layer above the lines: fireworks and petals only.
  final bool sky;

  /// Is there anything for the [sky] layer among [spots]?
  static bool hasSky(List<SeasonSpot> spots) =>
      spots.any((s) => s.kind == SeasonKind.hanabi || s.kind == SeasonKind.sakura);

  /// Shown from a little before the Tokyo overview; gone with all of Kanto on screen.
  static double fadeAt(double s) => ((s - 0.11) / 0.09).clamp(0.0, 1.0);

  /// [fadeAt] for a spot that keeps its size far out; one in a crowded part
  /// of the map shrinks with the map instead and comes in a little nearer.
  static double fadeOf(SeasonSpot spot, double s) =>
      spot.keepSize ? fadeAt(s) : ((s - SeasonPlacer.lowZoom) / (0.3 - SeasonPlacer.lowZoom)).clamp(0.0, 1.0);

  /// Fireworks burst radius on screen.
  static double burstRadius(double s) => (130 * s).clamp(14.0, 80.0);

  static double _burstOf(SeasonSpot spot, double s) =>
      spot.scale * (spot.keepSize ? burstRadius(s) : math.min(130 * s, 80.0));

  /// Scenery dimmed at night (as the moving scenery layer).
  static const _nightTone = ColorFilter.matrix([
    0.55, 0, 0, 0, 6, //
    0, 0.55, 0, 0, 8,
    0.1, 0, 0.62, 0, 22,
    0, 0, 0, 1, 0,
  ]);

  static double _rnd(int seed, int i) {
    final x = math.sin(seed * 0.0137 + i * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  // ---------------- sizes (shared by the drawing, the placement and taps) ----------------

  /// Sprite pixels on screen: the scenery's size (2 map units a pixel),
  /// kept from getting too small far out, where it has the room, so the
  /// spot still reads.
  static double _treePx(SeasonSpot spot, double s) => 2 * spot.scale * (spot.keepSize ? math.max(s, 0.3) : s);

  /// One pixel of the far-out gate icon.
  static double _gateUnit(SeasonSpot spot, double s) =>
      1.6 * spot.scale * (spot.keepSize ? 1 : math.min(1.0, s / 0.45));

  /// The gate icon gives way to the shrine picture (or the landmark) over this zoom.
  static double _near(double s) => ((s - 0.42) / 0.2).clamp(0.0, 1.0);

  /// One pixel of the 初詣 crowd, and how strongly it shows.
  static double _crowdUnit(SeasonSpot spot, double s) => (1.5 * s).clamp(0.8, 3.0) * spot.scale;
  static double _crowdAlpha(double s) => ((s - 0.5) / 0.15).clamp(0.0, 1.0);
  static Offset _crowdAt(SeasonSpot spot) => spot.crowd ?? Offset(0, spot.onLandmark ? 1.5 : 6);

  /// Screen pixels per layout unit of the illuminations, and one pixel of their drawing.
  static double _lightsG(SeasonSpot spot, double s) =>
      spot.scale * (spot.keepSize ? s.clamp(0.36, 1.5) : math.min(s, 1.5));
  static double _lightsU(SeasonSpot spot, double g) => spot.keepSize ? (3 * g).clamp(1.5, 4.0) : math.min(3 * g, 4.0);

  /// The lit street trees of an illumination, from its middle: an avenue
  /// leaning like the map's streets.
  static List<Offset> avenue(int seed) {
    final lean = _rnd(seed, 1) < 0.5 ? -1 : 1;
    return [
      for (var j = 0; j < 6; j++)
        for (final side in const [-1, 1])
          if (j != 2 && j != 3 || side > 0) Offset((j - 2.5) * 17.0, 20 + lean * (j - 2.5) * 5.0 + side * 9.0),
    ];
  }

  /// Everything the ground layer draws for [spot] at zoom [s] (and the day
  /// fireworks picture), as boxes in map units: its trees, shrine, crowd,
  /// fir and lit trees. Soft glows on the ground are held inside
  /// [SeasonSpot.clear] instead; fireworks bursting at night and falling
  /// petals are in the air and not counted.
  static List<Rect> boxes(SeasonSpot spot, double s) {
    final out = <Rect>[];
    // In screen pixels from where [from] (map units from the spot) is on screen.
    void add(double l, double t, double r, double b, [Offset from = Offset.zero]) =>
        out.add(Rect.fromLTRB(l / s, t / s, r / s, b / s).shift(spot.position + from));
    switch (spot.kind) {
      case SeasonKind.sakura || SeasonKind.momiji || SeasonKind.icho || SeasonKind.mixed:
        final px = _treePx(spot, s);
        for (final o in spot.items ?? treeSpots(spot)) {
          add(-16 * px, -24 * px, 16 * px, 8 * px, o);
        }
      case SeasonKind.shrine || SeasonKind.temple:
        final near = _near(s);
        if (near < 1) {
          final u = _gateUnit(spot, s);
          add(-7.5 * u, -11.5 * u, 7.5 * u, 1.5 * u);
        }
        if (near > 0 && !spot.onLandmark) {
          final px = _treePx(spot, s);
          add(-16 * px, -24 * px, 16 * px, 8 * px);
        }
        final at = _crowdAt(spot);
        if (_crowdAlpha(s) > 0 && at.isFinite) {
          final q = _crowdUnit(spot, s);
          add(-19 * q, -2 * q, 19 * q, 3.5 * q, at);
          add(-15.5 * q, 3 * q, 15.5 * q, 15.5 * q, at);
        }
      case SeasonKind.lights:
        final g = _lightsG(spot, s), u = _lightsU(spot, g);
        add(-6.5 * u, -18 * g - 13 * u, 6.5 * u, -18 * g + 2.5 * u);
        for (final o in spot.items ?? avenue(spot.seed)) {
          final c = o * (g / spot.scale);
          add(c.dx - 2 * u, c.dy - 2 * u, c.dx + 2 * u, c.dy + 2 * u);
        }
      case SeasonKind.hanabi:
        final r = _burstOf(spot, s);
        // (Half a spark more on every side.)
        final e = (r / 26).clamp(1.5, 4.0) / 2 + 0.25, f = (r * 0.32 / 13).clamp(1.5, 4.0) / 2 + 0.25;
        add(-0.5 * r - e, -1.25 * r - e, 0.5 * r + e, -0.25 * r + e);
        add(0.18 * r - f, -0.87 * r - f, 0.82 * r + f, -0.23 * r + f);
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final m = matrix.value;
    final s = m.storage[0];
    if (fadeAt(s) <= 0 || spots.isEmpty) return;
    Offset sp(Offset w) => MatrixUtils.transformPoint(m, w);
    final inv = Matrix4.inverted(m);
    final view = Rect.fromPoints(
      MatrixUtils.transformPoint(inv, Offset.zero),
      MatrixUtils.transformPoint(inv, Offset(size.width, size.height)),
    ).inflate(200 / s);
    final t = still ? 0.0 : clock.value;
    for (final spot in spots) {
      if (!view.contains(spot.position)) continue;
      final fade = fadeOf(spot, s);
      if (fade <= 0) continue;
      if (sky) {
        if (spot.kind == SeasonKind.sakura && !still) _petals(canvas, spot, s, sp, t);
        if (spot.kind == SeasonKind.hanabi) _fireworks(canvas, spot, s, sp, fade, t);
        continue;
      }
      switch (spot.kind) {
        case SeasonKind.shrine || SeasonKind.temple:
          _hatsumode(canvas, spot, s, sp, fade, t);
        case SeasonKind.sakura || SeasonKind.momiji || SeasonKind.icho || SeasonKind.mixed:
          _trees(canvas, spot, s, sp, fade);
        case SeasonKind.lights:
          _lights(canvas, spot, s, sp, fade, t);
        case SeasonKind.hanabi:
          break;
      }
    }
  }

  // ---------------- trees (sakura, momiji, ginkgo) ----------------

  List<String> _treeImages(SeasonKind k) => switch (k) {
    SeasonKind.sakura => const [
      'assets/art/map_decor/sakura_a.png',
      'assets/art/map_decor/sakura_b.png',
      'assets/art/map_decor/sakura_c.png',
    ],
    SeasonKind.icho => const ['assets/art/map_seasons/icho_a.webp', 'assets/art/map_seasons/icho_b.webp'],
    SeasonKind.mixed => const [
      'assets/art/map_decor/momiji_a.png',
      'assets/art/map_seasons/icho_a.webp',
      'assets/art/map_decor/momiji_b.png',
      'assets/art/map_seasons/icho_b.webp',
    ],
    _ => const [
      'assets/art/map_decor/momiji_a.png',
      'assets/art/map_decor/momiji_b.png',
      'assets/art/map_decor/momiji_c.png',
    ],
  };

  /// Where the trees of a cluster stand when nothing is in their way, in
  /// map units from the spot (round a landmark: a ring, leaving its picture
  /// clear). On the map [SeasonSpot.items] says where they found room.
  static List<Offset> treeSpots(SeasonSpot spot) {
    final out = <Offset>[];
    for (var i = 0; i < spot.count; i++) {
      final a = spot.seed * 0.7 + i * 2.39996;
      final r = spot.onLandmark ? 78 + 22 * math.sqrt(i) : (i == 0 ? 0 : 30 + 22 * math.sqrt(i));
      out.add(Offset(math.cos(a) * r, math.sin(a) * r * 0.62));
    }
    return out..sort((a, b) => a.dy.compareTo(b.dy));
  }

  void _trees(Canvas canvas, SeasonSpot spot, double s, Offset Function(Offset) sp, double fade) {
    final names = _treeImages(spot.kind);
    final px = _treePx(spot, s);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..color = Color.fromRGBO(0, 0, 0, fade);
    if (night) paint.colorFilter = _nightTone;
    final c = sp(spot.position);
    final at = spot.items ?? treeSpots(spot);
    // A soft blush on the ground under each tree (pink / gold / warm red),
    // inside the tree's own room so it never lies on a line or a station.
    final tint = switch (spot.kind) {
      SeasonKind.sakura => const Color(0xFFFFB7CF),
      SeasonKind.icho => const Color(0xFFFFD75E),
      _ => const Color(0xFFFF8A5B),
    };
    final blush = Paint()
      ..color = tint.withValues(alpha: (night ? 0.16 : 0.3) * fade)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.6, px));
    for (final o in at) {
      canvas.drawOval(Rect.fromCenter(center: (c + o * s).translate(0, px), width: 22 * px, height: 7 * px), blush);
    }
    for (var i = 0; i < at.length; i++) {
      final img = images[names[(spot.seed + i) % names.length]];
      if (img == null) continue;
      final p = c + at[i] * s;
      final w = img.width * px, h = img.height * px;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(p.dx - w / 2, p.dy - h * 0.75, w, h),
        paint,
      );
    }
  }

  /// A few petals drifting down over the cherry trees (zoomed in only).
  void _petals(Canvas canvas, SeasonSpot spot, double s, Offset Function(Offset) sp, double t) {
    final a = ((s - 0.55) / 0.25).clamp(0.0, 1.0);
    if (a <= 0) return;
    final c = sp(spot.position);
    final q = (2.6 * s).clamp(2.0, 4.5);
    final paint = Paint();
    final at = spot.items ?? treeSpots(spot);
    if (at.isEmpty) return;
    final n = 6 + at.length * 2;
    // Over the trees, wherever they found room.
    var reach = 0.0;
    for (final o in at) {
      reach = math.max(reach, o.dx.abs());
    }
    reach = (reach + 24 * spot.scale) * s;
    for (var j = 0; j < n; j++) {
      final speed = 1 + (j % 3);
      final ph = (t * speed + _rnd(spot.seed, j)) % 1.0;
      final x0 = (_rnd(spot.seed, j + 40) - 0.5) * 2 * reach;
      final y = -80 * s + ph * 130 * s;
      final x = x0 + math.sin((ph * 2 + _rnd(spot.seed, j + 80)) * math.pi * 2) * 9 * s + ph * 14 * s;
      final al = math.min(1.0, math.sin(ph * math.pi) * 1.8) * a;
      paint.color =
          (j % 3 == 0 ? const Color(0xFFFFF4F8) : (j.isEven ? const Color(0xFFFF6FA3) : const Color(0xFFEE4F8A)))
              .withValues(alpha: al * (night ? 0.7 : 0.95));
      final p = c.translate(x, y);
      // A petal turning as it falls: wide, then narrow.
      final wide = ((ph * 6 + j) % 2) < 1;
      canvas.drawRect(Rect.fromLTWH(p.dx, p.dy, q * (wide ? 1.6 : 0.9), q * (wide ? 0.9 : 1.4)), paint);
    }
  }

  // ---------------- 初詣 ----------------

  void _hatsumode(Canvas canvas, SeasonSpot spot, double s, Offset Function(Offset) sp, double fade, double t) {
    final c = sp(spot.position);
    // Warm glow round the shrine, breathing slowly (lanterns and bonfires):
    // as wide as the room free of lines and stations round it.
    final r = math.min((130 * s).clamp(spot.keepSize ? 16.0 : 0.0, 100.0), spot.clear * s);
    final pulse = 0.85 + 0.15 * math.sin(t * math.pi * 4);
    final glowAt = spot.onLandmark ? sp(spot.origin) : sp(spot.position.translate(0, -16 * spot.scale));
    if (r > 2) {
      canvas.drawCircle(
        glowAt,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            glowAt,
            r,
            [
              const Color(0xFFFFC060).withValues(alpha: (night ? 0.6 : 0.5) * fade * pulse),
              const Color(0xFFFF8A4A).withValues(alpha: (night ? 0.25 : 0.18) * fade * pulse),
              const Color(0x00FF8A4A),
            ],
            const [0, 0.5, 1],
          ),
      );
    }
    // Far out: a small red torii (or temple gate) icon. Zoomed in: the
    // landmark picture, or the map's own little shrine / temple where no
    // landmark stands.
    final near = _near(s);
    if (near < 1) _gateIcon(canvas, c, spot.kind == SeasonKind.temple, fade * (1 - near), _gateUnit(spot, s));
    final img =
        images[spot.kind == SeasonKind.temple
            ? 'assets/art/map_decor/temple_a.png'
            : 'assets/art/map_decor/shrine_a.png'];
    if (img != null && !spot.onLandmark && near > 0) {
      final px = _treePx(spot, s);
      final w = img.width * px, h = img.height * px;
      final paint = Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(0, 0, 0, fade * near);
      if (night) paint.colorFilter = _nightTone;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(c.dx - w / 2, c.dy - h * 0.75, w, h),
        paint,
      );
    }
    final ca = _crowdAlpha(s) * fade, crowdAt = _crowdAt(spot);
    if (ca <= 0 || !crowdAt.isFinite) return;
    final q = _crowdUnit(spot, s);
    final paint = Paint();
    // A string of red paper lanterns over the approach, lit at night.
    final o = c + crowdAt * s;
    final ly = o.dy;
    for (var i = 0; i < 7; i++) {
      final x = o.dx + (i - 3) * 6 * q;
      final sag = (1 - math.pow((i - 3) / 3, 2)) * 2 * q;
      final at = Offset(x, ly + sag);
      if (night) {
        canvas.drawCircle(
          at,
          q * 3,
          Paint()
            ..color = const Color(0xFFFFB347).withValues(alpha: 0.35 * ca)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, q * 2),
        );
      }
      paint.color = (night ? const Color(0xFFFF6A4A) : const Color(0xFFD83A34)).withValues(alpha: ca);
      canvas.drawRect(Rect.fromCenter(center: at, width: 2 * q, height: 3 * q), paint);
      paint.color = const Color(0xFF2A2230).withValues(alpha: ca);
      canvas.drawRect(Rect.fromCenter(center: at.translate(0, -1.75 * q), width: 2 * q, height: q * 0.5), paint);
    }
    // The crowd on the approach, in furisode and winter coats, bobbing a little.
    const coats = [
      Color(0xFFD6334A), // red furisode
      Color(0xFF2B3A67), // navy coat
      Color(0xFFF2EDE4), // white
      Color(0xFFE58FB0), // pink
      Color(0xFF6B4A3A), // brown
      Color(0xFF3F7A5C), // green
      Color(0xFFE8A33A), // mustard
    ];
    final skin = (night ? const Color(0xFFB89A86) : const Color(0xFFF3CBA5)).withValues(alpha: ca);
    final hair = const Color(0xFF2A2230).withValues(alpha: ca);
    final top = ly + 6 * q;
    for (var i = 0; i < 13; i++) {
      final row = i < 7 ? 0 : 1;
      final col = row == 0 ? i : i - 7;
      final x = (col - (row == 0 ? 3 : 2.5)) * 4.5 * q + (_rnd(spot.seed, i + 60) - 0.5) * q;
      final y = top + row * 6 * q;
      final bob = !still && math.sin((t * 6 + _rnd(spot.seed, i)) * math.pi * 2) > 0.75 ? -q : 0.0;
      final at = Offset(o.dx + x, y + bob);
      var coat = coats[(spot.seed + i * 5) % coats.length];
      if (night) coat = Color.lerp(coat, const Color(0xFF1C2238), 0.35)!;
      paint.color = coat.withValues(alpha: ca);
      canvas.drawRect(Rect.fromLTWH(at.dx - 1.5 * q, at.dy, 3 * q, 3.5 * q), paint); // body
      paint.color = skin;
      canvas.drawRect(Rect.fromLTWH(at.dx - q, at.dy - 2 * q, 2 * q, 2 * q), paint); // face
      paint.color = hair;
      canvas.drawRect(Rect.fromLTWH(at.dx - q, at.dy - 2 * q, 2 * q, q), paint); // hair
    }
  }

  /// A crisp pixel torii (shrine) or temple gate, standing on [at].
  void _gateIcon(Canvas canvas, Offset at, bool temple, double alpha, double u) {
    if (alpha <= 0) return;
    final o = Offset((at.dx / u).roundToDouble() * u, (at.dy / u).roundToDouble() * u);
    final paint = Paint();
    void px(double x, double y, double w, double h, Color c) {
      paint.color = c.withValues(alpha: alpha);
      canvas.drawRect(Rect.fromLTWH(o.dx + x * u, o.dy + y * u, w * u, h * u), paint);
    }

    const ink = Color(0xFF3A2228);
    if (temple) {
      // Grey tiled roof over a red gate with a dark doorway.
      px(-6, -10, 12, 1, ink);
      px(-5, -9, 10, 2, const Color(0xFF59606E));
      px(-6, -9, 1, 1, const Color(0xFF59606E));
      px(5, -9, 1, 1, const Color(0xFF59606E));
      px(-5, -7, 10, 1, ink);
      px(-4, -6, 8, 6, const Color(0xFFD8352A));
      px(-1, -4, 2, 4, ink);
      px(-5, 0, 10, 1, ink);
      return;
    }
    // Torii: the upturned top beam, the tie beam and two pillars.
    px(-6, -10, 12, 1, ink);
    px(-7, -11, 2, 1, ink);
    px(5, -11, 2, 1, ink);
    px(-5, -9, 10, 1, const Color(0xFFE2402F));
    px(-4, -7, 8, 1, const Color(0xFFE2402F));
    px(-4, -8, 8, 1, ink);
    px(-3, -8, 2, 8, const Color(0xFFE2402F));
    px(1, -8, 2, 8, const Color(0xFFE2402F));
    px(-3, -1, 2, 1, ink);
    px(1, -1, 2, 1, ink);
  }

  // ---------------- イルミネーション ----------------

  /// Light palettes: champagne gold, blue and white, colourful.
  static const _lightSets = [
    [Color(0xFFFFD86B), Color(0xFFFFF3C4), Color(0xFFFFB347)],
    [Color(0xFF7CC8FF), Color(0xFFE4F4FF), Color(0xFFA9C4FF)],
    [Color(0xFFFF6B6B), Color(0xFFFFD86B), Color(0xFF7CE0A0), Color(0xFF7CC8FF)],
  ];

  void _lights(Canvas canvas, SeasonSpot spot, double s, Offset Function(Offset) sp, double fade, double t) {
    final c = sp(spot.position);
    final g = _lightsG(spot, s); // screen px per layout unit
    final colors = _lightSets[spot.seed % _lightSets.length];
    final paint = Paint();
    final u = _lightsU(spot, g); // one pixel of the drawing
    Offset snap(Offset p) => Offset((p.dx / u).roundToDouble() * u, (p.dy / u).roundToDouble() * u);

    // An avenue of lit street trees (those that found room), leaning like the map's streets.
    final trees = [for (final o in spot.items ?? avenue(spot.seed)) o * (g / spot.scale)];
    if (night) {
      // The glow on the ground, as wide as the room free of lines and stations.
      final rx = math.min(75 * g, spot.clear * s), ry = math.min(60 * g, spot.clear * s * 0.8);
      if (rx > 3) {
        canvas.drawOval(
          Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
          Paint()
            ..color = colors.first.withValues(alpha: 0.28 * fade)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, rx * 0.35),
        );
      }
    }
    for (var i = 0; i < trees.length; i++) {
      final p = snap(c + trees[i]);
      final col = colors[i % colors.length];
      final tw = 0.6 + 0.4 * math.sin((t * 3 + i * 0.618) * math.pi * 2);
      if (night) {
        canvas.drawCircle(
          p,
          u * 2.4,
          Paint()
            ..color = col.withValues(alpha: 0.75 * tw * fade)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 1.4),
        );
        paint.color = Color.lerp(col, const Color(0xFFFFFFFF), 0.5)!.withValues(alpha: tw * fade);
        canvas.drawRect(Rect.fromCenter(center: p, width: u * 2, height: u * 2), paint);
      } else {
        // By day: little round trees hung with lights.
        paint.color = const Color(0xFF3E7A4E).withValues(alpha: fade);
        canvas.drawRect(Rect.fromCenter(center: p, width: u * 3, height: u * 2), paint);
        canvas.drawRect(Rect.fromCenter(center: p, width: u * 2, height: u * 3), paint);
        paint.color = col.withValues(alpha: (0.8 + 0.2 * tw) * fade);
        canvas.drawRect(Rect.fromLTWH(p.dx - u, p.dy - u, u, u), paint);
        canvas.drawRect(Rect.fromLTWH(p.dx, p.dy, u, u), paint);
      }
    }

    // A big Christmas tree in the middle: a stepped pixel fir, covered in lights.
    const steps = [(1, 0), (3, 1), (3, 2), (5, 3), (5, 4), (7, 5), (7, 6), (9, 7), (9, 8), (11, 9)];
    final top = snap(c.translate(0, -18 * g - steps.length * u));
    final fir = (night ? const Color(0xFF1E3B33) : const Color(0xFF2E6B47)).withValues(alpha: fade);
    final edge = const Color(0xFF173226).withValues(alpha: fade);
    for (final (w, row) in steps) {
      paint.color = edge;
      canvas.drawRect(Rect.fromLTWH(top.dx - (w / 2 + 0.5) * u, top.dy + row * u, (w + 1) * u, u), paint);
    }
    for (final (w, row) in steps) {
      paint.color = fir;
      canvas.drawRect(Rect.fromLTWH(top.dx - w / 2 * u, top.dy + row * u, w * u, u), paint);
    }
    paint.color = const Color(0xFF6B4A3A).withValues(alpha: fade);
    canvas.drawRect(Rect.fromLTWH(top.dx - u, top.dy + steps.length * u, 2 * u, 2 * u), paint);
    // Its lights: a few twinkling dots along the rows.
    var k = 0;
    for (final (w, row) in steps.skip(1)) {
      for (var j = 0; j < w; j += 2) {
        if ((row + j) % 3 == 0) continue;
        k++;
        final col = colors[k % colors.length];
        final tw = 0.5 + 0.5 * math.sin((t * 4 + k * 0.618) * math.pi * 2);
        final p = Offset(top.dx + (j - (w - 1) / 2) * u, top.dy + (row + 0.5) * u);
        if (night) {
          canvas.drawCircle(
            p,
            u * 1.4,
            Paint()
              ..color = col.withValues(alpha: 0.5 * tw * fade)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, u),
          );
        }
        paint.color = col.withValues(alpha: (night ? 0.5 + 0.5 * tw : 0.75 + 0.25 * tw) * fade);
        canvas.drawRect(Rect.fromCenter(center: p, width: u, height: u), paint);
      }
    }
    // The star on top.
    final star = top.translate(0, -u);
    final sa = (0.75 + 0.25 * math.sin(t * math.pi * 6)) * fade;
    if (night) {
      canvas.drawCircle(
        star,
        u * 3,
        Paint()
          ..color = const Color(0xFFFFE27A).withValues(alpha: 0.5 * sa)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 2),
      );
    }
    paint.color = const Color(0xFFFFE27A).withValues(alpha: sa);
    canvas.drawRect(Rect.fromCenter(center: star, width: u * 3, height: u), paint);
    canvas.drawRect(Rect.fromCenter(center: star, width: u, height: u * 3), paint);
  }

  // ---------------- 花火 ----------------

  static const _fireColors = [
    Color(0xFFFF5A6E),
    Color(0xFFFFD45A),
    Color(0xFF6FE3FF),
    Color(0xFFFF8AD8),
    Color(0xFF8CFF8A),
    Color(0xFFC9A2FF),
    Color(0xFFFFA24A),
  ];

  /// Deeper colours for the still icons on the pale day map.
  static const _dayColors = [
    Color(0xFFE5304A),
    Color(0xFFF08C00),
    Color(0xFF1F8FE0),
    Color(0xFFD63AAF),
    Color(0xFF2FA84F),
    Color(0xFF7B4FE0),
  ];

  void _fireworks(Canvas canvas, SeasonSpot spot, double s, Offset Function(Offset) sp, double fade, double t) {
    final base = sp(spot.position);
    final r = _burstOf(spot, s);
    if (!night || still) {
      // By day (or without motion): a small still fireworks icon.
      final at = base.translate(0, -r * 0.75);
      final cs = night ? _fireColors : _dayColors;
      _burst(canvas, at, r * 0.5, 1, cs[spot.seed % cs.length], cs[(spot.seed + 3) % cs.length], fade, glow: night);
      _burst(
        canvas,
        at.translate(r * 0.5, r * 0.2),
        r * 0.32,
        1,
        cs[(spot.seed + 1) % cs.length],
        cs[(spot.seed + 4) % cs.length],
        fade,
        glow: night,
      );
      return;
    }
    // At night: three shells in turn, each 3 s: up, burst, fade and droop.
    for (var b = 0; b < 3; b++) {
      final run = t * 2 + b / 3 + _rnd(spot.seed, 7);
      final ph = run % 1.0;
      final shot = run.floor() * 3 + b;
      final dx = (_rnd(spot.seed, shot + 11) - 0.5) * r * 1.5;
      final hi = r * (1.1 + _rnd(spot.seed, shot + 23) * 0.6);
      final at = base.translate(dx, -hi);
      final size = r * (0.65 + _rnd(spot.seed, shot + 31) * 0.4);
      final c1 = _fireColors[(spot.seed + shot * 3) % 7], c2 = _fireColors[(spot.seed + shot * 5 + 2) % 7];
      const rise = 0.2;
      if (ph < rise) {
        // The shell going up: a short trail of sparks.
        final k = ph / rise;
        final p = Offset.lerp(base.translate(dx * 0.7, 0), at, Curves.easeOut.transform(k))!;
        final q = (size / 18).clamp(1.5, 3.0);
        for (var i = 0; i < 4; i++) {
          canvas.drawRect(
            Rect.fromCenter(center: p.translate(0, i * q * 1.8), width: q, height: q),
            Paint()..color = const Color(0xFFFFF0C0).withValues(alpha: fade * (1 - i * 0.24)),
          );
        }
        continue;
      }
      _burst(canvas, at, size, (ph - rise) / (1 - rise), c1, c2, fade, glow: true);
    }
  }

  /// One firework at expansion [e] (0 = just burst, 1 = still, fully open).
  void _burst(Canvas canvas, Offset at, double size, double e, Color c1, Color c2, double fade, {bool glow = false}) {
    final open = e >= 1;
    final grow = open ? 1.0 : 1 - math.pow(1 - math.min(e * 1.4, 1.0), 3).toDouble();
    final rad = size * grow;
    // Full for a while, then fading out while the sparks droop.
    final alpha = (open ? 1.0 : (e < 0.45 ? 1.0 : math.pow(1 - (e - 0.45) / 0.55, 1.5).toDouble())) * fade;
    final droop = open ? 0.0 : size * 0.3 * e * e;
    final q = (size / 13).clamp(1.5, 4.0);
    if (glow) {
      canvas.drawCircle(
        at.translate(0, droop * 0.5),
        rad + 3,
        Paint()
          ..color = c1.withValues(alpha: 0.3 * alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.45 + 3),
      );
    }
    final paint = Paint();
    const n = 20;
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2;
      final dir = Offset(math.cos(a), math.sin(a));
      // Each spark with a tail back towards the centre.
      for (var k = 0; k < 3; k++) {
        final f = 1 - k * 0.13;
        paint.color = (k == 0 && e < 0.3 && !open ? Color.lerp(c1, const Color(0xFFFFFFFF), 0.6)! : c1).withValues(
          alpha: alpha * (1 - k * 0.3),
        );
        final w = q * (1 - k * 0.2);
        canvas.drawRect(
          Rect.fromCenter(center: at + dir * (rad * f) + Offset(0, droop * f), width: w, height: w),
          paint,
        );
      }
    }
    for (var i = 0; i < 10; i++) {
      final a = (i + 0.5) / 10 * math.pi * 2;
      paint.color = c2.withValues(alpha: alpha);
      canvas.drawRect(
        Rect.fromCenter(
          center: at + Offset(math.cos(a), math.sin(a)) * (rad * 0.5) + Offset(0, droop * 0.6),
          width: q,
          height: q,
        ),
        paint,
      );
    }
    paint.color = c2.withValues(alpha: alpha);
    canvas.drawRect(Rect.fromCenter(center: at.translate(0, droop * 0.4), width: q, height: q), paint);
    if (!open && e < 0.1) {
      paint.color = const Color(0xFFFFFFFF).withValues(alpha: (1 - e / 0.1) * fade);
      canvas.drawCircle(at, q * 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(SeasonPainter old) =>
      old.spots != spots ||
      old.night != night ||
      old.still != still ||
      old.sky != sky ||
      old.images.length != images.length;
}
