import 'dart:async';
import 'dart:ui' show Color, Locale;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Where the trip is, from far away to arrival. Drives the wording and
/// colour of the lock-screen views.
enum LivePhase { far, near, last, arrived }

/// What the lock screen / Dynamic Island (iOS Live Activity) and the Galaxy
/// Now Bar (Android Live Updates) show during a trip.
class LiveStatus {
  const LiveStatus({
    required this.currentStation,
    required this.nextStation,
    required this.destination,
    required this.remainingStops,
    required this.eta,
    required this.progress,
    required this.lineColor,
    required this.atStation,
    this.lineLabel = '',
    this.lang = 'ja',
    this.currentIndex = 0,
    this.stopFractions = const [],
    this.segmentColors = const [],
    this.trainSkinId = 'train.starter',
    this.characterId,
    this.congestionLevel,
    this.congestionIsLive = false,
  });

  final String currentStation;
  final String? nextStation;
  final String destination;
  final int remainingStops;
  final DateTime eta;

  /// Whole trip, 0 at the first station → 1 at the destination.
  final double progress;
  final Color lineColor;
  final bool atStation;

  /// e.g. "山手線 内回り".
  final String lineLabel;
  final String lang;

  /// Index of the station the train is at / last passed.
  final int currentIndex;

  /// Where each stop sits on the bar (0..1, by time), first = 0, last = 1.
  final List<double> stopFractions;

  /// Colour of each segment between stops (the line ridden on it).
  final List<Color> segmentColors;

  /// Equipped MY room items, so the native views draw the same pixel train.
  final String trainSkinId;
  final String? characterId;

  /// 1–4, null when unknown. Filled in by the congestion step.
  final int? congestionLevel;
  final bool congestionIsLive;

  LivePhase get phase => switch (remainingStops) {
    0 => LivePhase.arrived,
    1 => LivePhase.last,
    2 => LivePhase.near,
    _ => LivePhase.far,
  };
}

/// Bridge to the native Live Activity / Live Updates code.
abstract class LiveStatusBridge {
  Future<void> start(LiveStatus status);
  Future<void> update(LiveStatus status);

  /// One stop before the destination, or arrived: a one-off buzz alert.
  Future<void> alert(LivePhase kind, LiveStatus status);
  Future<void> end(LiveStatus status, {bool arrived = false});

  /// The user tapped 終了 on the notification.
  Stream<void> get endRequests;
}

class NoopLiveStatusBridge implements LiveStatusBridge {
  const NoopLiveStatusBridge();
  @override
  Future<void> start(LiveStatus status) async {}
  @override
  Future<void> update(LiveStatus status) async {}
  @override
  Future<void> alert(LivePhase kind, LiveStatus status) async {}
  @override
  Future<void> end(LiveStatus status, {bool arrived = false}) async {}
  @override
  Stream<void> get endRequests => const Stream.empty();
}

/// Talks to android/.../MainActivity.kt ("tsugiwa/live"). iOS will answer on
/// the same channel once the Live Activity extension is added.
class MethodChannelLiveStatusBridge implements LiveStatusBridge {
  MethodChannelLiveStatusBridge() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'endRequested') _endRequests.add(null);
    });
  }

  static const _channel = MethodChannel('tsugiwa/live');
  final _endRequests = StreamController<void>.broadcast();

  /// Native views are updated at most this often; station or phase changes
  /// go through immediately. The countdown ticks natively in between.
  static const minInterval = Duration(seconds: 4);

  DateTime? _lastSent;
  String? _lastKey;
  bool _active = false;

  @override
  Stream<void> get endRequests => _endRequests.stream;

  @override
  Future<void> start(LiveStatus status) async {
    _active = true;
    _lastKey = null;
    await _call('ensureNotificationPermission', null);
    await _send('start', status);
  }

  @override
  Future<void> update(LiveStatus status) async {
    if (!_active) return;
    final key = '${status.currentIndex}|${status.phase}|${status.atStation}';
    final now = DateTime.now();
    final due = _lastSent == null || now.difference(_lastSent!) >= minInterval;
    if (!due && key == _lastKey) return;
    _lastKey = key;
    await _send('update', status);
  }

  @override
  Future<void> alert(LivePhase kind, LiveStatus status) async {
    final t = lookupAppLocalizations(Locale(status.lang));
    final arrived = kind == LivePhase.arrived;
    await _call('alert', {
      'kind': arrived ? 'arrived' : 'approaching',
      'title': arrived ? t.alertArrivedTitle(status.destination) : t.alertApproachTitle(status.destination),
      'text': arrived ? t.alertArrivedBody : t.alertApproachBody,
      'color': status.lineColor.toARGB32(),
    });
  }

  @override
  Future<void> end(LiveStatus status, {bool arrived = false}) async {
    _active = false;
    await _call('end', arrived ? payload(status) : null);
  }

  Future<void> _send(String method, LiveStatus status) async {
    _lastSent = DateTime.now();
    await _call(method, payload(status));
  }

  Future<void> _call(String method, Object? args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Platform without native support yet (e.g. iOS before the extension).
    } on PlatformException {
      // A lock-screen problem must never break the trip itself.
    }
  }

  /// Localized texts + bar layout for the native side.
  static Map<String, Object?> payload(LiveStatus s) {
    final t = lookupAppLocalizations(Locale(s.lang));
    final eta = DateFormat.Hm().format(s.eta);
    final next = s.nextStation ?? s.destination;
    final (title, text) = switch (s.phase) {
      LivePhase.far => (t.liveFar(s.destination, s.remainingStops), t.liveFlow(s.currentStation, next)),
      LivePhase.near => (t.liveNear(s.remainingStops, s.destination), t.liveFlow(s.currentStation, next)),
      LivePhase.last => (t.liveNext(s.destination), t.alertApproachBody),
      LivePhase.arrived => (t.liveArrived(s.destination), t.alertArrivedBody),
    };
    return {
      'title': title,
      'text': text,
      'sub': t.liveSub(s.lineLabel, eta),
      'short': s.phase == LivePhase.arrived ? '' : t.liveShort(s.remainingStops),
      'endLabel': t.liveEnd,
      'phase': s.phase.name,
      'progress': s.progress.clamp(0.0, 1.0),
      'stops': s.stopFractions,
      'colors': [for (final c in s.segmentColors) c.toARGB32()],
      'current': s.currentIndex,
      'eta': s.eta.millisecondsSinceEpoch,
      'channelNames': {'trip': t.channelTrip, 'approach': t.channelApproach, 'arrive': t.channelArrive},
    };
  }
}
