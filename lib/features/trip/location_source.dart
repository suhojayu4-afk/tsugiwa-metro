import 'package:geolocator/geolocator.dart';

import 'trip_estimator.dart';

/// GPS input. Swappable so tests and the emulator can run without real GPS.
abstract class LocationSource {
  /// Asks for permission if needed. true = GPS can be used.
  Future<bool> ensurePermission();

  /// Emits fixes while listened to. Call [ensurePermission] first.
  Stream<GpsFix> watch();

  /// One position right now (or the last known one), null if unavailable.
  Future<GpsFix?> currentFix();
}

class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  @override
  Future<GpsFix?> currentFix() async {
    if (!await ensurePermission()) return null;
    Position? p;
    try {
      p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      // Weak signal (e.g. underground): fall back to the last known position.
      p = await Geolocator.getLastKnownPosition();
    }
    if (p == null) return null;
    return GpsFix(lat: p.latitude, lng: p.longitude, accuracyM: p.accuracy, time: p.timestamp);
  }

  @override
  Stream<GpsFix> watch() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 30),
    ).map((p) => GpsFix(lat: p.latitude, lng: p.longitude, accuracyM: p.accuracy, time: p.timestamp));
  }
}

class NoLocationSource implements LocationSource {
  const NoLocationSource();
  @override
  Future<bool> ensurePermission() async => false;
  @override
  Future<GpsFix?> currentFix() async => null;
  @override
  Stream<GpsFix> watch() => const Stream.empty();
}
