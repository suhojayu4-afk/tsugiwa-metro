/// Simplified timetable: first/last train and how often trains come per time band.
/// Exact minute-by-minute timetables can come later from a RealtimeProvider (ODPT).
class LineTimetable {
  const LineTimetable({
    required this.firstTrainMin,
    required this.lastTrainMin,
    required this.weekday,
    required this.holiday,
  });

  factory LineTimetable.fromJson(Map<String, dynamic> json) => LineTimetable(
    firstTrainMin: parseClock(json['firstTrain'] as String),
    lastTrainMin: parseClock(json['lastTrain'] as String),
    weekday: _bands(json['weekday']),
    holiday: _bands(json['holiday']),
  );

  /// Minutes after midnight. Values over 24:00 mean "after midnight of the same service day".
  final int firstTrainMin;
  final int lastTrainMin;
  final List<HeadwayBand> weekday;
  final List<HeadwayBand> holiday;

  /// Minutes between trains at [time]. Service days start at 04:00.
  int headwayMinAt(DateTime time) {
    final isHoliday = time.weekday == DateTime.saturday || time.weekday == DateTime.sunday;
    final bands = isHoliday ? holiday : weekday;
    final minute = serviceMinute(time);
    for (final b in bands) {
      if (minute >= b.fromMin && minute < b.toMin) return b.everyMin;
    }
    return bands.isEmpty ? 5 : bands.last.everyMin;
  }

  /// Whether trains run at [time] (between first and last train, service day from 04:00).
  bool inService(DateTime time) {
    final m = serviceMinute(time);
    return m >= firstTrainMin && m <= lastTrainMin;
  }

  /// Minutes left until the last train leaves, while trains still run.
  int? minutesToLastTrain(DateTime time) {
    if (!inService(time)) return null;
    return lastTrainMin - serviceMinute(time);
  }

  /// Minutes until the next first train (after the last one, or early in
  /// the morning before it); null while trains run.
  int? minutesToFirstTrain(DateTime time) {
    if (inService(time)) return null;
    final m = serviceMinute(time);
    return m < firstTrainMin ? firstTrainMin - m : firstTrainMin + 24 * 60 - m;
  }

  /// After the last train of the service day (until 04:00).
  bool endedFor(DateTime time) => serviceMinute(time) > lastTrainMin;

  /// "05:00" style text; values past 24:00 wrap to the next morning (e.g. 24:15 → 00:15).
  static String clock(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static int serviceMinute(DateTime time) {
    final m = time.hour * 60 + time.minute;
    return m < 4 * 60 ? m + 24 * 60 : m;
  }

  static int parseClock(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static List<HeadwayBand> _bands(Object? raw) => [
    for (final b in raw as List? ?? const [])
      HeadwayBand(
        fromMin: parseClock((b as Map<String, dynamic>)['from'] as String),
        toMin: parseClock(b['to'] as String),
        everyMin: b['everyMin'] as int,
      ),
  ];
}

class HeadwayBand {
  const HeadwayBand({required this.fromMin, required this.toMin, required this.everyMin});
  final int fromMin;
  final int toMin;
  final int everyMin;
}
