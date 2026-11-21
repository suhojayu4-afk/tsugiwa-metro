import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/trip/route_finder.dart';
import '../features/trip/trip_plan.dart';
import 'models/city.dart';
import 'models/timetable.dart';

/// The latest time (service minutes, Japan time; past 24:00 = after midnight)
/// to leave [route]'s first station and still catch the last train of every
/// line on the way. Null when no line on the route has a timetable.
int? lastDepartureMin(CityData city, RouteResult route) {
  // Plan it late in the evening: waits between trains are the night ones.
  final plan = TripPlan.build(city, route, DateTime.utc(2026, 1, 5, 23));
  int? best;
  void check(String lineId, int boardSec) {
    final tt = city.timetables[lineId];
    if (tt == null) return;
    final m = tt.lastTrainMin - (boardSec / 60).ceil();
    if (best == null || m < best!) best = m;
  }

  check(plan.lineAt(0), 0);
  for (final s in plan.stops) {
    if (s.transferToLineId != null) check(s.transferToLineId!, s.departSec);
  }
  return best;
}

/// Lines on [route] whose last train is gone (or has not started yet) if you
/// leave its first station at [nowMin] (service minutes, Japan time).
Set<String> missedLines(CityData city, RouteResult route, int nowMin) {
  final plan = TripPlan.build(city, route, DateTime.utc(2026, 1, 5, 23));
  final out = <String>{};
  void check(String lineId, int boardSec) {
    final tt = city.timetables[lineId];
    if (tt == null) return;
    final board = nowMin + (boardSec / 60).ceil();
    if (board > tt.lastTrainMin || board < tt.firstTrainMin) out.add(lineId);
  }

  check(plan.lineAt(0), 0);
  for (final s in plan.stops) {
    if (s.transferToLineId != null) check(s.transferToLineId!, s.departSec);
  }
  return out;
}

/// After a last train has gone: another way that still gets there tonight,
/// avoiding every line whose last train is missed. Null when there is none.
({RouteResult route, int lastDep, Set<String> avoid})? stillPossible(
  CityData city,
  String fromId,
  String toId,
  int nowMin,
) {
  final avoid = <String>{};
  for (var i = 0; i < 8; i++) {
    final r = RouteFinder(city).find(fromId, toId, avoid: avoid);
    if (r == null) return null;
    final missed = missedLines(city, r, nowMin);
    if (missed.isEmpty) return (route: r, lastDep: lastDepartureMin(city, r) ?? nowMin, avoid: Set.of(avoid));
    avoid.addAll(missed);
  }
  return null;
}

/// What the alarm says; texts come from the app's language.
typedef LastTrainTexts = ({String title, String body, String channel});

/// 終電アラーム: one saved route; every night, [leadMin] minutes before its
/// last departure, the phone shows a notification, even when the app is
/// closed (android/.../LastTrainAlarm.kt keeps the daily alarm; iPhone: a
/// local notification from ios/Runner/AppDelegate.swift).
class LastTrainAlarm extends ChangeNotifier {
  static const leadMin = 30;
  static const _key = 'lastTrainAlarm';
  static const _channel = MethodChannel('tsugiwa/live');

  String? _fromId;
  String? _toId;
  bool _loaded = false;

  bool get loaded => _loaded;
  String? get fromId => _fromId;
  String? get toId => _toId;
  bool isOnFor(String from, String to) => _fromId == from && _toId == to;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getStringList(_key);
    if (v != null && v.length == 2) {
      _fromId = v[0];
      _toId = v[1];
    }
    _loaded = true;
    notifyListeners();
  }

  /// Turns the alarm on for [from] → [to] (replacing any other route) and
  /// sets it on the phone. Returns the last departure, or null when the
  /// route has no last-train data (then nothing is set).
  Future<int?> turnOn(CityData city, String from, String to, LastTrainTexts Function(int lastDep) texts) async {
    final route = RouteFinder(city).find(from, to);
    final dep = route == null ? null : lastDepartureMin(city, route);
    if (dep == null) return null;
    _fromId = from;
    _toId = to;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [from, to]);
    await _arm(dep, texts(dep));
    return dep;
  }

  Future<void> turnOff() async {
    _fromId = null;
    _toId = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await _call('lastTrainAlarmOff', {'slot': 'last'});
  }

  // ---- 始発アラーム: once, [leadMin] before the next first train ----

  static const _firstKey = 'firstTrainAlarm';
  String? _firstFrom;
  String? _firstTo;
  int _firstAt = 0; // when it rings (ms since epoch); after that it is off

  bool firstOnFor(String from, String to, {DateTime? now}) =>
      _firstFrom == from && _firstTo == to && _firstAt > (now ?? DateTime.now()).millisecondsSinceEpoch;

  Future<void> loadFirst() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getStringList(_firstKey);
    if (v != null && v.length == 3) {
      _firstFrom = v[0];
      _firstTo = v[1];
      _firstAt = int.tryParse(v[2]) ?? 0;
      notifyListeners();
    }
  }

  /// Rings once, [leadMin] minutes before the first train of [lineId] at
  /// [firstMin] (service minutes), [minutesAway] from [now].
  Future<void> turnOnFirst({
    required String from,
    required String to,
    required int firstMin,
    required int minutesAway,
    required LastTrainTexts texts,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    var at = clock.add(Duration(minutes: minutesAway - leadMin));
    // Too close to the first train: the phone sets it for the same time
    // tomorrow, so the bell stays on until then.
    if (!at.isAfter(clock)) at = at.add(const Duration(days: 1));
    _firstFrom = from;
    _firstTo = to;
    _firstAt = at.millisecondsSinceEpoch;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_firstKey, [from, to, '$_firstAt']);
    await _call('ensureNotificationPermission', null);
    await _call('lastTrainAlarm', {
      'slot': 'first',
      'minute': (firstMin - leadMin) % (24 * 60),
      'title': texts.title,
      'text': texts.body,
      'channel': texts.channel,
    });
  }

  Future<void> turnOffFirst() async {
    _firstFrom = null;
    _firstTo = null;
    _firstAt = 0;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstKey);
    await _call('lastTrainAlarmOff', {'slot': 'first'});
  }

  /// Sets the alarm again with fresh texts (language or timetable changes).
  Future<void> refresh(CityData city, LastTrainTexts Function(int lastDep) texts) async {
    final from = _fromId, to = _toId;
    if (from == null || to == null) return;
    if (!city.stations.containsKey(from) || !city.stations.containsKey(to)) return;
    final route = RouteFinder(city).find(from, to);
    final dep = route == null ? null : lastDepartureMin(city, route);
    if (dep == null) return;
    await _arm(dep, texts(dep));
  }

  Future<void> _arm(int lastDep, LastTrainTexts texts) async {
    await _call('ensureNotificationPermission', null);
    await _call('lastTrainAlarm', {
      'slot': 'last',
      // Clock time in Japan, 0..1439.
      'minute': (lastDep - leadMin) % (24 * 60),
      'title': texts.title,
      'text': texts.body,
      'channel': texts.channel,
    });
  }

  Future<void> _call(String method, Object? args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Tests and platforms without the native part.
    } on PlatformException {
      // A failed alarm must never break the app.
    }
  }

  /// "23:35" for a service minute.
  static String clock(int minute) => LineTimetable.clock(minute);
}
