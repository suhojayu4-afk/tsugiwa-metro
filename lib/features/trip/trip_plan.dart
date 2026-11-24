import 'dart:math' as math;

import '../../data/models/city.dart';
import '../../data/models/timetable.dart';
import '../../data/models/train_run.dart';
import 'route_finder.dart';

/// One station on the trip, with the time (seconds after boarding) the train
/// should arrive and leave.
class TripStop {
  const TripStop({
    required this.stationId,
    required this.lineId,
    required this.arriveSec,
    required this.departSec,
    required this.underground,
    this.transferToLineId,
    this.walkToStationId,
    this.through = false,
  });

  final String stationId;

  /// Line the user is on when arriving here (for the first stop: the first line).
  final String lineId;
  final int arriveSec;
  final int departSec;

  /// GPS is ignored on underground stops; the timetable estimate is used instead.
  final bool underground;

  /// Set when the user changes trains here.
  final String? transferToLineId;

  /// Set when the change means walking to another station (上野 → 京成上野).
  final String? walkToStationId;

  /// The train runs on onto [transferToLineId]: stay on.
  final bool through;
}

/// A route turned into a timeline. Built once when tracking starts.
class TripPlan {
  TripPlan._(this.route, this.stops, [this.trains = const []]);

  /// [boardingTime]: Japan time (see `japanNow`); waits at changes follow the
  /// timetable of that hour.
  /// [realTrains] false = intervals only, even where real trains are known
  /// (the last-train sums plan a typical night, not a given one).
  factory TripPlan.build(CityData city, RouteResult route, DateTime boardingTime, {bool realTrains = true}) {
    final stops = <TripStop>[];
    final trains = <TrainDeparture?>[];
    // Seconds into the service day at boarding: real trains leave at clock times.
    final startSec = LineTimetable.serviceMinute(boardingTime) * 60 + boardingTime.second;
    var t = 0;
    for (var li = 0; li < route.legs.length; li++) {
      final leg = route.legs[li];
      final line = city.line(leg.lineId);
      // The real train for this leg (Tottori): the first one leaving after
      // the user can be on the platform. Null = follow the intervals.
      TrainDeparture? train;
      int readyAt() => li == 0 ? 0 : stops.last.arriveSec + _walkSec(city, route, li);
      final real = leg.through || !realTrains ? null : city.trains[leg.lineId];
      if (real != null) {
        final ready = boardingTime.add(Duration(seconds: readyAt()));
        final found = real.next(leg.stationIds.first, leg.stationIds.last, ready);
        if (found.isNotEmpty) train = found.first;
      }
      trains.add(train);
      if (li == 0) {
        final first = leg.stationIds.first;
        stops.add(
          TripStop(
            stationId: first,
            lineId: leg.lineId,
            arriveSec: 0,
            departSec: train == null ? 0 : math.max(0, train.departMin * 60 - startSec),
            underground: city.station(first).isUndergroundOn(leg.lineId),
          ),
        );
        t = stops.first.departSec;
      } else if (train != null) {
        final arrived = stops.removeLast();
        t = math.max(readyAt(), train.departMin * 60 - startSec);
        stops.add(
          TripStop(
            stationId: arrived.stationId,
            lineId: arrived.lineId,
            arriveSec: arrived.arriveSec,
            departSec: t,
            underground: arrived.underground,
            transferToLineId: leg.lineId,
            walkToStationId: leg.stationIds.first == arrived.stationId ? null : leg.stationIds.first,
          ),
        );
      } else {
        // Change trains: walk, then wait about half the interval between trains.
        final from = route.legs[li - 1].stationIds.last;
        final to = leg.stationIds.first;
        final prevLine = route.legs[li - 1].lineId;
        final walkMin = from == to
            ? city.station(to).transferWalkMin(prevLine, leg.lineId)
            : city.walkMin(from, to) ?? 5;
        // A through train just stops there as usual; otherwise walk, then wait.
        final wait = leg.through
            ? line.dwellSec
            : walkMin * 60 + city.averageWaitSec(leg.lineId, boardingTime.add(Duration(seconds: t)));
        final arrived = stops.removeLast();
        t = arrived.arriveSec + wait;
        stops.add(
          TripStop(
            stationId: arrived.stationId,
            lineId: arrived.lineId,
            arriveSec: arrived.arriveSec,
            departSec: t,
            underground: arrived.underground,
            transferToLineId: leg.lineId,
            walkToStationId: from == to ? null : to,
            through: leg.through,
          ),
        );
      }
      final leaveSec = t;
      for (var i = 1; i < leg.stationIds.length; i++) {
        final isLast = li == route.legs.length - 1 && i == leg.stationIds.length - 1;
        final at = train?.run.indexOf(leg.stationIds[i]);
        final int arrive;
        if (train != null && at != null && at > train.fromIndex) {
          // As printed: minutes after the train left the boarding station.
          final s = train.run.stops[at];
          arrive = math.max(t, leaveSec + (s.arriveMin - train.from.departMin) * 60);
          t = isLast ? arrive : math.max(arrive, leaveSec + (s.departMin - train.from.departMin) * 60);
        } else {
          // Passed through (or no timetable): the usual run time.
          t += line.runSecBetween(leg.stationIds[i - 1], leg.stationIds[i]);
          arrive = t;
          if (!isLast && train == null) t += line.dwellSec;
        }
        final id = leg.stationIds[i];
        stops.add(
          TripStop(
            stationId: id,
            lineId: leg.lineId,
            arriveSec: arrive,
            departSec: t,
            underground: city.station(id).isUndergroundOn(leg.lineId),
          ),
        );
      }
    }
    return TripPlan._(route, stops, trains);
  }

  /// Walk minutes (in seconds) at the change before leg [li].
  static int _walkSec(CityData city, RouteResult route, int li) {
    final from = route.legs[li - 1].stationIds.last;
    final to = route.legs[li].stationIds.first;
    final walkMin = from == to
        ? city.station(to).transferWalkMin(route.legs[li - 1].lineId, route.legs[li].lineId)
        : city.walkMin(from, to) ?? 5;
    return walkMin * 60;
  }

  final RouteResult route;
  final List<TripStop> stops;

  /// The real train of each leg (same order as `route.legs`), where the
  /// line has a published timetable; null where times are estimates.
  final List<TrainDeparture?> trains;

  /// Every leg rides a real, timetabled train.
  bool get timetabled => trains.isNotEmpty && trains.every((t) => t != null);

  int get totalSec => stops.last.arriveSec;

  /// On board and changing, without the wait for the first train.
  int get rideSec => totalSec - stops.first.departSec;
  int get lastIndex => stops.length - 1;

  /// The real train the user takes when leaving stop [index], if known.
  TrainDeparture? trainLeaving(int index) {
    if (trains.isEmpty || index >= lastIndex) return null;
    var leg = 0;
    for (var i = 1; i <= index; i++) {
      if (stops[i].transferToLineId != null && !stops[i].through) leg++;
    }
    return leg < trains.length ? trains[leg] : null;
  }

  /// Line the user rides when leaving stop [index].
  String lineAt(int index) {
    final stop = stops[index];
    return stop.transferToLineId ?? (index < lastIndex ? stops[index + 1].lineId : stop.lineId);
  }
}
