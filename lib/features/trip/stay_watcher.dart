import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/models/city.dart';
import '../platform/nearest_station.dart';
import 'location_source.dart';
import 'trip_estimator.dart';

/// Watches, while the app is open, whether the user stays at a station:
/// within [radiusM] of the same station for [stay], it reports the station
/// once (a gold "stayed here" stamp). Underground the GPS often has no fix:
/// the last good position counts (fixes that fail keep the current station).
///
/// Only uses location when permission is already given (never asks itself).
class StayWatcher with WidgetsBindingObserver {
  StayWatcher({
    required this.city,
    required this.location,
    required this.onStay,
    this.radiusM = 300,
    this.stay = const Duration(minutes: 5),
    this.every = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CityData city;
  final LocationSource location;

  /// Called once per station visit with the station id.
  final void Function(String stationId) onStay;
  final double radiusM;
  final Duration stay;
  final Duration every;
  final DateTime Function() _clock;

  Timer? _timer;
  String? _station;
  DateTime? _since;
  String? _reported;

  /// Station the user is at now (null when not near one), for tests.
  String? get station => _station;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Closed apps do not count: the time starts again when it is opened.
      _timer?.cancel();
      _timer = null;
      _station = null;
      _since = null;
    }
  }

  void _resume() {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => check());
    check();
  }

  /// One look at where the user is (also called by the timer).
  Future<void> check() async {
    if (!await location.hasPermission()) return;
    final fix = await location.currentFix();
    seen(fix);
  }

  /// Handles one position (null = no fix right now, e.g. underground).
  void seen(GpsFix? fix) {
    final now = _clock();
    if (fix == null) {
      // No signal: keep the station we were at (the last good position).
      _maybeReport(now);
      return;
    }
    final near = nearestStation(city, fix.lat, fix.lng, maxMeters: radiusM);
    final id = near?.station.id;
    if (id != _station) {
      _station = id;
      _since = id == null ? null : now;
      if (id != _reported) _reported = null;
      return;
    }
    _maybeReport(now);
  }

  void _maybeReport(DateTime now) {
    final id = _station, since = _since;
    if (id == null || since == null || id == _reported) return;
    if (now.difference(since) >= stay) {
      _reported = id;
      onStay(id);
    }
  }
}
