import '../../data/models/city.dart';
import '../../data/models/station.dart';
import '../trip/trip_estimator.dart';

class NearestStation {
  const NearestStation(this.station, this.meters);
  final Station station;
  final double meters;
}

/// Closest station within [maxMeters], or null (e.g. the user is outside the city).
NearestStation? nearestStation(CityData city, double lat, double lng, {double maxMeters = 3000}) {
  NearestStation? best;
  for (final s in city.stations.values) {
    final d = distanceMeters(lat, lng, s.lat, s.lng);
    if (d <= maxMeters && (best == null || d < best.meters)) {
      best = NearestStation(s, d);
    }
  }
  return best;
}
