import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/models/city.dart';
import 'package:tsugiwa_metro/data/models/timetable.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';
import 'package:tsugiwa_metro/features/platform/nearest_station.dart';

CityData loadTokyo() {
  dynamic read(String f) => jsonDecode(File('assets/cities/tokyo/$f').readAsStringSync());
  return CityData.fromJson(
    city: read('city.json') as Map<String, dynamic>,
    stations: read('stations.json') as List<dynamic>,
    lines: read('lines.json') as List<dynamic>,
    timetables: read('timetables.json') as Map<String, dynamic>,
    walks: read('walks.json') as List<dynamic>,
  );
}

void main() {
  final city = loadTokyo();

  group('nearest station', () {
    test('a point by Shibuya scramble finds Shibuya', () {
      final n = nearestStation(city, 35.6595, 139.7005)!;
      expect(n.station.id, 'tokyo.shibuya');
      expect(n.meters, lessThan(300));
    });

    test('far away (Osaka) finds nothing', () {
      expect(nearestStation(city, 34.7025, 135.4959), isNull);
    });
  });

  group('timetable helpers', () {
    final ginza = city.timetables['tokyo.ginza']!;
    test('in service at noon, not at 02:00', () {
      expect(ginza.inService(DateTime(2026, 11, 17, 12)), isTrue);
      expect(ginza.inService(DateTime(2026, 11, 18, 2)), isFalse);
    });
    test('clock wraps after midnight', () {
      expect(LineTimetable.clock(ginza.lastTrainMin), '00:15');
      expect(LineTimetable.clock(ginza.firstTrainMin), '05:00');
    });
  });

  group('JMA weather parsing', () {
    final area = city.weather!;
    final amedas = {
      '44132': {
        'temp': [12.7, 0],
        'humidity': [77, 0],
      },
    };
    final forecast = [
      {
        'timeSeries': [
          {
            'timeDefines': ['2026-11-17T05:00:00+09:00'],
            'areas': [
              {
                'area': {'name': '東京地方', 'code': '130010'},
                'weatherCodes': ['214'],
              },
            ],
          },
          {
            'timeDefines': ['2026-11-17T06:00:00+09:00', '2026-11-17T12:00:00+09:00', '2026-11-17T18:00:00+09:00'],
            'areas': [
              {
                'area': {'name': '東京地方', 'code': '130010'},
                'pops': ['10', '20', '40'],
              },
            ],
          },
        ],
      },
    ];

    test('reads temperature, humidity, kind and the current rain block', () {
      final w = parseJma(
        area: area,
        amedasJson: amedas,
        forecastJson: forecast,
        latestTime: '2026-11-17T13:20:00+09:00',
        now: DateTime.parse('2026-11-17T13:20:00+09:00'),
      );
      expect(w.tempC, 12.7);
      expect(w.humidity, 77);
      expect(w.kind, WeatherKind.cloudy);
      expect(w.rainChance, 20);
    });

    test('survives a changed format without throwing', () {
      final w = parseJma(
        area: area,
        amedasJson: {},
        forecastJson: {'unexpected': true},
        latestTime: 'bad',
        now: DateTime(2026),
      );
      expect(w.kind, WeatherKind.unknown);
      expect(w.tempC, isNull);
    });

    test('the rain gauge decides if it is raining now', () {
      WeatherNow at(Map<String, dynamic> obs, String code) => parseJma(
        area: area,
        amedasJson: {area.amedasStation: obs},
        forecastJson: [
          {
            'timeSeries': [
              {
                'timeDefines': ['2026-11-17T05:00:00+09:00'],
                'areas': [
                  {
                    'area': {'code': area.forecastArea},
                    'weatherCodes': [code],
                  },
                ],
              },
              {'timeDefines': [], 'areas': []},
            ],
          },
        ],
        latestTime: '2026-11-17T13:20:00+09:00',
        now: DateTime.parse('2026-11-17T13:20:00+09:00'),
      );
      // 曇り時々雨 forecast, but it is raining now.
      var w = at({
        'temp': [12.0, 0],
        'precipitation10m': [0.5, 0],
      }, '202');
      expect(w.kind, WeatherKind.rain);
      expect(w.forecastKind, WeatherKind.cloudy);
      // Rain forecast, still dry: cloudy now, rain coming.
      w = at({
        'temp': [12.0, 0],
        'precipitation10m': [0.0, 0],
      }, '300');
      expect(w.kind, WeatherKind.cloudy);
      expect(w.wetLater, isTrue);
      // Falling at 1 °C: snow.
      w = at({
        'temp': [1.0, 0],
        'precipitation10m': [1.0, 0],
      }, '200');
      expect(w.kind, WeatherKind.snow);
      // No gauge: the forecast stands.
      w = at({
        'temp': [12.0, 0],
      }, '300');
      expect(w.kind, WeatherKind.rain);
    });

    test('AMeDAS file key', () {
      expect(JmaWeatherSource.amedasKey('2026-11-17T09:20:00+09:00'), '20261117092000');
    });
  });
}
