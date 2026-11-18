import '../../data/models/city.dart';

/// One ride on a single line without changing trains.
class RouteLeg {
  const RouteLeg({required this.lineId, required this.forward, required this.stationIds});

  final String lineId;

  /// true = the line's "forward" direction (e.g. 内回り, 浅草方面).
  final bool forward;

  /// Boarding station first, alighting station last.
  final List<String> stationIds;

  int get stopCount => stationIds.length - 1;
}

class RouteResult {
  const RouteResult(this.legs);
  final List<RouteLeg> legs;

  int get stopCount => legs.fold(0, (sum, l) => sum + l.stopCount);
  int get transferCount => legs.length - 1;
  String get fromId => legs.first.stationIds.first;
  String get toId => legs.last.stationIds.last;
}

/// Finds the quickest route (fewest seconds, with a penalty for changing trains).
class RouteFinder {
  RouteFinder(this.city, {this.transferPenaltySec = 180});

  final CityData city;
  final int transferPenaltySec;

  /// [avoid]: lines not to ride (e.g. those whose last train has gone).
  RouteResult? find(String fromId, String toId, {DateTime? at, Set<String> avoid = const {}}) {
    if (fromId == toId) return null;
    final time = at ?? DateTime.now();
    final edges = _buildEdges(time, avoid);

    final dist = <String, int>{};
    final prev = <String, _Edge>{};
    final open = <String>{};
    for (final lineId in city.station(fromId).lines) {
      if (avoid.contains(lineId)) continue;
      final key = _key(lineId, fromId);
      dist[key] = 0;
      open.add(key);
    }

    String? goal;
    while (open.isNotEmpty) {
      final current = open.reduce((a, b) => dist[a]! <= dist[b]! ? a : b);
      open.remove(current);
      if (_stationOf(current) == toId) {
        goal = current;
        break;
      }
      for (final e in edges[current] ?? const <_Edge>[]) {
        final d = dist[current]! + e.cost;
        if (d < (dist[e.to] ?? 1 << 30)) {
          dist[e.to] = d;
          prev[e.to] = e;
          open.add(e.to);
        }
      }
    }
    if (goal == null) return null;

    // Walk back from the goal and group rides into legs.
    final path = <_Edge>[];
    for (var node = goal; prev.containsKey(node); node = prev[node]!.from) {
      path.add(prev[node]!);
    }
    final rides = path.reversed.where((e) => !e.isTransfer).toList();
    final legs = <RouteLeg>[];
    for (final ride in rides) {
      final last = legs.isEmpty ? null : legs.last;
      if (last != null && last.lineId == ride.lineId && last.forward == ride.forward) {
        last.stationIds.add(_stationOf(ride.to));
      } else {
        legs.add(
          RouteLeg(
            lineId: ride.lineId,
            forward: ride.forward,
            stationIds: [_stationOf(ride.from), _stationOf(ride.to)],
          ),
        );
      }
    }
    return legs.isEmpty ? null : RouteResult(legs);
  }

  Map<String, List<_Edge>> _buildEdges(DateTime time, Set<String> avoid) {
    final edges = <String, List<_Edge>>{};
    void add(_Edge e) {
      if (avoid.contains(e.lineId) || avoid.contains(e.from.substring(0, e.from.indexOf('|')))) return;
      (edges[e.from] ??= []).add(e);
    }

    for (final line in city.lines) {
      final n = line.stations.length;
      for (var i = 0; i < line.segmentCount; i++) {
        final a = line.stations[i];
        final b = line.stations[(i + 1) % n];
        final cost = line.runSec[i] + line.dwellSec;
        add(_Edge(_key(line.id, a), _key(line.id, b), cost, line.id, forward: true));
        add(_Edge(_key(line.id, b), _key(line.id, a), cost, line.id, forward: false));
      }
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
  static String _stationOf(String key) => key.substring(key.indexOf('|') + 1);
}

class _Edge {
  const _Edge(this.from, this.to, this.cost, this.lineId, {this.forward = true, this.isTransfer = false});
  final String from;
  final String to;
  final int cost;
  final String lineId;
  final bool forward;
  final bool isTransfer;
}
