import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/models/route_map.dart';

void main() {
  Map<String, dynamic> read(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final map = RouteMapData.fromJson(
    read('assets/cities/tokyo/map.json'),
    read('assets/cities/tokyo/tips.json'),
  );
  final lines = (jsonDecode(File('assets/cities/tokyo/lines.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  test('every station of every line has a place on the map', () {
    for (final line in lines) {
      final drawn = map.lines.firstWhere((l) => l.lineId == line['id']);
      for (final id in (line['stations'] as List).cast<String>()) {
        expect(drawn.stops[id], isNotNull, reason: '$id on ${line['id']}');
      }
    }
  });

  test('lines only use straight and 45° segments', () {
    for (final line in map.lines) {
      final pts = [...line.path, if (line.closed) line.path.first];
      for (var i = 0; i + 1 < pts.length; i++) {
        final d = pts[i + 1] - pts[i];
        final straight = d.dx.abs() < 0.5 || d.dy.abs() < 0.5;
        final diagonal = (d.dx.abs() - d.dy.abs()).abs() < 0.5;
        expect(straight || diagonal, isTrue, reason: '${line.lineId} segment $i: $d');
      }
    }
  });

  test('hanami spots change with the season in Japan; every decor picture exists', () {
    // 9 Nov 16:00 UTC is already 10 Nov 01:00 in Japan.
    expect(RouteMapData.seasonOf(DateTime.utc(2026, 11, 9, 16)), 'autumn');
    expect(RouteMapData.seasonOf(DateTime.utc(2026, 4, 1)), 'spring');
    expect(RouteMapData.seasonOf(DateTime.utc(2026, 7, 1)), 'other');
    Iterable<String> pics(DateTime t) =>
        RouteMapData.fromJson(read('assets/cities/tokyo/map.json'), const {}, now: t).decor.map((d) => d.image);
    final spring = pics(DateTime.utc(2026, 4, 1)), autumn = pics(DateTime.utc(2026, 11, 20));
    final summer = pics(DateTime.utc(2026, 7, 1));
    expect(spring.where((p) => p.contains('sakura_')), isNotEmpty);
    expect(autumn.where((p) => p.contains('momiji_')), isNotEmpty);
    expect(summer.where((p) => p.contains('sakura_') || p.contains('momiji_')), isEmpty);
    for (final p in {...spring, ...autumn, ...summer}) {
      expect(File(p).existsSync(), isTrue, reason: p);
    }
  });

  test('station card knows the neighbourhood and ward', () {
    expect(map.areaOf('tokyo.ginza', 'ja'), '銀座 · 中央区');
    expect(map.areaOf('tokyo.ginza', 'ko'), '긴자 · 주오구');
    expect(map.areaOf('tokyo.tokyo', 'en'), 'Marunouchi · Chiyoda');
    expect(map.areaOf('nowhere', 'ja'), isNull);
  });

  test('transfer stations are drawn on both lines; landmarks and tips are valid', () {
    for (final id in ['tokyo.ueno', 'tokyo.kanda', 'tokyo.shimbashi', 'tokyo.shibuya']) {
      expect(map.stopsOf(id).length, greaterThanOrEqualTo(2), reason: id);
    }
    for (final lm in map.landmarks) {
      expect(File(lm.image).existsSync(), isTrue, reason: lm.image);
    }
    expect(File(map.terrainImage).existsSync(), isTrue);
    final stationIds = {for (final l in lines) ...(l['stations'] as List).cast<String>()};
    expect(stationIds.containsAll(map.tips.keys), isTrue);
    expect(map.tips['tokyo.ueno'], isNotEmpty);
  });
}
