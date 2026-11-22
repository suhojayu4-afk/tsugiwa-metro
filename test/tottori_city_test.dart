import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/data/models/city.dart';
import 'package:tsugiwa_metro/data/models/route_map.dart';
import 'package:tsugiwa_metro/features/guide/guide_data.dart';
import 'package:tsugiwa_metro/features/settings/app_city.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';

dynamic _read(String f) => jsonDecode(File('assets/cities/tottori/$f').readAsStringSync());

CityData loadTottori() => CityData.fromJson(
  city: _read('city.json') as Map<String, dynamic>,
  stations: _read('stations.json') as List<dynamic>,
  lines: _read('lines.json') as List<dynamic>,
  timetables: _read('timetables.json') as Map<String, dynamic>,
  walks: _read('walks.json') as List<dynamic>,
  throughs: _read('through.json') as List<dynamic>,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final city = loadTottori();

  test('Tottori is received in 設定 before it can be used, and stays received', () async {
    SharedPreferences.setMockInitialValues({'settings.city': 'tottori'});
    await AppCity.load();
    expect(AppCity.current.value, 'tokyo', reason: 'not received yet');
    await AppCity.set('tottori');
    expect(AppCity.current.value, 'tokyo');
    await AppCity.receive('tottori');
    await AppCity.set('tottori');
    expect(AppCity.current.value, 'tottori');
    await AppCity.load();
    expect(AppCity.received.value, containsAll(['tokyo', 'tottori']));
    expect(AppCity.current.value, 'tottori');
  });
  final map = RouteMapData.fromJson(
    _read('map.json') as Map<String, dynamic>,
    _read('tips.json') as Map<String, dynamic>,
  );

  test('the city is listed and every line has a timetable', () {
    final index = jsonDecode(File('assets/cities/index.json').readAsStringSync()) as Map<String, dynamic>;
    expect((index['cities'] as List).any((c) => c['id'] == 'tottori' && c['status'] == 'available'), isTrue);
    for (final l in city.lines) {
      expect(city.timetables[l.id], isNotNull, reason: l.id);
      expect(l.stations.length, greaterThan(1), reason: l.id);
    }
  });

  test('every stop is on the map, lines straight or 45°', () {
    for (final line in city.lines) {
      final drawn = map.lines.firstWhere((l) => l.lineId == line.id);
      for (final id in line.stations) {
        expect(drawn.stops[id], isNotNull, reason: '$id on ${line.id}');
      }
      for (var i = 0; i + 1 < drawn.path.length; i++) {
        final d = drawn.path[i + 1] - drawn.path[i];
        final ok = d.dx.abs() < 0.5 || d.dy.abs() < 0.5 || (d.dx.abs() - d.dy.abs()).abs() < 0.5;
        expect(ok, isTrue, reason: '${line.id} segment $i: $d');
      }
    }
  });

  test('map pictures and landmarks exist', () {
    expect(File(map.terrainImage).existsSync(), isTrue);
    for (final s in map.tileSets) {
      for (final h in s.have) {
        expect(File('${s.dir}/${s.prefix}$h.png').existsSync(), isTrue, reason: h);
      }
    }
    expect(map.landmarks.length, 22);
    for (final lm in map.landmarks) {
      expect(File(lm.image).existsSync(), isTrue, reason: lm.image);
    }
    for (final p in ['day', 'evening', 'night']) {
      expect(File('assets/art/tottori/rural_$p.webp').existsSync(), isTrue);
    }
  });

  test('routes across the prefecture: Tottori to Sakaiminato, Wakasa to Yonago', () {
    final finder = RouteFinder(city);
    final a = finder.find('tottori.tottori', 'tottori.sakaiminato')!;
    expect(a.legs.last.lineId, 'tottori.sakai');
    final b = finder.find('tottori.wakasa', 'tottori.yonago')!;
    expect(b.legs.first.lineId, 'tottori.wakasa');
  });

  test('guide: courses and exits point at real stations and landmarks', () {
    final g = GuideData.fromJson(
      exits: _read('exits.json') as Map<String, dynamic>,
      courses: _read('courses.json') as List<dynamic>,
    );
    final keys = {for (final lm in map.landmarks) lm.image.split('/').last.replaceAll('.png', '')};
    expect(g.courses, isNotEmpty);
    for (final c in g.courses) {
      for (final s in c.stops) {
        expect(city.stations.containsKey(s.station), isTrue, reason: s.station);
        expect(keys, contains(s.landmark));
      }
    }
    for (final id in g.exits.keys) {
      expect(city.stations.containsKey(id), isTrue, reason: id);
    }
    final notes = _read('landmarks.json') as Map<String, dynamic>;
    expect(notes.keys.toSet(), keys);
  });

  test('MY shop: Tottori scenes, the railcar and a reward for each local line', () {
    final cat = jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>;
    final items = (cat['items'] as List).cast<Map<String, dynamic>>();
    final scenes = items.where((i) => (i['station'] as String? ?? '').startsWith('tottori.')).toList();
    expect(scenes, hasLength(4));
    for (final s in scenes) {
      expect(city.stations.containsKey(s['station']), isTrue, reason: s['id'] as String);
      for (final img in (s['images'] as Map).values) {
        expect(File(img as String).existsSync(), isTrue, reason: img);
      }
    }
    for (final line in ['sanin', 'sakai', 'inbi', 'wakasa', 'chizukyu', 'hakubi']) {
      expect(items.where((i) => i['unlock'] == 'line:tottori.$line'), hasLength(1), reason: line);
    }
    for (final art in ['assets/art/tottori/diesel', 'assets/art/tottori/sl']) {
      for (final f in [
        'front_base_day.webp',
        'front_base_evening.webp',
        'front_base_night.webp',
        'front_stripe.webp',
      ]) {
        expect(File('$art/$f').existsSync(), isTrue, reason: '$art/$f');
      }
    }
    expect(File('assets/art/tottori/diesel/side_base.webp').existsSync(), isTrue);
  });

  test('seasonal spots stand on the Tottori map', () {
    final s = _read('seasons.json') as Map<String, dynamic>;
    final keys = {for (final lm in map.landmarks) lm.image.split('/').last.replaceAll('.png', '')};
    for (final spot in (s['spots'] as List).cast<Map<String, dynamic>>()) {
      final lm = spot['landmark'] as String?;
      if (lm != null) expect(keys, contains(lm));
    }
  });
}
