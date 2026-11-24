import '../../data/models/city.dart';
import '../../data/models/train_run.dart';
import '../../l10n/app_localizations.dart';

/// 普通 / 快速 / 特急 in the reader's language; express names stay as printed.
String trainKindText(TrainRun run, String lang) {
  final kind = switch (lang) {
    'ko' => const {'普通': '보통', '快速': '쾌속', '特急': '특급'}[run.kind] ?? run.kind,
    'en' => const {'普通': 'Local', '快速': 'Rapid', '特急': 'Ltd. Exp.'}[run.kind] ?? run.kind,
    _ => run.kind,
  };
  return run.name.isEmpty ? kind : '$kind ${run.name}';
}

/// Where the train ends, in the reader's language when it is a station of the city.
String trainToText(CityData city, TrainRun run, String lang) {
  for (final s in city.stations.values) {
    if (s.name.ja == run.to) return s.name.of(lang);
  }
  return run.to;
}

/// 「普通 境港行き」.
String trainText(AppLocalizations t, CityData city, TrainDeparture d, String lang) =>
    t.trainAt(trainKindText(d.run, lang), trainToText(city, d.run, lang));

/// The next real trains of [lineId] from [from] that get to [to], or empty
/// when the line has no published timetable.
List<TrainDeparture> realDepartures(
  CityData city,
  String lineId,
  String from,
  String to,
  DateTime jst, {
  int count = 2,
}) => city.trains[lineId]?.next(from, to, jst, count: count) ?? const [];
