import 'dart:math' as math;

import '../../data/models/city.dart';
import 'trip_plan.dart';

/// Where the user is right now, worked out from the plan and the elapsed time.
class TripSnapshot {
  const TripSnapshot({
    required this.currentIndex,
    required this.atStation,
    required this.remainingStops,
    required this.progress,
    required this.eta,
    required this.elapsedSec,
  });

  /// Last stop the train has reached.
  final int currentIndex;

  /// true = stopped at [currentIndex]; false = running towards the next stop.
  final bool atStation;
  final int remainingStops;

  /// 0.0 – 1.0 along the whole trip.
  final double progress;
  final DateTime eta;
  final int elapsedSec;

  int? get nextIndex => remainingStops == 0 ? null : currentIndex + 1;
  bool get arrived => remainingStops == 0;
}

TripSnapshot estimateTrip(TripPlan plan, int elapsedSec, DateTime now) {
  final elapsed = math.max(0, elapsedSec);
  var current = 0;
  for (var i = 0; i < plan.stops.length; i++) {
    if (plan.stops[i].arriveSec <= elapsed) current = i;
  }
  final atStation = current == plan.lastIndex || elapsed < plan.stops[current].departSec;
  final remainingSec = math.max(0, plan.totalSec - elapsed);
  return TripSnapshot(
    currentIndex: current,
    atStation: atStation,
    remainingStops: plan.lastIndex - current,
    progress: plan.totalSec == 0 ? 1 : math.min(1, elapsed / plan.totalSec),
    eta: now.add(Duration(seconds: remainingSec)),
    elapsedSec: elapsed,
  );
}

class GpsFix {
  const GpsFix({required this.lat, required this.lng, required this.accuracyM, required this.time});
  final double lat;
  final double lng;
  final double accuracyM;
  final DateTime time;
}

/// GPS correction: puts the trip where a good fix shows the phone. Near a
/// station on the route it is at that station; between two stations (above
/// ground) it is that far along the run between them. Returns seconds to add
/// to the elapsed time, or null when GPS should not be used (weak signal,
/// underground, nowhere near the route).
int? gpsCorrection(
  TripPlan plan,
  CityData city,
  GpsFix fix,
  int elapsedSec, {
  double maxAccuracyM = 100,
  double nearStationM = 250,
}) {
  if (fix.accuracyM > maxAccuracyM) return null;
  final target = gpsElapsed(plan, city, fix, elapsedSec, nearStationM: nearStationM);
  if (target == null) return null;
  final delta = target - elapsedSec;
  return delta.abs() >= 20 ? delta : 0;
}

/// The elapsed time that matches where [fix] is on the route, or null when
/// it is not on it. Looks from a little behind the estimate to the end, so a
/// trip that runs well ahead of the timetable (an earlier train) still finds
/// its place; the nearest match wins, the earlier one on a tie.
int? gpsElapsed(TripPlan plan, CityData city, GpsFix fix, int elapsedSec, {double nearStationM = 250}) {
  final est = estimateTrip(plan, elapsedSec, fix.time);
  final cur = plan.stops[est.currentIndex];
  final next = est.nextIndex == null ? null : plan.stops[est.nextIndex!];
  if (cur.underground && (next == null || next.underground)) return null;
  final from = math.max(0, est.currentIndex - 2);

  // A station on the route.
  int? station;
  var stationDist = double.infinity;
  for (var i = from; i <= plan.lastIndex; i++) {
    final stop = plan.stops[i];
    if (stop.underground) continue;
    final s = city.station(stop.stationId);
    final d = distanceMeters(fix.lat, fix.lng, s.lat, s.lng);
    if (d < stationDist - 1) {
      stationDist = d;
      station = i;
    }
  }
  if (station != null && stationDist <= nearStationM) {
    final stop = plan.stops[station];
    if (elapsedSec < stop.arriveSec) return stop.arriveSec; // ahead of the timetable
    if (elapsedSec > stop.departSec + 20) return stop.departSec; // still there: running late
    return elapsedSec;
  }

  // Between two stations: the nearest run, as far along as the fix is.
  int? seg;
  var segDist = double.infinity;
  var segAlong = 0.0;
  for (var i = from; i < plan.lastIndex; i++) {
    final a = plan.stops[i], b = plan.stops[i + 1];
    if (a.underground && b.underground) continue;
    final sa = city.station(a.stationId), sb = city.station(b.stationId);
    final (dist, along, length) = _toSegment(fix.lat, fix.lng, sa.lat, sa.lng, sb.lat, sb.lng);
    // Tracks bend away from the straight line: more room on a long run.
    final room = math.min(900.0, 250 + length * 0.2);
    if (dist <= room && dist < segDist - 1) {
      segDist = dist;
      seg = i;
      segAlong = along;
    }
  }
  if (seg == null) return null;
  final a = plan.stops[seg], b = plan.stops[seg + 1];
  final run = b.arriveSec - a.departSec;
  if (run <= 2) return b.arriveSec;
  return (a.departSec + 1 + segAlong * (run - 2)).round();
}

/// Distance (m) from a point to the segment a→b, how far along it the point
/// falls (0 … 1) and the segment's length (m), on a flat local projection.
(double, double, double) _toSegment(double lat, double lng, double aLat, double aLng, double bLat, double bLng) {
  final k = math.cos(aLat * math.pi / 180) * 111320;
  const m = 110540.0;
  final bx = (bLng - aLng) * k, by = (bLat - aLat) * m;
  final px = (lng - aLng) * k, py = (lat - aLat) * m;
  final len2 = bx * bx + by * by;
  final f = len2 == 0 ? 0.0 : ((px * bx + py * by) / len2).clamp(0.0, 1.0);
  final dx = px - f * bx, dy = py - f * by;
  return (math.sqrt(dx * dx + dy * dy), f, math.sqrt(len2));
}

double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a));
}
