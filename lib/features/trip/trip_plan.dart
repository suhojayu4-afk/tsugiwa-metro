import '../../data/models/city.dart';
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
  TripPlan._(this.route, this.stops);

  factory TripPlan.build(CityData city, RouteResult route, DateTime boardingTime) {
    final stops = <TripStop>[];
    var t = 0;
    for (var li = 0; li < route.legs.length; li++) {
      final leg = route.legs[li];
      final line = city.line(leg.lineId);
      if (li == 0) {
        final first = leg.stationIds.first;
        stops.add(
          TripStop(
            stationId: first,
            lineId: leg.lineId,
            arriveSec: 0,
            departSec: 0,
            underground: city.station(first).isUndergroundOn(leg.lineId),
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
      for (var i = 1; i < leg.stationIds.length; i++) {
        t += line.runSecBetween(leg.stationIds[i - 1], leg.stationIds[i]);
        final arrive = t;
        final isLast = li == route.legs.length - 1 && i == leg.stationIds.length - 1;
        if (!isLast) t += line.dwellSec;
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
    return TripPlan._(route, stops);
  }

  final RouteResult route;
  final List<TripStop> stops;

  int get totalSec => stops.last.arriveSec;
  int get lastIndex => stops.length - 1;

  /// Line the user rides when leaving stop [index].
  String lineAt(int index) {
    final stop = stops[index];
    return stop.transferToLineId ?? (index < lastIndex ? stops[index + 1].lineId : stop.lineId);
  }
}
