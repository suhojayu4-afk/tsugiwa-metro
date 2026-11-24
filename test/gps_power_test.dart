import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tsugiwa_metro/features/trip/location_source.dart';

/// What a trip asks of the phone's location at each power, and that only a
/// trip keeps the phone looking in the background.
void main() {
  test('the nearer the destination the closer the look; a tunnel asks least', () {
    LocationSettings at(GpsPower p) => GeolocatorLocationSource.settingsFor(p, TargetPlatform.android);
    expect(at(GpsPower.precise).accuracy, LocationAccuracy.high);
    expect(at(GpsPower.cruise).accuracy, LocationAccuracy.medium);
    expect(at(GpsPower.idle).accuracy, LocationAccuracy.low);
    expect(at(GpsPower.precise).distanceFilter, lessThan(at(GpsPower.cruise).distanceFilter));
    expect(at(GpsPower.cruise).distanceFilter, lessThan(at(GpsPower.idle).distanceFilter));
    final android = at(GpsPower.cruise) as AndroidSettings;
    expect(android.intervalDuration, const Duration(seconds: 15));
  });

  test('iPhone: a trip runs on in the background and is never paused; a map view is not', () {
    final trip =
        GeolocatorLocationSource.settingsFor(GpsPower.cruise, TargetPlatform.iOS, background: true) as AppleSettings;
    expect(trip.allowBackgroundLocationUpdates, isTrue);
    expect(trip.showBackgroundLocationIndicator, isTrue);
    expect(trip.pauseLocationUpdatesAutomatically, isFalse);
    expect(trip.activityType, ActivityType.otherNavigation);
    final map = GeolocatorLocationSource.settingsFor(GpsPower.precise, TargetPlatform.iOS) as AppleSettings;
    expect(map.allowBackgroundLocationUpdates, isFalse);
    expect(map.showBackgroundLocationIndicator, isFalse);
  });
}
