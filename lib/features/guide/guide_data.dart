import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/localized_text.dart';
import '../../data/congestion/congestion_source.dart';
import '../../data/weather/weather_source.dart';

/// What a tip is about (the attendant points for warnings).
enum TipKind { warn, help, fun }

class GuideTip {
  const GuideTip(this.kind, this.text, {this.id});
  final TipKind kind;
  final LocalizedText text;

  /// Stable name of a tip whose words change (minutes to the last train).
  final String? id;

  /// What tells two tips apart.
  String get key => id ?? text.ja;
}

/// The moment a tip is shown in: Japan time, the weather, the crowd, the route.
class TipMoment {
  const TipMoment({
    required this.hour,
    required this.weekday,
    required this.monthDay,
    this.weather,
    this.wetLater = false,
    this.tempC,
    this.crowd,
    this.hasRoute = false,
    this.changes = false,
    this.through = false,
  });

  /// [jst] is the time in Japan (its own fields are read, not its zone).
  factory TipMoment.at(
    DateTime jst, {
    WeatherNow? weather,
    CongestionLevel? crowd,
    bool hasRoute = false,
    bool changes = false,
    bool through = false,
  }) => TipMoment(
    hour: jst.hour,
    weekday: jst.weekday,
    monthDay: jst.month * 100 + jst.day,
    weather: weather == null || weather.kind == WeatherKind.unknown ? null : weather.kind,
    wetLater: weather?.wetLater ?? false,
    tempC: weather?.tempC,
    crowd: crowd,
    hasRoute: hasRoute,
    changes: changes,
    through: through,
  );

  /// 0–23 in Japan.
  final int hour;

  /// 1 = Monday … 7 = Sunday.
  final int weekday;

  /// month * 100 + day, e.g. 1122.
  final int monthDay;

  /// null = not known: no weather tips at all.
  final WeatherKind? weather;
  final bool wetLater;
  final double? tempC;
  final CongestionLevel? crowd;
  final bool hasRoute;

  /// The route has a change of trains (not a through run).
  final bool changes;

  /// The route runs through onto another line.
  final bool through;

  bool get wet => weather == WeatherKind.rain || weather == WeatherKind.snow;
}

/// One line of the attendant's general pool (`attendant_tips.json`) and when
/// it fits: hours and dates are Japan time, both ends of a date window count.
class PoolTip extends GuideTip {
  const PoolTip(
    super.kind,
    super.text, {
    required this.cat,
    this.hours,
    this.days,
    this.wx,
    this.crowd,
    this.day,
    this.need,
  });

  factory PoolTip.fromJson(Map<String, dynamic> j) {
    int md(Object? v) => int.parse((v! as String).replaceAll('-', ''));
    final h = j['h'] as List?, m = j['m'] as List?;
    return PoolTip(
      switch (j['k']) {
        'warn' => TipKind.warn,
        'fun' => TipKind.fun,
        _ => TipKind.help,
      },
      LocalizedText({'ja': j['ja'] as String, 'ko': j['ko'] as String, 'en': j['en'] as String}),
      cat: j['c'] as String,
      hours: h == null ? null : (h[0] as int, h[1] as int),
      days: m == null ? null : (md(m[0]), md(m[1])),
      wx: j['wx'] as String?,
      crowd: j['crowd'] as String?,
      day: j['day'] as String?,
      need: j['need'] as String?,
    );
  }

  /// greet, manners, howto, trivia, season, weather, crowd, app.
  final String cat;

  /// From this hour up to (not including) that one; may pass midnight.
  final (int, int)? hours;

  /// From this month-day to that one (month * 100 + day); may pass New Year.
  final (int, int)? days;

  /// rain, snow, wet (either), later (dry now, wet later), hot, cold, sunny, cloudy.
  final String? wx;

  /// busy or calm.
  final String? crowd;

  /// wd (Mon–Fri), we (Sat, Sun) or weekday digits such as "5".
  final String? day;

  /// route, transfer or through.
  final String? need;

  static bool _within(int v, (int, int) w, {required bool inclusive}) {
    final (a, b) = w;
    final end = inclusive ? v <= b : v < b;
    return a <= b ? v >= a && end : v >= a || end;
  }

  /// Whether this line belongs to the moment [m].
  bool fits(TipMoment m) {
    if (hours != null && !_within(m.hour, hours!, inclusive: false)) return false;
    if (days != null && !_within(m.monthDay, days!, inclusive: true)) return false;
    if (day != null) {
      final ok = switch (day!) {
        'wd' => m.weekday <= 5,
        'we' => m.weekday >= 6,
        final d => d.contains('${m.weekday}'),
      };
      if (!ok) return false;
    }
    if (wx != null) {
      final t = m.tempC;
      final ok =
          m.weather != null &&
          switch (wx!) {
            'rain' => m.weather == WeatherKind.rain,
            'snow' => m.weather == WeatherKind.snow,
            'wet' => m.wet,
            'later' => !m.wet && m.wetLater,
            'hot' => t != null && t >= 30,
            'cold' => t != null && t <= 5,
            'sunny' => m.weather == WeatherKind.sunny,
            'cloudy' => m.weather == WeatherKind.cloudy,
            _ => false,
          };
      if (!ok) return false;
    }
    if (crowd != null) {
      final ok = switch (crowd!) {
        'busy' => m.crowd == CongestionLevel.crowded || m.crowd == CongestionLevel.packed,
        'calm' => m.crowd == CongestionLevel.relaxed,
        _ => false,
      };
      if (!ok) return false;
    }
    return switch (need) {
      null => true,
      'route' => m.hasRoute,
      'transfer' => m.changes,
      'through' => m.through,
      _ => false,
    };
  }
}

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

/// The guide's data for a city: exits of the big stations, the courses, the
/// tips of each station (`tips.json`) and the attendant's general pool
/// (`attendant_tips.json`).
class GuideData {
  const GuideData({this.exits = const {}, this.courses = const [], this.stationTips = const {}, this.pool = const []});
  final Map<String, List<StationExit>> exits;
  final List<GuideCourse> courses;
  final Map<String, List<LocalizedText>> stationTips;
  final List<PoolTip> pool;

  /// The exit nearest to [landmark] at [stationId], if the guide knows it.
  StationExit? exitFor(String stationId, String landmark) {
    for (final e in exits[stationId] ?? const <StationExit>[]) {
      if (e.landmarks.contains(landmark)) return e;
    }
    return null;
  }

  static LocalizedText _t(Object? v) => LocalizedText.fromJson(v! as Map<String, dynamic>);

  factory GuideData.fromJson({
    Map<String, dynamic>? exits,
    List<dynamic>? courses,
    Map<String, dynamic>? tips,
    List<dynamic>? pool,
  }) => GuideData(
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
    stationTips: {
      for (final e in (tips ?? const {}).entries) e.key: [for (final t in e.value as List) _t(t)],
    },
    pool: [for (final p in (pool ?? const []).cast<Map<String, dynamic>>()) PoolTip.fromJson(p)],
  );

  static final _cache = <String, Future<GuideData>>{};

  /// Read once per city and kept: every screen shares the same lists.
  static Future<GuideData> load(String cityId) => _cache[cityId] ??= () async {
    Future<Object?> read(String f) async {
      try {
        // Not loadString: it starts an isolate for files over 50 kB, slower than reading these.
        final bytes = await rootBundle.load('assets/cities/$cityId/$f');
        return jsonDecode(utf8.decode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes)));
      } catch (_) {
        return null;
      }
    }

    return GuideData.fromJson(
      exits: await read('exits.json') as Map<String, dynamic>?,
      courses: await read('courses.json') as List<dynamic>?,
      tips: await read('tips.json') as Map<String, dynamic>?,
      pool: await read('attendant_tips.json') as List<dynamic>?,
    );
  }();
}
