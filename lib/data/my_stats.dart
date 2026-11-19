import '../core/localized_text.dart';
import '../features/trip/trip_estimator.dart' show distanceMeters;
import 'models/city.dart';
import 'my_store.dart';

/// What the share card shows off: a level and a title from everything
/// ridden so far, and this month's rides.
class MyStats {
  MyStats._({
    required this.stamps,
    required this.linesDone,
    required this.trips,
    required this.level,
    required this.levelProgress,
    required this.title,
    required this.month,
    required this.lineProgress,
  });

  /// [now] is Japan time.
  factory MyStats.of(CityData city, MyStore store, {DateTime? now}) {
    final jst = now ?? DateTime.now().toUtc().add(const Duration(hours: 9));
    final stamps = city.stations.keys.where(store.stamped).length;
    final done = [
      for (final l in city.lines)
        if (store.lineComplete(l.id)) l.id,
    ];
    final trips = store.trips.length;
    // Points for everything ridden; each level needs a little more.
    final xp = stamps * 10 + trips * 4 + done.length * 120;
    var level = 1;
    var need = 40;
    var left = xp;
    while (left >= need) {
      left -= need;
      level++;
      need = 40 + level * 20;
    }
    final progress = [
      for (final l in city.lines)
        if (store.lineProgress(l.id).done > 0)
          (lineId: l.id, done: store.lineProgress(l.id).done, total: store.lineProgress(l.id).total),
    ]..sort((a, b) => (b.done / b.total).compareTo(a.done / a.total));
    return MyStats._(
      stamps: stamps,
      linesDone: done,
      trips: trips,
      level: level,
      levelProgress: left / need,
      title: _title(city, stamps, done, trips),
      month: MonthRides.of(city, store.trips, jst),
      lineProgress: progress,
    );
  }

  final int stamps;
  final List<String> linesDone;
  final int trips;
  final int level;

  /// 0 … 1 toward the next level.
  final double levelProgress;
  final LocalizedText title;
  final MonthRides month;

  /// Lines with at least one stamp, most complete first.
  final List<({String lineId, int done, int total})> lineProgress;

  static LocalizedText _title(CityData city, int stamps, List<String> done, int trips) {
    if (done.isNotEmpty) {
      // The longest finished line names you.
      final best = done.map(city.line).reduce((a, b) => a.stations.length >= b.stations.length ? a : b);
      if (done.length >= 5) {
        return const LocalizedText({'ja': '関東レールマスター', 'ko': '관동 레일 마스터', 'en': 'Kanto Rail Master'});
      }
      return LocalizedText({
        'ja': '${best.name.of('ja')}マスター',
        'ko': '${best.name.of('ko')} 마스터',
        'en': '${best.name.of('en')} Master',
      });
    }
    if (stamps >= 100) return const LocalizedText({'ja': '路線図の探検家', 'ko': '노선도 탐험가', 'en': 'Map Explorer'});
    if (stamps >= 50) return const LocalizedText({'ja': '乗りつぶし名人', 'ko': '역 모으기 달인', 'en': 'Station Collector'});
    if (stamps >= 20) return const LocalizedText({'ja': '通勤の達人', 'ko': '출퇴근 달인', 'en': 'Commute Pro'});
    if (stamps >= 5 || trips >= 5) {
      return const LocalizedText({'ja': 'となり駅の旅人', 'ko': '옆 역 여행자', 'en': 'Next-Stop Traveller'});
    }
    return const LocalizedText({'ja': 'はじめての乗客', 'ko': '새내기 승객', 'en': 'First-Time Rider'});
  }
}

/// This month's rides (Japan time).
class MonthRides {
  const MonthRides({
    required this.month,
    required this.trips,
    required this.stations,
    required this.km,
    this.topLine,
    this.earliest,
    this.latest,
  });

  factory MonthRides.of(CityData city, List<TripLog> log, DateTime jst) {
    final key = jst.toIso8601String().substring(0, 7);
    final mine = [
      for (final t in log)
        if (t.day.startsWith(key)) t,
    ];
    var metres = 0.0;
    final seen = <String>{};
    final lineCount = <String, int>{};
    for (final t in mine) {
      final ids = [
        for (final id in t.stations)
          if (city.stations.containsKey(id)) id,
      ];
      seen.addAll(ids);
      for (var i = 1; i < ids.length; i++) {
        final a = city.station(ids[i - 1]), b = city.station(ids[i]);
        metres += distanceMeters(a.lat, a.lng, b.lat, b.lng);
      }
      for (final l in t.lines) {
        lineCount[l] = (lineCount[l] ?? 0) + 1;
      }
    }
    String? top;
    for (final e in lineCount.entries) {
      if (city.lines.any((l) => l.id == e.key) && (top == null || e.value > lineCount[top]!)) top = e.key;
    }
    final minutes = [for (final t in mine) t.minute];
    // The day starts at 4:00 for trains: 0:30 is late, not early.
    int service(int m) => m < 240 ? m + 1440 : m;
    minutes.sort((a, b) => service(a).compareTo(service(b)));
    return MonthRides(
      month: jst.month,
      trips: mine.length,
      stations: seen.length,
      km: metres / 1000,
      topLine: top,
      earliest: minutes.firstOrNull,
      latest: minutes.lastOrNull,
    );
  }

  final int month;
  final int trips;
  final int stations;
  final double km;

  /// The line ridden most this month.
  final String? topLine;

  /// Minutes after midnight of the earliest and the latest ride.
  final int? earliest;
  final int? latest;

  static String clock(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}
