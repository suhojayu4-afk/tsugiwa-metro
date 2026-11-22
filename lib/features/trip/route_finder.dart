import '../../core/japan_time.dart';
import '../../data/models/city.dart';

/// One ride on a single line without changing trains.
class RouteLeg {
  const RouteLeg({required this.lineId, required this.forward, required this.stationIds, this.through = false});

  /// The train runs on from the previous leg's line: stay on, no change.
  final bool through;

  final String lineId;

  /// true = the line's "forward" direction (e.g. 内回り, 浅草方面).
  final bool forward;

  /// Boarding station first, alighting station last.
  final List<String> stationIds;

  int get stopCount => stationIds.length - 1;
}

class RouteResult {
  const RouteResult(this.legs, {this.walkFromId, this.walkToId});
  final List<RouteLeg> legs;

  /// The chosen start when the trip begins on foot to another station
  /// (原宿 → 明治神宮前 for the 千代田線); null when you board where you start.
  final String? walkFromId;

  /// The chosen destination when the trip ends on foot from [toId].
  final String? walkToId;

  /// Minutes on foot before the first train (0 without a walk).
  int headWalkMin(CityData city) => walkFromId == null ? 0 : city.walkMin(walkFromId!, fromId) ?? 5;

  /// Minutes on foot after the last train (0 without a walk).
  int tailWalkMin(CityData city) => walkToId == null ? 0 : city.walkMin(toId, walkToId!) ?? 5;

  int get stopCount => legs.fold(0, (sum, l) => sum + l.stopCount);
  int get transferCount => legs.length - 1;

  /// Where the first train is boarded and the last one left (see
  /// [walkFromId] / [walkToId] for a walk before or after).
  String get fromId => legs.first.stationIds.first;
  String get toId => legs.last.stationIds.last;

  /// Same lines, same stations: the same route.
  String get key => legs.map((l) => '${l.lineId}:${l.stationIds.join(',')}').join('|');
}

/// Finds the quickest route (fewest seconds, with a penalty for changing trains).
class RouteFinder {
  RouteFinder(this.city, {this.transferPenaltySec = 300});

  final CityData city;
  final int transferPenaltySec;

  /// [at]: Japan time (waits follow the timetable of that hour); now when
  /// left out. [avoid]: lines not to ride (e.g. those whose last train has gone).
  RouteResult? find(String fromId, String toId, {DateTime? at, Set<String> avoid = const {}}) {
    if (fromId == toId) return null;
    final time = at ?? japanNow();
    final edges = _buildEdges(time, avoid);

    final dist = <String, int>{};
    final prev = <String, _Edge>{};
    // Dijkstra with a binary heap: with 2,000+ stations (all of Kanto) a
    // linear search for the nearest open node each step is too slow.
    final open = _Heap();
    for (final lineId in city.station(fromId).lines) {
      if (avoid.contains(lineId)) continue;
      final key = _key(lineId, fromId);
      dist[key] = 0;
      open.push(0, key);
    }

    String? goal;
    while (open.isNotEmpty) {
      final (cost, current) = open.pop();
      if (cost > (dist[current] ?? 1 << 30)) continue; // an old, longer entry
      if (_stationOf(current) == toId) {
        goal = current;
        break;
      }
      for (final e in edges[current] ?? const <_Edge>[]) {
        final d = cost + e.cost;
        if (d < (dist[e.to] ?? 1 << 30)) {
          dist[e.to] = d;
          prev[e.to] = e;
          open.push(d, e.to);
        }
      }
    }
    if (goal == null) return null;

    // Walk back from the goal and group rides into legs.
    final path = <_Edge>[];
    for (var node = goal; prev.containsKey(node); node = prev[node]!.from) {
      path.add(prev[node]!);
    }
    final legs = <RouteLeg>[];
    var viaThrough = false;
    for (final e in path.reversed) {
      if (e.isTransfer) {
        viaThrough = e.through;
        continue;
      }
      final last = legs.isEmpty ? null : legs.last;
      if (last != null && last.lineId == e.lineId && last.forward == e.forward) {
        last.stationIds.add(_stationOf(e.to));
      } else {
        legs.add(
          RouteLeg(
            lineId: e.lineId,
            forward: e.forward,
            stationIds: [_stationOf(e.from), _stationOf(e.to)],
            through: viaThrough && last != null,
          ),
        );
      }
      viaThrough = false;
    }
    if (legs.isEmpty) return null;
    // A walk to or from a nearby station at either end is not a leg: keep it.
    final boardAt = legs.first.stationIds.first, leaveAt = legs.last.stationIds.last;
    return RouteResult(legs, walkFromId: boardAt == fromId ? null : fromId, walkToId: leaveAt == toId ? null : toId);
  }

  Map<String, List<_Edge>> _buildEdges(DateTime time, Set<String> avoid) {
    final edges = <String, List<_Edge>>{};
    void add(_Edge e) {
      if (avoid.contains(e.lineId) || avoid.contains(e.from.substring(0, e.from.indexOf('|')))) return;
      (edges[e.from] ??= []).add(e);
    }

    for (final line in city.lines) {
      if (avoid.contains(line.id)) continue;
      final n = line.stations.length;
      for (var i = 0; i < line.segmentCount; i++) {
        final a = line.stations[i];
        final b = line.stations[(i + 1) % n];
        final cost = line.runSec[i] + line.dwellSec;
        add(_Edge(_key(line.id, a), _key(line.id, b), cost, line.id, forward: true));
        add(_Edge(_key(line.id, b), _key(line.id, a), cost, line.id, forward: false));
      }
    }
    // Through trains: stay on (no walk, no wait) but only in the direction
    // the train carries on in - a node 'line|station>next' leads only there.
    for (final t in city.throughs) {
      if (avoid.contains(t.a) || avoid.contains(t.b)) continue;
      final line = city.line(t.b);
      final n = line.stations.length;
      final i = line.stations.indexOf(t.at);
      final j = line.stations.indexOf(t.toward);
      if (i < 0 || j < 0) continue;
      final forward = line.loop ? (i + 1) % n == j : j == i + 1;
      final seg = forward ? i : (line.loop ? (j % n) : j);
      final ride = line.runSec[seg] + line.dwellSec;
      final via = '${_key(t.b, t.at)}>${t.toward}';
      add(_Edge(_key(t.a, t.at), via, 0, t.b, isTransfer: true, through: true));
      add(_Edge(via, _key(t.b, t.toward), ride, t.b, forward: forward));
    }
    for (final station in city.stations.values) {
      for (final from in station.lines) {
        for (final to in station.lines) {
          if (from == to) continue;
          final cost = station.transferWalkMin(from, to) * 60 + city.averageWaitSec(to, time) + transferPenaltySec;
          add(_Edge(_key(from, station.id), _key(to, station.id), cost, to, isTransfer: true));
        }
      }
    }
    // On foot to a nearby station with another name (上野 → 京成上野).
    for (final w in city.walks) {
      for (final (from, to) in [(w.a, w.b), (w.b, w.a)]) {
        for (final fromLine in city.station(from).lines) {
          for (final toLine in city.station(to).lines) {
            final cost = w.minutes * 60 + city.averageWaitSec(toLine, time) + transferPenaltySec;
            add(_Edge(_key(fromLine, from), _key(toLine, to), cost, toLine, isTransfer: true));
          }
        }
      }
    }
    return edges;
  }

  static String _key(String lineId, String stationId) => '$lineId|$stationId';
  static String _stationOf(String key) {
    final s = key.substring(key.indexOf('|') + 1);
    final cut = s.indexOf('>');
    return cut < 0 ? s : s.substring(0, cut);
  }
}

class _Edge {
  const _Edge(
    this.from,
    this.to,
    this.cost,
    this.lineId, {
    this.forward = true,
    this.isTransfer = false,
    this.through = false,
  });
  final String from;
  final String to;
  final int cost;
  final String lineId;
  final bool forward;
  final bool isTransfer;

  /// A through train onto another line (no change).
  final bool through;
}

/// Smallest-cost-first queue of (cost, node) pairs.
class _Heap {
  final _costs = <int>[];
  final _keys = <String>[];

  bool get isNotEmpty => _costs.isNotEmpty;

  void push(int cost, String key) {
    _costs.add(cost);
    _keys.add(key);
    var i = _costs.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_costs[p] <= _costs[i]) break;
      _swap(i, p);
      i = p;
    }
  }

  (int, String) pop() {
    final top = (_costs.first, _keys.first);
    final lastCost = _costs.removeLast(), lastKey = _keys.removeLast();
    if (_costs.isNotEmpty) {
      _costs[0] = lastCost;
      _keys[0] = lastKey;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _costs.length && _costs[l] < _costs[m]) m = l;
        if (r < _costs.length && _costs[r] < _costs[m]) m = r;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final c = _costs[a];
    _costs[a] = _costs[b];
    _costs[b] = c;
    final k = _keys[a];
    _keys[a] = _keys[b];
    _keys[b] = k;
  }
}
