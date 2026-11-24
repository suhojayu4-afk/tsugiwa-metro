import 'dart:async';

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../data/my_store.dart';
import '../../platform/live_status_bridge.dart';
import '../album/postcard_book.dart';
import 'location_source.dart';
import 'trip_estimator.dart';
import 'trip_plan.dart';

enum GpsState { waiting, corrected, underground, off }

enum TripEvent { approaching, arrived, endedFromNotification }

/// Runs one trip: ticks every second, applies GPS corrections, raises
/// "next stop is yours" / "arrived" events, and feeds the native live views.
class TripController extends ChangeNotifier {
  TripController({
    required this.city,
    required this.plan,
    required this.lang,
    LocationSource? location,
    LiveStatusBridge? bridge,
    DateTime Function()? clock,
  }) : _location = location ?? Services.location,
       _bridge = bridge ?? Services.live,
       _clock = clock ?? DateTime.now;

  final CityData city;
  final TripPlan plan;
  final String lang;
  final LocationSource _location;
  final LiveStatusBridge _bridge;
  final DateTime Function() _clock;

  final _events = StreamController<TripEvent>.broadcast();
  Stream<TripEvent> get events => _events.stream;

  Timer? _timer;
  StreamSubscription<void>? _endSub;
  StreamSubscription<GpsFix>? _gpsSub;
  DateTime? _lastTick;
  DateTime? _lastGoodFix;
  bool _gpsPermissionGiven = false;
  double _elapsedMs = 0;
  int _correctionSec = 0;
  bool _approachingSent = false;
  bool _arrivedSent = false;

  // What the phone's location showed of this ride, for the coins: where it
  // was first seen, how far from there it got, and whether it came near
  // the last station.
  GpsFix? _firstFix;
  double _movedM = 0;
  bool _nearEnd = false;

  /// The location showed a real ride: the phone moved a good way, or was
  /// seen at the station where the trip ends (not just where it began).
  bool get rideConfirmed => _movedM >= 600 || (_nearEnd && _movedM >= 200);

  /// Coins earned by this trip, once arrived.
  TripReward? reward;

  /// Test speed (debug builds only): 1 = real time.
  double speed = 1;

  late TripSnapshot snapshot = estimateTrip(plan, 0, _clock());

  GpsState get gpsState {
    final stop = plan.stops[snapshot.currentIndex];
    if (stop.underground) return GpsState.underground;
    if (!_gpsPermissionGiven) return GpsState.off;
    final last = _lastGoodFix;
    if (last != null && _clock().difference(last).inSeconds < 90) {
      return GpsState.corrected;
    }
    return GpsState.waiting;
  }

  int get _elapsedSec => _elapsedMs ~/ 1000 + _correctionSec - _delaySec;

  /// How late the real train being waited for / ridden runs (JR西日本's
  /// 走行位置, Tottori), while no GPS fix has put the trip right.
  int get _delaySec {
    if (_lastGoodFix != null && _clock().difference(_lastGoodFix!).inSeconds < 90) return 0;
    final train = plan.trainLeaving(snapshot.currentIndex);
    return train == null ? 0 : Services.jrwest.delayOf(train.run.no) * 60;
  }

  /// Minutes late of the train now waited for or ridden (0 = on time / unknown).
  int get delayMin {
    final train = plan.trainLeaving(snapshot.currentIndex);
    return train == null ? 0 : Services.jrwest.delayOf(train.run.no);
  }

  void start() {
    _lastTick = _clock();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _bridge.start(_liveStatus());
    // 終了 on the lock-screen notification ends the trip in the app too.
    _endSub = _bridge.endRequests.listen((_) {
      cancel();
      _events.add(TripEvent.endedFromNotification);
    });
    _checkEvents();
    _startGps();
  }

  Future<void> _startGps() async {
    _gpsPermissionGiven = await _location.ensurePermission();
    if (!_gpsPermissionGiven || _timer == null) return;
    notifyListeners();
    _gpsSub = _location.watch().listen(_onFix, onError: (_) {});
  }

  void setSpeed(double value) {
    speed = value;
    notifyListeners();
  }

  void _tick() {
    final now = _clock();
    _elapsedMs += now.difference(_lastTick ?? now).inMilliseconds * speed;
    _lastTick = now;
    _refresh();
  }

  void _onFix(GpsFix fix) {
    if (fix.accuracyM <= 150) {
      final first = _firstFix ??= fix;
      final moved = distanceMeters(first.lat, first.lng, fix.lat, fix.lng);
      if (moved > _movedM) _movedM = moved;
      final end = city.station(plan.stops.last.stationId);
      if (distanceMeters(fix.lat, fix.lng, end.lat, end.lng) <= 500) _nearEnd = true;
    }
    final delta = gpsCorrection(plan, city, fix, _elapsedSec);
    if (delta != null) {
      _lastGoodFix = _clock();
      _correctionSec += delta;
    }
    _refresh();
  }

  void _refresh() {
    snapshot = estimateTrip(plan, _elapsedSec, _clock());
    _checkEvents();
    if (!_arrivedSent) _bridge.update(_liveStatus());
    notifyListeners();
  }

  void _checkEvents() {
    final last = plan.lastIndex;
    if (!_approachingSent && !snapshot.arrived && snapshot.currentIndex >= last - 1) {
      _approachingSent = true;
      _events.add(TripEvent.approaching);
      _bridge.alert(LivePhase.last, _liveStatus());
    }
    if (!_arrivedSent && snapshot.arrived) {
      _arrivedSent = true;
      _giveCoins();
      _events.add(TripEvent.arrived);
      final status = _liveStatus();
      _bridge.alert(LivePhase.arrived, status);
      // One "arrived" notification (with its buzz) replaces the trip card.
      _bridge.end(status);
      _stopTimers();
    }
  }

  String _name(int index) => city.station(plan.stops[index].stationId).name.of(lang);

  late final List<double> _stopFractions = [
    for (final stop in plan.stops) plan.totalSec == 0 ? 0 : stop.arriveSec / plan.totalSec,
  ];

  late final List<Color> _segmentColors = [
    for (var i = 0; i + 1 < plan.stops.length; i++) city.line(plan.stops[i + 1].lineId).color,
  ];

  String _lineLabel(String lineId) {
    final line = city.line(lineId);
    final leg = plan.route.legs.where((l) => l.lineId == lineId).firstOrNull;
    final dir = leg == null ? '' : ' ${line.directionName(leg.forward).of(lang)}';
    return '${line.name.of(lang)}$dir';
  }

  LiveStatus _liveStatus() {
    final s = snapshot;
    final lineId = plan.lineAt(s.currentIndex);
    return LiveStatus(
      lineLabel: _lineLabel(lineId),
      lang: lang,
      currentIndex: s.currentIndex,
      stopFractions: _stopFractions,
      segmentColors: _segmentColors,
      currentStation: _name(s.currentIndex),
      nextStation: s.nextIndex == null ? null : _name(s.nextIndex!),
      destination: _name(plan.lastIndex),
      remainingStops: s.remainingStops,
      eta: s.eta,
      progress: s.progress,
      lineColor: city.line(lineId).color,
      atStation: s.atStation,
    );
  }

  Future<void> _giveCoins() async {
    final store = Services.my;
    if (!store.loaded) await store.load();
    reward = await store.rewardTrip(
      [for (final s in plan.stops) s.stationId],
      ridden: {for (final s in plan.stops) s.lineId}.toList(),
      confirmed: rideConfirmed,
    );
    // A picture postcard from where the user got off (旅のアルバム).
    await PostcardBook.instance.add(
      my: store,
      station: plan.stops.last.stationId,
      from: plan.stops.first.stationId,
      line: plan.stops.last.lineId,
      weather: Services.weatherNow.value?.kind,
    );
    notifyListeners();
  }

  /// User ended the trip early.
  void cancel() {
    if (!_arrivedSent) _bridge.end(_liveStatus());
    _stopTimers();
  }

  void _stopTimers() {
    _endSub?.cancel();
    _endSub = null;
    _timer?.cancel();
    _timer = null;
    _gpsSub?.cancel();
    _gpsSub = null;
  }

  @override
  void dispose() {
    _stopTimers();
    _events.close();
    super.dispose();
  }
}
