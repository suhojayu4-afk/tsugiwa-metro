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

/// GPS correction: if a good fix puts the user at a station on the route, shift
/// the timeline so the estimate matches. Returns seconds to add to the elapsed
/// time, or null when GPS should not be used (weak signal, underground, far away).
int? gpsCorrection(
  TripPlan plan,
  CityData city,
  GpsFix fix,
  int elapsedSec, {
  double maxAccuracyM = 100,
  double nearStationM = 250,
}) {
  if (fix.accuracyM > maxAccuracyM) return null;
  final est = estimateTrip(plan, elapsedSec, fix.time);
  final cur = plan.stops[est.currentIndex];
  final next = est.nextIndex == null ? null : plan.stops[est.nextIndex!];
  if (cur.underground && (next == null || next.underground)) return null;

  int? bestIndex;
  var bestDist = double.infinity;
  final from = math.max(0, est.currentIndex - 2);
  final to = math.min(plan.lastIndex, est.currentIndex + 3);
  for (var i = from; i <= to; i++) {
    final stop = plan.stops[i];
    if (stop.underground) continue;
    final s = city.station(stop.stationId);
    final d = distanceMeters(fix.lat, fix.lng, s.lat, s.lng);
    if (d < bestDist) {
      bestDist = d;
      bestIndex = i;
    }
  }
  if (bestIndex == null || bestDist > nearStationM) return null;

  final stop = plan.stops[bestIndex];
  int delta = 0;
  if (elapsedSec < stop.arriveSec) {
    delta = stop.arriveSec - elapsedSec; // we are ahead of the timetable
  } else if (elapsedSec > stop.departSec + 20) {
    delta = stop.departSec - elapsedSec; // still at the station: running late
  }
  return delta.abs() >= 20 ? delta : 0;
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
