import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../data/models/city.dart';
import '../../data/models/route_map.dart';
import '../../data/models/station.dart';
import '../trip/trip_estimator.dart' show distanceMeters;

/// Where the user is on the route map, and which way is north there.
///
/// The map is a drawing, not a true-to-scale chart: stations are where the
/// lines look good. So a place between stations is found from the stations
/// round it: the few nearest ones say how the ground lies on the drawing just
/// there (a best-fit shift, turn and stretch), and the user's spot and the
/// compass directions are carried over with it.
@immutable
class MapPlace {
  const MapPlace({
    required this.position,
    required this.north,
    required this.nearest,
    required this.meters,
    required this.metersPerUnit,
  });

  /// The spot on the map (map units).
  final Offset position;

  /// The direction on the screen that is geographic north there, as a unit
  /// vector in map units (up is (0, -1)).
  final Offset north;

  /// The closest station and how far it is.
  final Station nearest;
  final double meters;

  /// Roughly how many metres one map unit is there (for the accuracy ring).
  final double metersPerUnit;

  /// The screen direction (radians, 0 = right, clockwise as y grows down) of
  /// a compass [heading] in degrees clockwise from north.
  double angleOf(double heading) {
    final h = heading * math.pi / 180;
    // East on the map: north turned a quarter clockwise on screen.
    final east = Offset(-north.dy, north.dx);
    final d = north * math.cos(h) + east * math.sin(h);
    return math.atan2(d.dy, d.dx);
  }
}

/// The user's place on [map] at ([lat], [lng]), or null when no station of
/// [city] is within [maxMeters] (the user is somewhere else).
MapPlace? placeOnMap(CityData city, RouteMapData map, double lat, double lng, {double maxMeters = 3000}) {
  // Stations that are drawn on the map, nearest first.
  final near = <({Station s, Offset at, double d})>[];
  for (final s in city.stations.values) {
    final stops = map.stopsOf(s.id);
    if (stops.isEmpty) continue;
    final d = distanceMeters(lat, lng, s.lat, s.lng);
    if (d > math.max(maxMeters * 3, 9000)) continue;
    near.add((s: s, at: stops.first.position, d: d));
  }
  if (near.isEmpty) return null;
  near.sort((a, b) => a.d.compareTo(b.d));
  if (near.first.d > maxMeters) return null;
  final first = near.first;

  // Ground coordinates in metres, east and north of the nearest station.
  final mLat = 111320.0;
  final mLng = 111320.0 * math.cos(first.s.lat * math.pi / 180);
  Offset ground(double la, double ln) => Offset((ln - first.s.lng) * mLng, (la - first.s.lat) * mLat);
  final me = ground(lat, lng);

  // A similarity (shift, turn, one stretch; never a mirror image of the
  // ground) fitted to the nearest stations, the nearer the heavier.
  final used = near.take(6).toList();
  MapPlace fallback() =>
      MapPlace(position: first.at, north: const Offset(0, -1), nearest: first.s, meters: first.d, metersPerUnit: 40);
  if (used.length < 2) return fallback();
  var wSum = 0.0;
  var gMean = Offset.zero, pMean = Offset.zero;
  final w = [for (final u in used) 1 / (u.d + 150)];
  for (var i = 0; i < used.length; i++) {
    final g = ground(used[i].s.lat, used[i].s.lng);
    wSum += w[i];
    gMean += g * w[i];
    pMean += used[i].at * w[i];
  }
  gMean /= wSum;
  pMean /= wSum;
  // The map's y grows down while north grows up: flip the ground's y first.
  var a = 0.0, b = 0.0, den = 0.0;
  for (var i = 0; i < used.length; i++) {
    final g0 = ground(used[i].s.lat, used[i].s.lng) - gMean;
    final g = Offset(g0.dx, -g0.dy);
    final p = used[i].at - pMean;
    a += w[i] * (g.dx * p.dx + g.dy * p.dy);
    b += w[i] * (g.dx * p.dy - g.dy * p.dx);
    den += w[i] * (g.dx * g.dx + g.dy * g.dy);
  }
  if (den < 1) return fallback();
  a /= den;
  b /= den;
  final scale = math.sqrt(a * a + b * b); // map units per metre
  if (scale < 1e-5) return fallback();
  Offset toMap(Offset g0) {
    final g = Offset(g0.dx - gMean.dx, -(g0.dy - gMean.dy));
    return pMean + Offset(a * g.dx - b * g.dy, b * g.dx + a * g.dy);
  }

  var at = toMap(me);
  // Never further from the nearest station on the drawing than the ground
  // says (a stretched corner of the map would throw the spot far away).
  final reach = (first.d * scale * 1.6) + 6;
  final off = at - first.at;
  if (off.distance > reach) at = first.at + off / off.distance * reach;
  // North on the ground is (0, 1); on the map that is the fitted turn of (0, -1).
  final n = Offset(b, -a) / scale;
  return MapPlace(position: at, north: n, nearest: first.s, meters: first.d, metersPerUnit: 1 / scale);
}

/// The user on the map, in pixel blocks like the map itself: a blue dot with a
/// white rim, a dotted ring as wide as the fix is uncertain, and a wedge
/// showing which way the phone points.
class MyLocationPainter extends CustomPainter {
  MyLocationPainter({
    required this.place,
    required this.matrix,
    required this.clock,
    this.heading,
    this.accuracyM = 0,
    this.still = false,
  }) : super(repaint: Listenable.merge([matrix, clock]));

  final MapPlace place;
  final TransformationController matrix;

  /// 0 … 1 again and again: the dot's slow pulse.
  final Animation<double> clock;

  /// Compass heading in degrees clockwise from north; null = not known (no cone).
  final double? heading;
  final double accuracyM;
  final bool still;

  static const blue = Color(0xFF2F7BFF);
  static const _deep = Color(0xFF1450D8);
  static const _edge = Color(0xFF14204A);

  /// One "pixel" of the marker, in screen pixels: it is drawn in blocks, like
  /// the rest of the map.
  static const double px = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final m = matrix.value;
    final s = m.storage[0];
    final c0 = MatrixUtils.transformPoint(m, place.position);
    // The middle block sits on whole pixels.
    final c = Offset((c0.dx / px).roundToDouble() * px, (c0.dy / px).roundToDouble() * px);
    final paint = Paint()..isAntiAlias = false;
    void block(int gx, int gy, Color color) {
      paint.color = color;
      canvas.drawRect(Rect.fromLTWH(c.dx + gx * px - px / 2, c.dy + gy * px - px / 2, px, px), paint);
    }

    // How uncertain the fix is, when that is wider than the dot itself: a
    // dotted ring.
    final ring = (accuracyM / place.metersPerUnit * s / px).clamp(0.0, 30.0);
    if (ring > 8) {
      final n = ring.ceil();
      for (var gy = -n; gy <= n; gy++) {
        for (var gx = -n; gx <= n; gx++) {
          final r = math.sqrt(gx * gx + gy * gy);
          if (r <= ring - 0.5) {
            if ((gx + gy).isEven) block(gx, gy, blue.withValues(alpha: 0.10));
          } else if (r <= ring + 0.5) {
            block(gx, gy, blue.withValues(alpha: 0.55));
          }
        }
      }
    }

    // The way the phone points: a wedge of blocks opening from the dot, solid
    // near it and thinning out in steps, with a darker edge so it reads on
    // any ground.
    final h = heading;
    if (h != null) {
      final a = place.angleOf(h);
      const reach = 26, half = 0.50;
      for (var gy = -reach; gy <= reach; gy++) {
        for (var gx = -reach; gx <= reach; gx++) {
          final r = math.sqrt(gx * gx + gy * gy);
          if (r < 4.2 || r > reach) continue;
          var d = (math.atan2(gy.toDouble(), gx.toDouble()) - a) % (2 * math.pi);
          if (d > math.pi) d -= 2 * math.pi;
          final off = d.abs();
          if (off > half) continue;
          // The two sides of the wedge: a darker line.
          final side = off > half - 0.9 / r;
          if (r < 11) {
            block(gx, gy, side ? _edge.withValues(alpha: 0.85) : _deep.withValues(alpha: 0.88));
          } else if (r < 18) {
            block(gx, gy, side ? _edge.withValues(alpha: 0.70) : blue.withValues(alpha: 0.72));
          } else if ((gx + gy).isEven || side) {
            // The far end: every other block.
            block(gx, gy, side ? _edge.withValues(alpha: 0.50) : blue.withValues(alpha: 0.62));
          }
        }
      }
      // A white pointer on the dot's rim, straight ahead.
      for (var gy = -9; gy <= 9; gy++) {
        for (var gx = -9; gx <= 9; gx++) {
          final r = math.sqrt(gx * gx + gy * gy);
          if (r < 4.2 || r > 8.2) continue;
          var d = (math.atan2(gy.toDouble(), gx.toDouble()) - a) % (2 * math.pi);
          if (d > math.pi) d -= 2 * math.pi;
          if (d.abs() <= 0.34 * (8.6 - r) / 4) block(gx, gy, const Color(0xFFFFFFFF));
        }
      }
    }

    // The pulse: a ring of blocks growing out of the dot and fading.
    final t = still ? 0.0 : (clock.value * 3) % 1;
    final pr = 5.0 + 5 * t;
    for (var gy = -11; gy <= 11; gy++) {
      for (var gx = -11; gx <= 11; gx++) {
        final r = math.sqrt(gx * gx + gy * gy);
        if ((r - pr).abs() <= 0.5) block(gx, gy, blue.withValues(alpha: 0.55 * (1 - t)));
      }
    }
    // The dot: a dark edge, a white rim, the blue middle and a glint.
    for (var gy = -5; gy <= 5; gy++) {
      for (var gx = -5; gx <= 5; gx++) {
        final r = math.sqrt(gx * gx + gy * gy);
        if (r <= 2.6) {
          block(gx, gy, blue);
        } else if (r <= 3.7) {
          block(gx, gy, const Color(0xFFFFFFFF));
        } else if (r <= 4.6) {
          block(gx, gy, _edge);
        }
      }
    }
    block(-1, -1, const Color(0xFF9CC4FF));
  }

  @override
  bool shouldRepaint(MyLocationPainter old) =>
      old.place != place || old.heading != heading || old.accuracyM != accuracyM || old.still != still;
}
