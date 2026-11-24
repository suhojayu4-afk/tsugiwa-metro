import 'timetable.dart';

/// One stop of a real train: minutes after midnight of the service day
/// (00:30 = 1470), as on the published timetable.
class TrainStop {
  const TrainStop(this.stationId, this.arriveMin, this.departMin);
  final String stationId;
  final int arriveMin;
  final int departMin;
}

/// One real train on one line (from `trains.json`): 「1631D 普通 境港行き」.
class TrainRun {
  TrainRun({required this.no, required this.kind, required this.name, required this.to, required this.stops});

  factory TrainRun.fromJson(Map<String, dynamic> j) => TrainRun(
    no: j['no'] as String? ?? '',
    kind: j['kind'] as String? ?? '',
    name: j['name'] as String? ?? '',
    to: j['to'] as String? ?? '',
    stops: [
      for (final s in (j['stops'] as List).cast<List<dynamic>>())
        TrainStop(s[0] as String, (s[1] as num).toInt(), (s[2] as num).toInt()),
    ],
  );

  /// Train number (1631D).
  final String no;

  /// 普通 / 快速 / 特急.
  final String kind;

  /// Express name (スーパーまつかぜ), empty for ordinary trains.
  final String name;

  /// Where the train ends (it may run on past the map): 「境港」.
  final String to;
  final List<TrainStop> stops;

  late final Map<String, int> _index = {for (final (i, s) in stops.indexed) s.stationId: i};

  /// Position of [stationId] among the stops, or null when the train does not stop there.
  int? indexOf(String stationId) => _index[stationId];

  /// 「特急スーパーまつかぜ」 / 「普通」.
  String get label => name.isEmpty ? kind : '$kind$name';
}

/// A train leaving a station, found in the timetable.
class TrainDeparture {
  const TrainDeparture(this.run, this.fromIndex, this.dayOffsetMin);
  final TrainRun run;
  final int fromIndex;

  /// 0 today, 1440 for a train of the next service day.
  final int dayOffsetMin;

  TrainStop get from => run.stops[fromIndex];

  /// Leaving time in minutes of today's service day (may pass 24:00 and more).
  int get departMin => from.departMin + dayOffsetMin;

  /// Arrival at [stationId] in minutes of today's service day, or null.
  int? arriveMinAt(String stationId) {
    final i = run.indexOf(stationId);
    return i == null || i <= fromIndex ? null : run.stops[i].arriveMin + dayOffsetMin;
  }
}

/// Every real train of one line on weekdays and on 土休日.
class LineTrains {
  LineTrains({required this.weekday, required this.holiday});

  factory LineTrains.fromJson(Map<String, dynamic> j) => LineTrains(
    weekday: [for (final r in (j['weekday'] as List? ?? const [])) TrainRun.fromJson(r as Map<String, dynamic>)],
    holiday: [for (final r in (j['holiday'] as List? ?? const [])) TrainRun.fromJson(r as Map<String, dynamic>)],
  );

  final List<TrainRun> weekday;
  final List<TrainRun> holiday;

  bool get isEmpty => weekday.isEmpty && holiday.isEmpty;

  List<TrainRun> runsOn(DateTime jst) => LineTimetable.isHolidayService(jst) ? holiday : weekday;

  /// The next trains leaving [from] at or after [jst] (Japan time) that stop
  /// later at [to] (so they go the right way and get there), soonest first.
  /// Looks into the next service day when today's trains are over.
  List<TrainDeparture> next(String from, String to, DateTime jst, {int count = 1}) => _next(jst, count, (r) {
    final a = r.indexOf(from), b = r.indexOf(to);
    return a != null && b != null && a < b ? a : null;
  });

  /// The next trains leaving [from] towards the end of the line in [forward]
  /// direction ([order] = the line's stations), soonest first.
  List<TrainDeparture> nextWay(String from, List<String> order, bool forward, DateTime jst, {int count = 2}) {
    final at = order.indexOf(from);
    return _next(jst, count, (r) {
      final i = r.indexOf(from);
      if (i == null || i == r.stops.length - 1) return null;
      final nextAt = order.indexOf(r.stops[i + 1].stationId);
      return (nextAt > at) == forward ? i : null;
    });
  }

  List<TrainDeparture> _next(DateTime jst, int count, int? Function(TrainRun) boardAt) {
    final now = LineTimetable.serviceMinute(jst);
    final out = <TrainDeparture>[];
    for (final day in const [0, 1]) {
      final when = jst.add(Duration(days: day));
      final found = <TrainDeparture>[];
      for (final r in runsOn(when)) {
        final i = boardAt(r);
        if (i == null) continue;
        final d = TrainDeparture(r, i, day * 1440);
        if (d.departMin >= now) found.add(d);
      }
      found.sort((a, b) => a.departMin - b.departMin);
      out.addAll(found);
      if (out.length >= count) break;
    }
    return out.take(count).toList();
  }
}
