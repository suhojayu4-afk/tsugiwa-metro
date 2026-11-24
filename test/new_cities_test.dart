import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/models/city.dart';
import 'package:tsugiwa_metro/data/models/route_map.dart';
import 'package:tsugiwa_metro/features/settings/app_city.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';

/// Osaka, Fukuoka, Sendai and Sapporo (`tools/<city>/`): their data, maps and
/// the stations the MY shop's station scenes belong to.
const _cities = {
  'osaka': ['osaka.osaka', 'osaka.osakajokoen', 'osaka.shin-imamiya'],
  'fukuoka': ['fukuoka.nakasu-kawabata', 'fukuoka.nishijin'],
  'sendai': ['sendai.sendai', 'sendai.matsushima-kaigan'],
  'sapporo': ['sapporo.odori', 'sapporo.otaru'],
};

CityData loadCity(String id) {
  dynamic read(String f) => jsonDecode(File('assets/cities/$id/$f').readAsStringSync());
  return CityData.fromJson(
    city: read('city.json') as Map<String, dynamic>,
    stations: read('stations.json') as List<dynamic>,
    lines: read('lines.json') as List<dynamic>,
    timetables: read('timetables.json') as Map<String, dynamic>,
    walks: read('walks.json') as List<dynamic>,
    throughs: read('through.json') as List<dynamic>,
  );
}

void main() {
  final index = jsonDecode(File('assets/cities/index.json').readAsStringSync()) as Map<String, dynamic>;
  final pubspec = File('pubspec.yaml').readAsStringSync();

  for (final MapEntry(key: id, value: sceneStations) in _cities.entries) {
    group(id, () {
      final city = loadCity(id);
      final map = RouteMapData.fromJson(
        jsonDecode(File('assets/cities/$id/map.json').readAsStringSync()) as Map<String, dynamic>,
        const {},
      );

      test('listed, choosable, and its files are in the app', () {
        expect((index['cities'] as List).any((c) => c['id'] == id && c['status'] == 'available'), isTrue);
        expect(AppCity.choices, contains(id));
        expect(AppCity.names[id], isNotNull);
        for (final dir in ['assets/cities/$id/', 'assets/art/$id/landmarks/', 'assets/art/$id/map_tiles/']) {
          expect(pubspec, contains('- $dir'), reason: dir);
        }
        for (final p in ['day', 'evening', 'night']) {
          expect(File('assets/art/cities/scenes/${_defaultScene[id]}_$p.webp').existsSync(), isTrue);
        }
      });

      test('every line has a timetable, every stop is on the map', () {
        for (final line in city.lines) {
          expect(city.timetables[line.id], isNotNull, reason: line.id);
          final drawn = map.lines.firstWhere((l) => l.lineId == line.id);
          for (final s in line.stations) {
            expect(drawn.stops[s], isNotNull, reason: '$s on ${line.id}');
          }
        }
      });

      test('the station scenes have their stations, and routes reach them', () {
        final finder = RouteFinder(city);
        for (final s in sceneStations) {
          expect(city.stations[s], isNotNull, reason: s);
          expect(s.startsWith('$id.'), isTrue);
        }
        final r = finder.find(sceneStations.first, sceneStations.last, at: DateTime(2026, 11, 24, 12));
        expect(r, isNotNull);
      });

      test('map pictures and landmarks exist', () {
        expect(File(map.terrainImage).existsSync(), isTrue);
        for (final s in map.tileSets) {
          for (final h in s.have) {
            expect(File('${s.dir}/${s.prefix}$h.png').existsSync(), isTrue, reason: h);
          }
        }
        expect(map.landmarks.length, greaterThanOrEqualTo(8));
        for (final lm in map.landmarks) {
          expect(File(lm.image).existsSync(), isTrue, reason: lm.image);
        }
      });
    });
  }
}

const _defaultScene = {
  'osaka': 'osaka_umeda',
  'fukuoka': 'fukuoka_nakasu',
  'sendai': 'sendai_aoba',
  'sapporo': 'sapporo_odori',
};
