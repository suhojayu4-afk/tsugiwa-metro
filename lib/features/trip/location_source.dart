import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import 'trip_estimator.dart';

/// How hard the phone looks for its place during a ride. Finding it costs
/// battery, so a trip asks only for what it needs at each moment.
enum GpsPower {
  /// Near the destination: the best fix, often (getting off at the right stop).
  precise,

  /// Riding along above ground: to about a hundred metres, now and then.
  cruise,

  /// Underground, where no fix comes anyway: the least the phone can do
  /// while still keeping the trip alive in the background.
  idle,
}

/// GPS input. Swappable so tests and the emulator can run without real GPS.
abstract class LocationSource {
  /// Asks for permission if needed. true = GPS can be used.
  Future<bool> ensurePermission();

  /// Whether permission is already given (never asks).
  Future<bool> hasPermission();

  /// Emits fixes while listened to. Call [ensurePermission] first. On an
  /// iPhone the stream also keeps the trip running while the app is in the
  /// background (the phone shows its blue location mark meanwhile).
  ///
  /// [background]: keep running with the app in the background (a trip).
  /// A screen that only shows where the user is leaves it false, so the
  /// phone stops looking when the app is put away.
  Stream<GpsFix> watch({GpsPower power = GpsPower.precise, bool background = false});

  /// One position right now (or the last known one), null if unavailable.
  Future<GpsFix?> currentFix();

  /// Which way the phone points while listened to: degrees clockwise from
  /// north (0 … 360). Empty where the phone has no compass.
  Stream<double> heading();
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
  Future<bool> hasPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  @override
  Future<GpsFix?> currentFix() async {
    if (!await ensurePermission()) return null;
    Position? p;
    try {
      p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
    } catch (_) {
      // Weak signal (e.g. underground): fall back to the last known position.
      p = await Geolocator.getLastKnownPosition();
    }
    if (p == null) return null;
    return GpsFix(lat: p.latitude, lng: p.longitude, accuracyM: p.accuracy, time: p.timestamp);
  }

  @override
  Stream<GpsFix> watch({GpsPower power = GpsPower.precise, bool background = false}) {
    return Geolocator.getPositionStream(
      locationSettings: settingsFor(power, defaultTargetPlatform, background: background),
    ).map((p) => GpsFix(lat: p.latitude, lng: p.longitude, accuracyM: p.accuracy, time: p.timestamp));
  }

  /// What is asked of the phone at each [power].
  static LocationSettings settingsFor(GpsPower power, TargetPlatform platform, {bool background = false}) {
    final (accuracy, metres, seconds) = switch (power) {
      GpsPower.precise => (LocationAccuracy.high, 30, 4),
      GpsPower.cruise => (LocationAccuracy.medium, 120, 15),
      GpsPower.idle => (LocationAccuracy.low, 400, 60),
    };
    if (platform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: metres,
        activityType: ActivityType.otherNavigation,
        // Never paused by the phone: a paused stream does not come back by
        // itself in the background and the trip would stop there.
        pauseLocationUpdatesAutomatically: !background,
        // The trip goes on with the app in the background (Info.plist:
        // UIBackgroundModes location); the phone shows its blue mark.
        allowBackgroundLocationUpdates: background,
        showBackgroundLocationIndicator: background,
      );
    }
    if (platform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: metres,
        intervalDuration: Duration(seconds: seconds),
      );
    }
    return LocationSettings(accuracy: accuracy, distanceFilter: metres);
  }

  @override
  Stream<double> heading() {
    final events = FlutterCompass.events;
    if (events == null) return const Stream.empty();
    return events.where((e) => e.heading != null).map((e) => (e.heading! % 360 + 360) % 360).handleError((Object _) {});
  }
}

class NoLocationSource implements LocationSource {
  const NoLocationSource();
  @override
  Future<bool> ensurePermission() async => false;
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<GpsFix?> currentFix() async => null;
  @override
  Stream<GpsFix> watch({GpsPower power = GpsPower.precise, bool background = false}) => const Stream.empty();
  @override
  Stream<double> heading() => const Stream.empty();
}
