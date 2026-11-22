import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../data/models/city.dart';
import '../../data/models/rail_line.dart';
import '../../data/models/route_map.dart';
import '../../data/models/timetable.dart';
import '../trip/route_finder.dart';

/// A drawn line as a polyline measured along its length: points at a
/// distance, the direction there, and pieces between two stations.
class LineGeo {
  LineGeo._(this._pts, this._cum, this.closed);

  final List<Offset> _pts;
  final List<double> _cum;
  final bool closed;

  /// Distance along the line of each station on it.
  final stopAt = <String, double>{};

  double get length => _cum.last;

  static final _cache = Expando<LineGeo>();

  static LineGeo of(MapLine line) => _cache[line] ??= () {
    final pts = [...line.path];
    if (line.closed && pts.length > 1 && pts.first != pts.last) pts.add(pts.first);
    final cum = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum.last + (pts[i] - pts[i - 1]).distance);
    }
    final g = LineGeo._(pts, cum, line.closed);
    for (final e in line.stops.entries) {
      g.stopAt[e.key] = g.project(e.value.position);
    }
    return g;
  }();

  /// Distance along the line of the point on it nearest to [p].
  double project(Offset p) {
    var best = double.infinity, at = 0.0;
    for (var i = 1; i < _pts.length; i++) {
      final a = _pts[i - 1], d = _pts[i] - a;
      final len2 = d.dx * d.dx + d.dy * d.dy;
      final t = len2 == 0 ? 0.0 : (((p.dx - a.dx) * d.dx + (p.dy - a.dy) * d.dy) / len2).clamp(0.0, 1.0);
      final q = a + d * t;
      final dist = (q - p).distanceSquared;
      if (dist < best) {
        best = dist;
        at = _cum[i - 1] + t * (_cum[i] - _cum[i - 1]);
      }
    }
    return at;
  }

  double _wrap(double s) {
    if (closed) {
      final r = s % length;
      return r < 0 ? r + length : r;
    }
    return s.clamp(0.0, length);
  }

  int _seg(double s) {
    var lo = 0, hi = _cum.length - 2;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_cum[mid] <= s) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// The point at distance [s] (wrapped round a loop, clamped otherwise).
  Offset at(double s) {
    if (_pts.length < 2) return _pts.first;
    s = _wrap(s);
    final i = _seg(s);
    final len = _cum[i + 1] - _cum[i];
    final t = len == 0 ? 0.0 : (s - _cum[i]) / len;
    return Offset.lerp(_pts[i], _pts[i + 1], t)!;
  }

  /// Unit direction (towards growing distance) round [s], smoothed over
  /// [span] so trains turn gently through the 45° bends.
  Offset dirAt(double s, double span) {
    var d = at(s + span) - at(s - span);
    if (d.distance < 1e-6) {
      final i = _seg(_wrap(s));
      d = _pts[i + 1] - _pts[i];
    }
    final n = d.distance;
    return n == 0 ? const Offset(1, 0) : d / n;
  }

  /// Signed distance from [a] to [b]; round a loop the shorter way.
  double delta(double a, double b) {
    var d = b - a;
    if (closed) {
      if (d > length / 2) d -= length;
      if (d < -length / 2) d += length;
    }
    return d;
  }

  /// Box round the stretch from [a] to [a] + [d] (bends included).
  Rect boxOf(double a, double d) {
    var box = Rect.fromPoints(at(a), at(a + d));
    final lo = math.min(a, a + d), hi = math.max(a, a + d);
    for (var j = 0; j < _cum.length; j++) {
      for (final k in closed ? const [-1, 0, 1] : const [0]) {
        final v = _cum[j] + k * length;
        if (v > lo && v < hi) box = box.expandToInclude(Rect.fromPoints(_pts[j], _pts[j]));
      }
    }
    return box.inflate(1);
  }

  /// Adds the stretch from [a] to [a] + [d] to [path] (bends included).
  void addTo(Path path, double a, double d, {required bool start}) {
    final p0 = at(a);
    if (start) {
      path.moveTo(p0.dx, p0.dy);
    } else {
      path.lineTo(p0.dx, p0.dy);
    }
    final lo = math.min(a, a + d), hi = math.max(a, a + d);
    final bends = <double>[];
    for (var j = 0; j < _cum.length; j++) {
      for (final k in closed ? const [-1, 0, 1] : const [0]) {
        final v = _cum[j] + k * length;
        if (v > lo && v < hi) bends.add(v);
      }
    }
    bends.sort();
    for (final v in d >= 0 ? bends : bends.reversed) {
      final q = at(v);
      path.lineTo(q.dx, q.dy);
    }
    final p1 = at(a + d);
    path.lineTo(p1.dx, p1.dy);
  }
}

// ---------------- the chosen route on the map ----------------

/// Where the route's legs run on the map (map units), its stations and the
/// walks between stations, built once per route.
class RouteOnMap {
  RouteOnMap._(this.legs, this.walks, this.stops, this.bounds);

  /// One path per leg, with the line it rides.
  final List<({String lineId, Path path})> legs;

  /// Walks between two stations (上野 → 京成上野).
  final List<(Offset, Offset)> walks;

  /// Start, changes and destination: station, where, and what it is.
  final List<({String stationId, Offset at, RouteStopKind kind})> stops;
  final Rect bounds;

  static RouteOnMap? build(RouteMapData map, CityData city, RouteResult route) {
    final byLine = {for (final l in map.lines) l.lineId: l};
    Offset? posOf(String station, String lineId) =>
        byLine[lineId]?.stops[station]?.position ?? map.stopsOf(station).firstOrNull?.position;
    final legs = <({String lineId, Path path})>[];
    final walks = <(Offset, Offset)>[];
    final stops = <({String stationId, Offset at, RouteStopKind kind})>[];
    Rect? box;
    void grow(Offset p) =>
        box = (box ?? Rect.fromCircle(center: p, radius: 1)).expandToInclude(Rect.fromCircle(center: p, radius: 1));
    for (var li = 0; li < route.legs.length; li++) {
      final leg = route.legs[li];
      final line = byLine[leg.lineId];
      final geo = line == null ? null : LineGeo.of(line);
      final path = Path();
      var started = false;
      for (var i = 1; i < leg.stationIds.length; i++) {
        final a = leg.stationIds[i - 1], b = leg.stationIds[i];
        final sa = geo?.stopAt[a], sb = geo?.stopAt[b];
        if (geo != null && sa != null && sb != null) {
          geo.addTo(path, sa, geo.delta(sa, sb), start: !started);
        } else {
          final pa = posOf(a, leg.lineId), pb = posOf(b, leg.lineId);
          if (pa == null || pb == null) continue;
          if (!started) path.moveTo(pa.dx, pa.dy);
          path.lineTo(pb.dx, pb.dy);
        }
        started = true;
      }
      if (started) {
        legs.add((lineId: leg.lineId, path: path));
        final r = path.getBounds();
        grow(r.topLeft);
        grow(r.bottomRight);
      }
      final first = leg.stationIds.first;
      if (li == 0) {
        final p = posOf(first, leg.lineId);
        if (p != null) stops.add((stationId: first, at: p, kind: RouteStopKind.start));
      } else {
        final prevEnd = route.legs[li - 1].stationIds.last;
        final p = posOf(first, leg.lineId), q = posOf(prevEnd, route.legs[li - 1].lineId);
        if (prevEnd != first && p != null && q != null) walks.add((q, p));
        if (!leg.through && p != null) stops.add((stationId: first, at: p, kind: RouteStopKind.change));
      }
    }
    final last = route.legs.last;
    final end = posOf(last.stationIds.last, last.lineId);
    if (end != null) stops.add((stationId: last.stationIds.last, at: end, kind: RouteStopKind.end));
    if (box == null) return null;
    return RouteOnMap._(legs, walks, stops, box!);
  }
}

enum RouteStopKind { start, change, end }

// ---------------- trains running on the lines ----------------

/// Lines with short trains: trams, people movers, monorails, one-car lines.
const _oneCar = {
  'tokyo.toden_arakawa',
  'tokyo.tokyu_setagaya',
  'tokyo.isumi',
  'tokyo.kominato',
  'tokyo.choshi_dentetsu',
  'tokyo.hitachinaka',
  'tokyo.mooka',
  'tokyo.kururi',
  'tokyo.karasuyama',
  'tokyo.koumi',
  'tokyo.kanto_ryugasaki',
  'tokyo.watarase',
  'tokyo.yamaman',
  'tokyo.disney_resort_line',
};
const _twoCars = {
  'tokyo.enoden',
  'tokyo.yurikamome',
  'tokyo.nippori_toneri',
  'tokyo.new_shuttle',
  'tokyo.seaside_line',
  'tokyo.tokyo_monorail',
  'tokyo.tama_monorail',
  'tokyo.chiba_monorail_1',
  'tokyo.chiba_monorail_2',
  'tokyo.shonan_monorail',
  'tokyo.kanto_joso',
  'tokyo.hakone_tozan',
  'tokyo.izuhakone_daiyuzan',
  'tokyo.izuhakone_sunzu',
  'tokyo.tobu_kameido',
  'tokyo.tobu_daishi',
  'tokyo.keikyu_daishi',
  'tokyo.ryutetsu',
};

/// One line's timings (forward = the line's station order): seconds from
/// leaving the first station to reaching / leaving each station.
class LineRun {
  LineRun(this.line, this.mapLine, this.geo, this.arc, this.arrive, this.depart, this.total);

  final RailLine line;
  final MapLine mapLine;
  final LineGeo geo;
  final List<double> arc;
  final List<int> arrive;
  final List<int> depart;

  /// Seconds end to end (a loop: once round).
  final int total;

  /// Box round the line between stop i and stop i + 1 (map units): a train
  /// on a stretch off screen is skipped without working out where it is.
  late final List<Rect> stretch = [
    for (var i = 0; i + 1 < arc.length; i++) geo.boxOf(arc[i], geo.delta(arc[i], arc[i + 1])),
  ];

  /// Spread the lines' trains apart (not all leaving on the same second).
  late final int phase = trainPhase(line.id);

  static LineRun? of(RailLine line, MapLine mapLine) {
    final geo = LineGeo.of(mapLine);
    final arc = <double>[];
    for (final s in line.stations) {
      final a = geo.stopAt[s];
      if (a == null) return null;
      arc.add(a);
    }
    if (line.loop) arc.add(arc.first);
    final arrive = <int>[0], depart = <int>[0];
    var t = 0;
    for (var i = 0; i < line.segmentCount; i++) {
      t += math.max(30, line.runSec[i]);
      arrive.add(t);
      final last = i == line.segmentCount - 1;
      if (!last || line.loop) t += line.dwellSec;
      depart.add(t);
    }
    return LineRun(line, mapLine, geo, arc, arrive, depart, t);
  }
}

/// How a line's trains are spread in time (seconds), so not every line's
/// trains leave on the same second. Shared with the departure board, so it
/// shows the very trains the route map draws.
int trainPhase(String lineId) => lineId.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0xFFFFF);

/// Extra spread for the trains running the other way.
const reversePhase = 977;

/// Seconds a train stands at the end of the line before it leaves.
const _wait = 60.0;

/// Where one train is: distance along its line, which way it is heading
/// along the line (+1 / -1), whether it waits at a station.
typedef TrainAt = ({LineRun run, double s, double sign, bool stopped});

/// Speed along a station-to-station run: speeds up, runs, brakes.
double _ease(double f) {
  const a = 0.28;
  if (f <= 0) return 0;
  if (f >= 1) return 1;
  if (f < a) return f * f / (2 * a * (1 - a));
  if (f < 1 - a) return (f - a / 2) / (1 - a);
  final g = 1 - f;
  return 1 - g * g / (2 * a * (1 - a));
}

/// Estimated trains on the drawn lines from the timetables (how often trains
/// come at this hour, run times, stops): not live positions.
class TrainSim {
  TrainSim(this.map, this.city);

  final RouteMapData map;
  final CityData city;

  late final List<LineRun> _runs = [for (final l in map.lines) ?LineRun.of(city.line(l.lineId), l)];

  /// Trains on lines that cross [view] (map units) at [now].
  List<TrainAt> trainsIn(Rect view, DateTime now) {
    final jst = now.toUtc().add(const Duration(hours: 9));
    // Seconds since 04:00 (the service day), with the milliseconds for smooth motion.
    final sec = ((LineTimetable.serviceMinute(jst) - 240) * 60 + jst.second) + jst.millisecond / 1000;
    final out = <TrainAt>[];
    for (final run in _runs) {
      if (!run.mapLine.bounds.inflate(40).overlaps(view)) continue;
      final tt = city.timetables[run.line.id];
      if (tt != null && !tt.inService(jst)) continue;
      final head = (tt?.headwayMinAt(jst) ?? 6) * 60.0;
      final first = tt == null ? -1e9 : (tt.firstTrainMin - 240) * 60.0;
      final last = tt == null ? 1e9 : (tt.lastTrainMin - 240) * 60.0;
      for (final forward in const [true, false]) {
        final offset = (run.phase + (forward ? 0 : reversePhase)) % head;
        if (run.line.loop) {
          // Trains spaced evenly round the loop.
          final n = math.max(1, (run.total / head).round());
          final gap = run.total / n;
          for (var k = 0; k < n; k++) {
            final e = (sec + offset + k * gap) % run.total;
            _place(run, e, forward, out, view);
          }
          continue;
        }
        // A train leaves each end every [head] seconds; the next one already
        // waits at the end of the line for up to [_wait] seconds before.
        final e0 = (sec - offset) % head;
        for (var e = e0 - head >= -_wait ? e0 - head : e0; e < run.total; e += head) {
          final left = sec - e;
          if (left < first || left > last) continue;
          _place(run, e, forward, out, view);
        }
      }
    }
    return out;
  }

  void _place(LineRun run, double e, bool forward, List<TrainAt> out, Rect view) {
    // Elapsed time on the way back = the same timings read from the other end.
    final arrive = run.arrive, depart = run.depart;
    final n = arrive.length;
    final t = forward ? e : run.total - e;
    // Find the stretch: binary search on depart times.
    var lo = 0, hi = n - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (arrive[mid] <= t) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final i = lo;
    if (n > 1 && !run.stretch[i < n - 1 ? i : n - 2].overlaps(view)) return;
    double s;
    var stopped = false;
    double sign;
    if (t <= depart[i] || i == n - 1) {
      s = run.arc[i];
      stopped = true;
      // Heading: the way it will go next (or came from at the end).
      final j = forward ? (i + 1 < n ? i + 1 : i) : (i > 0 ? i - 1 : i);
      final d = j == i ? (forward ? 1.0 : -1.0) : run.geo.delta(run.arc[i], run.arc[j]);
      sign = d >= 0 ? 1 : -1;
      if (j == i) {
        final k = forward ? i - 1 : i + 1;
        if (k >= 0 && k < n) sign = run.geo.delta(run.arc[k], run.arc[i]) >= 0 ? 1 : -1;
      }
    } else {
      final run0 = arrive[i + 1] - depart[i];
      var f = run0 <= 0 ? 1.0 : (t - depart[i]) / run0;
      if (!forward) f = 1 - f; // read backwards: from i+1 towards i
      final d = run.geo.delta(run.arc[i], run.arc[i + 1]);
      s = run.arc[i] + d * (forward ? _ease(f) : 1 - _ease(f));
      sign = (forward ? d : -d) >= 0 ? 1 : -1;
    }
    final p = run.geo.at(s);
    if (!view.contains(p)) return;
    out.add((run: run, s: s, sign: sign, stopped: stopped));
  }
}

/// Draws the estimated trains: little cars in the line's colour, bending
/// round the corners, on the left-hand track (as in Japan).
class TrainPainter extends CustomPainter {
  TrainPainter({
    required this.sim,
    required this.matrix,
    required this.clock,
    required this.visible,
    this.night = false,
    this.still = false,
  }) : super(repaint: Listenable.merge([matrix, clock]));

  final TrainSim sim;
  final TransformationController matrix;
  final Listenable clock;

  /// How strongly a line's trains are drawn (0 = hidden), for the focus and route.
  final double Function(String lineId) visible;

  /// Night map: the headlights throw a little light ahead.
  final bool night;

  /// Reduce-motion: still drawn, they only move with the clock (no tween).
  final bool still;

  /// Zoom from which trains appear.
  static const from = 0.3;

  static final _glow = Paint()
    ..shader = ui.Gradient.radial(Offset.zero, 1, const [
      Color.fromRGBO(255, 240, 190, 0.45),
      Color.fromRGBO(255, 240, 190, 0),
    ]);

  static Color _shade(Color c, double k) => Color.lerp(c, const Color(0xFF1C2230), k)!;
  static Color _tint(Color c, double k) => Color.lerp(c, const Color(0xFFFFFFFF), k)!;

  @override
  void paint(Canvas canvas, Size size) {
    final m = matrix.value;
    final s = m.storage[0];
    Offset sp(Offset w) => MatrixUtils.transformPoint(m, w);
    if (s >= from) _trains(canvas, size, m, s, sp);
  }

  void _trains(Canvas canvas, Size size, Matrix4 m, double s, Offset Function(Offset) sp) {
    final inv = Matrix4.inverted(m);
    final view = Rect.fromPoints(
      MatrixUtils.transformPoint(inv, Offset.zero),
      MatrixUtils.transformPoint(inv, Offset(size.width, size.height)),
    ).inflate(30 / s);
    final trains = sim.trainsIn(view, DateTime.now());
    // Fade in from [from].
    final fade = ((s - from) / 0.15).clamp(0.0, 1.0);
    final lineW = (5.5 * s).clamp(2.0, 7.0);
    final w = (lineW * 1.15 + 1.6).clamp(3.6, 9.5);
    final cars = s >= 0.95 ? 3 : (s >= 0.55 ? 2 : 1);
    final carL = cars == 1 ? w * 2.8 : w * 2.25;
    const gap = 1.2;
    final side = lineW * 0.42; // left-hand track
    final paint = Paint()..isAntiAlias = true;
    var drawn = 0;
    for (final tr in trains) {
      if (drawn > 500) break;
      final a = visible(tr.run.line.id) * fade;
      if (a <= 0.02) continue;
      final id = tr.run.line.id;
      final n = _oneCar.contains(id) ? 1 : (_twoCars.contains(id) ? math.min(cars, 2) : cars);
      final len = n == 1 && cars > 1 ? carL * 1.15 : carL;
      final color = tr.run.line.color;
      final geo = tr.run.geo;
      final stepW = (len + gap) / s; // car spacing in map units
      for (var c = 0; c < n; c++) {
        // Cars centred on the train's spot, the first one ahead.
        final along = tr.s + tr.sign * ((n - 1) / 2 - c) * stepW;
        final dir = geo.dirAt(along, len / s * 0.5) * tr.sign;
        final left = Offset(dir.dy, -dir.dx);
        final p = sp(geo.at(along)) + left * side;
        final angle = math.atan2(dir.dy, dir.dx);
        _car(canvas, paint, p, angle, len, w, color, a, front: c == 0, back: c == n - 1, stopped: tr.stopped);
      }
      drawn++;
    }
  }

  void _car(
    Canvas canvas,
    Paint paint,
    Offset p,
    double angle,
    double len,
    double w,
    Color color,
    double a, {
    required bool front,
    required bool back,
    required bool stopped,
  }) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    final body = Rect.fromCenter(center: Offset.zero, width: len, height: w);
    final nose = Radius.circular(w * 0.5), flat = Radius.circular(w * 0.22);
    RRect shape(Rect r) => RRect.fromRectAndCorners(
      r,
      topRight: front ? nose : flat,
      bottomRight: front ? nose : flat,
      topLeft: back ? nose : flat,
      bottomLeft: back ? nose : flat,
    );
    // Soft shadow, always to the lower right of the screen.
    final sh = Offset(math.cos(-angle) * 0.9 - math.sin(-angle) * 1.4, math.sin(-angle) * 0.9 + math.cos(-angle) * 1.4);
    paint
      ..style = PaintingStyle.fill
      ..color = Color.fromRGBO(30, 34, 48, 0.28 * a);
    canvas.drawRRect(shape(body.shift(sh)), paint);
    // Gangway to the car ahead.
    if (!front) {
      paint.color = Color.fromRGBO(60, 64, 76, 0.9 * a);
      canvas.drawRect(Rect.fromLTWH(len / 2 - 1, -w * 0.2, 4.5, w * 0.4), paint);
    }
    // White rim, so a train stands out on its own (same colour) line.
    paint.color = Color.fromRGBO(255, 255, 255, a);
    canvas.drawRRect(shape(body.inflate(1.1)), paint);
    // Body in the line colour, darker sides.
    paint.color = _shade(color, 0.28).withValues(alpha: a);
    canvas.drawRRect(shape(body), paint);
    paint.color = color.withValues(alpha: a);
    canvas.drawRRect(shape(body.deflate(w * 0.14)), paint);
    if (w >= 5) {
      // Roof: a light strip with air conditioners.
      final roof = Rect.fromCenter(center: Offset.zero, width: len - w * 1.1, height: w * 0.3);
      paint.color = _tint(color, 0.55).withValues(alpha: a);
      canvas.drawRRect(RRect.fromRectAndRadius(roof, Radius.circular(w * 0.15)), paint);
      if (len > w * 2) {
        paint.color = _shade(color, 0.12).withValues(alpha: 0.8 * a);
        final u = w * 0.34;
        for (final x in [-len * 0.18, len * 0.18]) {
          canvas.drawRect(Rect.fromCenter(center: Offset(x, 0), width: u, height: u * 0.9), paint);
        }
      }
    }
    if (front) {
      // Windscreen and two headlights.
      final glass = Rect.fromLTRB(len / 2 - w * 0.62, -w * 0.32, len / 2 - w * 0.2, w * 0.32);
      paint.color = Color.fromRGBO(34, 44, 66, 0.9 * a);
      canvas.drawRRect(RRect.fromRectAndRadius(glass, Radius.circular(w * 0.18)), paint);
      if (w >= 4.5) {
        paint.color = Color.fromRGBO(170, 210, 240, 0.85 * a);
        canvas.drawRect(Rect.fromLTWH(glass.left + w * 0.06, glass.top + w * 0.06, w * 0.1, w * 0.22), paint);
      }
      if (night) {
        final ahead = Offset(len / 2 + w * 0.9, 0);
        // One glow shader for every train (radius 1 at the origin), scaled into place.
        canvas.save();
        canvas.translate(ahead.dx, ahead.dy);
        canvas.scale(w * 1.3);
        canvas.drawCircle(Offset.zero, 1, _glow..color = Color.fromRGBO(255, 255, 255, a));
        canvas.restore();
      }
      final lamp = stopped ? const Color(0xFFFFF0C0) : const Color(0xFFFFFBE6);
      paint.color = lamp.withValues(alpha: a);
      for (final y in [-w * 0.3, w * 0.3]) {
        canvas.drawCircle(Offset(len / 2 - w * 0.1, y), math.max(0.7, w * 0.11), paint);
      }
    }
    if (back && w >= 4.5) {
      paint.color = Color.fromRGBO(226, 72, 60, 0.9 * a);
      for (final y in [-w * 0.3, w * 0.3]) {
        canvas.drawCircle(Offset(-len / 2 + w * 0.1, y), math.max(0.6, w * 0.09), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(TrainPainter old) => old.sim != sim || old.visible != visible || old.night != night;
}
