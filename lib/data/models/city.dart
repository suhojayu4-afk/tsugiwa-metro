import '../../core/localized_text.dart';
import '../weather/weather_source.dart';
import 'rail_line.dart';
import 'station.dart';
import 'timetable.dart';

/// Everything the app knows about one city, loaded from `assets/cities/<id>/`.
class CityData {
  CityData({
    required this.id,
    required this.name,
    this.weather,
    required this.lines,
    required this.stations,
    required this.timetables,
    this.walks = const [],
  });

  /// Builds a city from already-decoded JSON and checks that the files agree.
  factory CityData.fromJson({
    required Map<String, dynamic> city,
    required List<dynamic> stations,
    required List<dynamic> lines,
    required Map<String, dynamic> timetables,
    List<dynamic> walks = const [],
  }) {
    final stationMap = {
      for (final s in stations) (s as Map<String, dynamic>)['id'] as String: Station.fromJson(s),
    };
    final lineMap = {
      for (final l in lines) (l as Map<String, dynamic>)['id'] as String: RailLine.fromJson(l),
    };
    final order = List<String>.from(city['lines'] as List);
    for (final lineId in order) {
      final line = lineMap[lineId];
      if (line == null) {
        throw FormatException('city.json lists unknown line $lineId');
      }
      for (final s in line.stations) {
        final station = stationMap[s];
        if (station == null) {
          throw FormatException('$lineId uses unknown station $s');
        }
        if (!station.lines.contains(lineId)) {
          throw FormatException('$s does not list $lineId in its "lines"');
        }
      }
    }
    return CityData(
      id: city['id'] as String,
      name: LocalizedText.fromJson(city['name'] as Map<String, dynamic>),
      weather: city['weather'] == null ? null : WeatherArea.fromJson(city['weather'] as Map<String, dynamic>),
      lines: [for (final id in order) lineMap[id]!],
      stations: stationMap,
      timetables: {
        for (final e in timetables.entries) e.key: LineTimetable.fromJson(e.value as Map<String, dynamic>),
      },
      walks: [
        for (final w in walks.cast<Map<String, dynamic>>())
          if (stationMap.containsKey(w['a']) && stationMap.containsKey(w['b']))
            WalkTransfer(w['a'] as String, w['b'] as String, w['min'] as int),
      ],
    );
  }

  final String id;
  final LocalizedText name;
  final WeatherArea? weather;
  final List<RailLine> lines;
  final Map<String, Station> stations;
  final Map<String, LineTimetable> timetables;

  /// Walking transfers between stations with different names (上野 ↔ 京成上野).
  final List<WalkTransfer> walks;

  /// Stations reachable on foot from [stationId], with the minutes.
  List<({String stationId, int minutes})> walksFrom(String stationId) => [
    for (final w in walks)
      if (w.a == stationId)
        (stationId: w.b, minutes: w.minutes)
      else if (w.b == stationId)
        (stationId: w.a, minutes: w.minutes),
  ];

  /// Minutes on foot between two different stations, or null.
  int? walkMin(String a, String b) {
    for (final w in walks) {
      if ((w.a == a && w.b == b) || (w.a == b && w.b == a)) return w.minutes;
    }
    return null;
  }

  RailLine line(String id) => lines.firstWhere((l) => l.id == id);
  Station station(String id) => stations[id]!;

  /// Average wait for the next train on [lineId] at [time], in seconds.
  int averageWaitSec(String lineId, DateTime time) {
    final tt = timetables[lineId];
    final headway = tt?.headwayMinAt(time) ?? 5;
    return headway * 60 ~/ 2;
  }
}

/// Two nearby stations with different names, connected on foot.
class WalkTransfer {
  const WalkTransfer(this.a, this.b, this.minutes);
  final String a;
  final String b;
  final int minutes;
}

class CityEntry {
  const CityEntry({required this.id, required this.name, required this.available});

  factory CityEntry.fromJson(Map<String, dynamic> json) => CityEntry(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
    available: json['status'] == 'available',
  );

  final String id;
  final LocalizedText name;
  final bool available;
}
