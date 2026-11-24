import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:shared_preferences/shared_preferences.dart';

import '../features/trip/route_finder.dart';
import '../features/trip/trip_plan.dart';
import '../core/japan_time.dart';
import 'models/city.dart';
import 'models/timetable.dart';

/// THE last train, for every card, tip, alarm and widget (service minutes,
/// Japan time; past 24:00 = after midnight):
/// - with a [route]: the last departure from its start that still makes every
///   connection on the way ([lastDepartureMin]);
/// - with only a [lineId] (a station, no destination yet): that line's last train.
/// Null without timetable data.
int? lastTrainMinOf(CityData city, {RouteResult? route, String? lineId}) {
  if (route != null) return lastDepartureMin(city, route);
  return lineId == null ? null : city.timetables[lineId]?.lastTrainMin;
}

/// Minutes left until [lastTrainMinOf] at [jst] (Japan time); null when the
/// trains are not running (before the first train or after that last one).
int? minutesToLast(CityData city, DateTime jst, {RouteResult? route, String? lineId}) {
  final last = lastTrainMinOf(city, route: route, lineId: lineId);
  if (last == null) return null;
  final first = city.timetables[route?.legs.first.lineId ?? lineId]?.firstTrainMin ?? 0;
  final now = LineTimetable.serviceMinute(jst);
  return now < first || now > last ? null : last - now;
}

/// The latest time (service minutes, Japan time; past 24:00 = after midnight)
/// to leave [route]'s start (on foot first, when it begins with a walk) and
/// still catch the last train of every line on the way. Null when no line on
/// the route has a timetable.
int? lastDepartureMin(CityData city, RouteResult route) {
  // Real trains (Tottori): the last one that still makes every change today.
  final real = lastRealDepartureMin(city, route, japanNow());
  if (real != null) return real;
  // Plan it late in the evening: waits between trains are the night ones.
  final plan = TripPlan.build(city, route, DateTime.utc(2026, 1, 5, 23), realTrains: false);
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
  return best == null ? null : best! - route.headWalkMin(city);
}

/// With real timetables on every leg: the latest departure from the start
/// (minus a walk there) whose trains connect all the way, on the service day
/// of [jst]. Null when a leg has no real trains, or none connects.
int? lastRealDepartureMin(CityData city, RouteResult route, DateTime jst) {
  var mustArrive = 1 << 30; // at the end of the leg being looked at
  int? dep;
  for (var li = route.legs.length - 1; li >= 0; li--) {
    final leg = route.legs[li];
    final trains = city.trains[leg.lineId];
    if (trains == null || leg.through) return null;
    int? best;
    for (final r in trains.runsOn(jst)) {
      final a = r.indexOf(leg.stationIds.first), b = r.indexOf(leg.stationIds.last);
      if (a == null || b == null || a >= b) continue;
      if (r.stops[b].arriveMin > mustArrive) continue;
      final d = r.stops[a].departMin;
      if (best == null || d > best) best = d;
    }
    if (best == null) return null;
    dep = best;
    if (li > 0) {
      final prev = route.legs[li - 1];
      final from = prev.stationIds.last, to = leg.stationIds.first;
      final walk = from == to ? city.station(to).transferWalkMin(prev.lineId, leg.lineId) : city.walkMin(from, to) ?? 5;
      mustArrive = best - walk;
    }
  }
  return dep == null ? null : dep - route.headWalkMin(city);
}

/// Lines on [route] whose last train is gone (or has not started yet) if you
/// leave its first station at [nowMin] (service minutes, Japan time).
Set<String> missedLines(CityData city, RouteResult route, int nowMin) {
  // Real trains (Tottori): follow the trains from now; the first leg with no
  // train left today is the missed one.
  if (route.legs.every((l) => city.trains.containsKey(l.lineId) && !l.through)) {
    var t = nowMin + route.headWalkMin(city);
    final day = japanNow();
    for (var li = 0; li < route.legs.length; li++) {
      final leg = route.legs[li];
      int? arrive;
      for (final r in city.trains[leg.lineId]!.runsOn(day)) {
        final a = r.indexOf(leg.stationIds.first), b = r.indexOf(leg.stationIds.last);
        if (a == null || b == null || a >= b || r.stops[a].departMin < t) continue;
        if (arrive == null || r.stops[b].arriveMin < arrive) arrive = r.stops[b].arriveMin;
      }
      if (arrive == null) return {leg.lineId};
      if (li + 1 < route.legs.length) {
        final next = route.legs[li + 1];
        final from = leg.stationIds.last, to = next.stationIds.first;
        t =
            arrive +
            (from == to ? city.station(to).transferWalkMin(leg.lineId, next.lineId) : city.walkMin(from, to) ?? 5);
      }
    }
    return const {};
  }
  final plan = TripPlan.build(city, route, DateTime.utc(2026, 1, 5, 23), realTrains: false);
  final out = <String>{};
  void check(String lineId, int boardSec) {
    final tt = city.timetables[lineId];
    if (tt == null) return;
    final board = nowMin + route.headWalkMin(city) + (boardSec / 60).ceil();
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

/// Whether the phone will really show the alarm that was just set.
enum AlarmNotice {
  /// Notifications are allowed (or there is no native part to ask: tests).
  on,

  /// Notifications are off for this app: the alarm is kept but stays silent
  /// until they are turned on in the phone's settings.
  off,

  /// The question was shown but the phone cannot tell us the answer.
  unsure,
}

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

  /// Waits while the system's permission question is open. True: it was
  /// shown and is closed now; false: it never came up; null: cannot tell.
  /// Tests put their own here.
  Future<bool?> Function() promptWait = _waitForPrompt;

  /// The system question covers the app: it leaves "resumed" and comes back.
  static Future<bool?> _waitForPrompt() async {
    final binding = WidgetsBinding.instance;
    if (binding.lifecycleState == null) return null;
    var shown = false;
    for (var i = 0; i < 15 && !shown; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      shown = binding.lifecycleState != AppLifecycleState.resumed;
    }
    if (!shown) return false;
    // Until the user answers (at most two minutes).
    for (var i = 0; i < 600 && binding.lifecycleState != AppLifecycleState.resumed; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return true;
  }

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
  /// sets it on the phone, asking for the notification permission when
  /// needed and waiting for the answer. Returns the last departure and
  /// whether the phone will show it, or null when the route has no
  /// last-train data (then nothing is set).
  Future<({int lastDep, AlarmNotice notice})?> turnOn(
    CityData city,
    String from,
    String to,
    LastTrainTexts Function(int lastDep) texts,
  ) async {
    final route = RouteFinder(city).find(from, to);
    final dep = route == null ? null : lastDepartureMin(city, route);
    if (dep == null) return null;
    _fromId = from;
    _toId = to;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [from, to]);
    final notice = await _arm('last', dep, texts(dep), ask: true);
    return (lastDep: dep, notice: notice);
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

  /// Rings once, [leadMin] minutes before the first train at [firstMin]
  /// (service minutes), [minutesAway] from [now]. Returns whether the phone
  /// will show it (see [turnOn]).
  Future<AlarmNotice> turnOnFirst({
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
    return _arm('first', firstMin, texts, ask: true);
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
  /// Runs at every launch, so it never asks for the permission.
  Future<void> refresh(CityData city, LastTrainTexts Function(int lastDep) texts) async {
    final from = _fromId, to = _toId;
    if (from == null || to == null) return;
    if (!city.stations.containsKey(from) || !city.stations.containsKey(to)) return;
    final route = RouteFinder(city).find(from, to);
    final dep = route == null ? null : lastDepartureMin(city, route);
    if (dep == null) return;
    await _arm('last', dep, texts(dep), ask: false);
  }

  /// Sets the [slot] alarm [leadMin] before [trainMin]. With [ask] the
  /// permission is asked for first and the answer waited for:
  /// - Android: `ensureNotificationPermission` opens the system question and
  ///   answers false at once, so the answer is read again once it is closed;
  /// - iPhone: the question comes with `lastTrainAlarm` itself, which only
  ///   returns after the answer; `ensureNotificationPermission` just reports.
  Future<AlarmNotice> _arm(String slot, int trainMin, LastTrainTexts texts, {required bool ask}) async {
    final asked = ask ? await _bool('ensureNotificationPermission') : null;
    await _call('lastTrainAlarm', {
      'slot': slot,
      // Clock time in Japan, 0..1439.
      'minute': (trainMin - leadMin) % (24 * 60),
      'title': texts.title,
      'text': texts.body,
      'channel': texts.channel,
    });
    if (!ask) return AlarmNotice.on;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final shown = asked == false && !ios ? await promptWait() : null;
    // The plain answer, where the native side has it.
    final sure = await _bool('notificationsAllowed');
    if (sure != null) return sure ? AlarmNotice.on : AlarmNotice.off;
    if (asked != false) return AlarmNotice.on;
    if (ios) return await _bool('ensureNotificationPermission') == true ? AlarmNotice.on : AlarmNotice.off;
    // Android without that answer: no question came up = refused for good.
    return shown == false ? AlarmNotice.off : AlarmNotice.unsure;
  }

  /// A yes / no from the native side; null when it has no such method.
  Future<bool?> _bool(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
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
