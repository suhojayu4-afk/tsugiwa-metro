import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/localized_text.dart';

/// One exit of a station and what is near it (`exits.json`).
class StationExit {
  const StationExit({required this.name, required this.near, this.landmarks = const []});
  final LocalizedText name;
  final LocalizedText near;

  /// Landmark pictures near this exit (e.g. 'ueno'), to match a destination.
  final List<String> landmarks;
}

/// A sightseeing model course: stations in order, each with its landmark.
class GuideCourse {
  const GuideCourse({
    required this.id,
    required this.name,
    required this.time,
    required this.about,
    required this.stops,
  });
  final String id;
  final LocalizedText name;

  /// '3h', '1d': rough time needed.
  final String time;
  final LocalizedText about;
  final List<({String station, String landmark})> stops;

  /// Stations of the course already stamped (stamp rally progress).
  int done(bool Function(String stationId) stamped) => stops.where((s) => stamped(s.station)).length;

  bool finished(bool Function(String stationId) stamped) => done(stamped) == stops.length;
}

/// The guide's data for a city: exits of the big stations and the courses.
class GuideData {
  const GuideData({this.exits = const {}, this.courses = const []});
  final Map<String, List<StationExit>> exits;
  final List<GuideCourse> courses;

  /// The exit nearest to [landmark] at [stationId], if the guide knows it.
  StationExit? exitFor(String stationId, String landmark) {
    for (final e in exits[stationId] ?? const <StationExit>[]) {
      if (e.landmarks.contains(landmark)) return e;
    }
    return null;
  }

  static LocalizedText _t(Object? v) => LocalizedText.fromJson(v! as Map<String, dynamic>);

  factory GuideData.fromJson({Map<String, dynamic>? exits, List<dynamic>? courses}) => GuideData(
    exits: {
      for (final e in (exits ?? const {}).entries)
        e.key: [
          for (final x in (e.value as List).cast<Map<String, dynamic>>())
            StationExit(
              name: _t(x['name']),
              near: _t(x['near']),
              landmarks: [for (final l in x['landmarks'] as List? ?? const []) l as String],
            ),
        ],
    },
    courses: [
      for (final c in (courses ?? const []).cast<Map<String, dynamic>>())
        GuideCourse(
          id: c['id'] as String,
          name: _t(c['name']),
          time: c['time'] as String,
          about: _t(c['about']),
          stops: [
            for (final s in (c['stops'] as List).cast<Map<String, dynamic>>())
              (station: s['station'] as String, landmark: s['landmark'] as String),
          ],
        ),
    ],
  );

  static final _cache = <String, Future<GuideData>>{};

  static Future<GuideData> load(String cityId) => _cache[cityId] ??= () async {
    Future<Object?> read(String f) async {
      try {
        return jsonDecode(await rootBundle.loadString('assets/cities/$cityId/$f'));
      } catch (_) {
        return null;
      }
    }

    return GuideData.fromJson(
      exits: await read('exits.json') as Map<String, dynamic>?,
      courses: await read('courses.json') as List<dynamic>?,
    );
  }();
}
