import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/congestion/congestion_source.dart';
import 'package:tsugiwa_metro/features/guide/guide_data.dart';
import 'package:tsugiwa_metro/features/guide/guide_tips.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';

import 'trip_logic_test.dart' show loadTokyo;

void main() {
  final city = loadTokyo();
  Object read(String f) => jsonDecode(File('assets/cities/tokyo/$f').readAsStringSync()) as Object;
  final data = GuideData.fromJson(
    exits: read('exits.json') as Map<String, dynamic>,
    courses: read('courses.json') as List<dynamic>,
  );
  final landmarks = {
    for (final l in (read('map.json') as Map<String, dynamic>)['landmarks'] as List)
      ((l as Map<String, dynamic>)['image'] as String).split('/').last.split('.').first,
  };

  test('exits and courses point at real stations and landmarks', () {
    expect(data.exits.length, greaterThanOrEqualTo(10));
    for (final e in data.exits.entries) {
      expect(city.stations.containsKey(e.key), isTrue, reason: e.key);
      for (final x in e.value) {
        for (final lm in x.landmarks) {
          expect(landmarks.contains(lm), isTrue, reason: '${e.key}: $lm');
        }
      }
    }
    expect(data.courses.length, greaterThanOrEqualTo(5));
    for (final c in data.courses) {
      expect(c.stops.length, greaterThanOrEqualTo(2), reason: c.id);
      for (final st in c.stops) {
        expect(city.stations.containsKey(st.station), isTrue, reason: '${c.id}: ${st.station}');
        expect(landmarks.contains(st.landmark), isTrue, reason: '${c.id}: ${st.landmark}');
      }
    }
    expect(data.exitFor('tokyo.ueno', 'ueno')!.name.ja, '公園口');
  });

  test('stamp rally progress counts stamped course stations', () {
    final c = data.courses.firstWhere((c) => c.id == 'asakusa');
    bool stamped(String id) => id == 'tokyo.ueno' || id == 'tokyo.asakusa';
    expect(c.done(stamped), 2);
    expect(c.finished(stamped), isFalse);
    expect(c.finished((_) => true), isTrue);
  });

  test('tips: the last train first late at night, a long change, the exit at the destination, a greeting last', () {
    final route = RouteFinder(city).find('tokyo.shibuya', 'tokyo.ueno')!;
    // 00:00 in Japan: close to the last trains.
    final late = guideTips(
      city: city,
      data: data,
      now: DateTime.utc(2026, 11, 18, 15),
      lang: 'ja',
      route: route,
      fromId: 'tokyo.shibuya',
      toId: 'tokyo.ueno',
      crowd: CongestionLevel.normal,
      stamped: (_) => true,
      stayed: (_) => true,
    );
    expect(late.first.kind, TipKind.warn);
    expect(late.first.text.ja, contains('終電'));
    expect(late.any((t) => t.text.ja.contains('公園口')), isTrue);
    expect(late.last.kind, TipKind.fun);
    // Noon, no route: no last-train warning; a stamp nudge for a new station.
    final noon = guideTips(
      city: city,
      data: data,
      now: DateTime.utc(2026, 11, 18, 3),
      lang: 'ko',
      fromId: 'tokyo.shinjuku',
      stamped: (_) => false,
    );
    expect(noon.any((t) => t.text.ja.contains('終電')), isFalse);
    expect(noon.any((t) => t.text.of('ko').contains('스탬프')), isTrue);
  });
}
