import 'dart:convert';

import 'package:http/http.dart' as http;

/// Which JMA areas describe a city's weather (set in `assets/cities/<id>/city.json`).
class WeatherArea {
  const WeatherArea({required this.forecastOffice, required this.forecastArea, required this.amedasStation});

  factory WeatherArea.fromJson(Map<String, dynamic> json) => WeatherArea(
    forecastOffice: json['forecastOffice'] as String,
    forecastArea: json['forecastArea'] as String,
    amedasStation: json['amedas'] as String,
  );

  /// e.g. 130000 = 東京都 (forecast office code).
  final String forecastOffice;

  /// e.g. 130010 = 東京地方.
  final String forecastArea;

  /// AMeDAS observation point, e.g. 44132 = 東京 (北の丸公園).
  final String amedasStation;
}

enum WeatherKind { sunny, cloudy, rain, snow, unknown }

class WeatherNow {
  const WeatherNow({
    required this.kind,
    this.tempC,
    this.humidity,
    this.rainChance,
    this.observedAt,
    this.forecastKind,
    this.precipMm,
  });

  /// The weather now: from the rain gauge when it reports (raining or not
  /// right now), else today's forecast.
  final WeatherKind kind;

  /// Today's forecast (晴れ / くもり / 雨 / 雪), which can differ from now:
  /// a 雨 forecast while it is still dry means rain is coming.
  final WeatherKind? forecastKind;

  /// Rain or snow in the last 10 minutes (or hour), mm; null = not measured.
  final double? precipMm;

  /// Rain or snow is likely soon (forecast says so, or 50% or more).
  bool get wetLater => (rainChance ?? 0) >= 50 || forecastKind == WeatherKind.rain || forecastKind == WeatherKind.snow;

  final double? tempC;
  final int? humidity;
  final int? rainChance;
  final DateTime? observedAt;
}

abstract class WeatherSource {
  Future<WeatherNow> fetch(WeatherArea area);
}

/// Japan Meteorological Agency (気象庁) data. Free, commercial use allowed
/// under the Government of Japan Standard Terms of Use 2.0 with the credit
/// "出典：気象庁" (and a note that the data was processed).
/// These are the JSON files behind jma.go.jp; they are not a formal API and
/// may change without notice, so every field is read defensively.
class JmaWeatherSource implements WeatherSource {
  JmaWeatherSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://www.jma.go.jp/bosai';

  Future<String> _get(String url) async {
    final res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}', Uri.parse(url));
    }
    return utf8.decode(res.bodyBytes);
  }

  @override
  Future<WeatherNow> fetch(WeatherArea area) async {
    final latest = (await _get('$_base/amedas/data/latest_time.txt')).trim();
    final results = await Future.wait([
      _get('$_base/amedas/data/map/${amedasKey(latest)}.json'),
      _get('$_base/forecast/data/forecast/${area.forecastOffice}.json'),
    ]);
    return parseJma(
      area: area,
      amedasJson: jsonDecode(results[0]),
      forecastJson: jsonDecode(results[1]),
      latestTime: latest,
      now: DateTime.now(),
    );
  }

  /// "2026-11-17T09:20:00+09:00" → "20261117092000" (already Japan time).
  static String amedasKey(String latest) => latest.substring(0, 19).replaceAll(RegExp(r'[-T:]'), '');
}

WeatherKind weatherKindFromCode(String? code) => switch (code?.isNotEmpty == true ? code![0] : '') {
  '1' => WeatherKind.sunny,
  '2' => WeatherKind.cloudy,
  '3' => WeatherKind.rain,
  '4' => WeatherKind.snow,
  _ => WeatherKind.unknown,
};

/// Pure parsing, so it can be tested without the network.
WeatherNow parseJma({
  required WeatherArea area,
  required Object? amedasJson,
  required Object? forecastJson,
  required String latestTime,
  required DateTime now,
}) {
  double? temp;
  int? humidity;
  double? precip;
  try {
    final obs = (amedasJson as Map?)?[area.amedasStation] as Map?;
    if (obs != null) {
      temp = ((obs['temp'] as List?)?.first as num?)?.toDouble();
      humidity = ((obs['humidity'] as List?)?.first as num?)?.round();
      // Rain gauge: the last 10 minutes, else the last hour.
      precip =
          ((obs['precipitation10m'] as List?)?.first as num?)?.toDouble() ??
          ((obs['precipitation1h'] as List?)?.first as num?)?.toDouble();
    }
  } catch (_) {
    // Format changed: show "―" for these values.
  }

  var kind = WeatherKind.unknown;
  int? rainChance;
  try {
    final series = ((forecastJson as List).first as Map<String, dynamic>)['timeSeries'] as List;
    Map<String, dynamic>? areaIn(Map<String, dynamic> ts) {
      for (final a in ts['areas'] as List) {
        if (((a as Map<String, dynamic>)['area'] as Map)['code'] == area.forecastArea) {
          return a;
        }
      }
      return null;
    }

    final weather = areaIn(series[0] as Map<String, dynamic>);
    kind = weatherKindFromCode((weather?['weatherCodes'] as List?)?.first as String?);

    final popSeries = series[1] as Map<String, dynamic>;
    final times = [for (final t in popSeries['timeDefines'] as List) DateTime.parse(t as String)];
    final pops = areaIn(popSeries)?['pops'] as List?;
    if (pops != null) {
      // Each value covers 6 hours from its start time: pick the block we are in.
      for (var i = 0; i < times.length && i < pops.length; i++) {
        if (!now.isBefore(times[i])) {
          rainChance = int.tryParse(pops[i] as String);
        }
      }
      rainChance ??= int.tryParse(pops.first as String);
    }
  } catch (_) {
    // Format changed: keep what we have rather than failing the whole card.
  }

  // What is falling right now beats the day's forecast.
  final forecastKind = kind;
  if (precip != null) {
    if (precip > 0) {
      final cold = temp != null && (temp <= 1.5 || (forecastKind == WeatherKind.snow && temp <= 3));
      kind = cold ? WeatherKind.snow : WeatherKind.rain;
    } else if (kind == WeatherKind.rain || kind == WeatherKind.snow) {
      kind = WeatherKind.cloudy; // forecast rain, not falling yet
    }
  }

  return WeatherNow(
    kind: kind,
    forecastKind: forecastKind,
    precipMm: precip,
    tempC: temp,
    humidity: humidity,
    rainChance: rainChance,
    observedAt: DateTime.tryParse(latestTime),
  );
}
