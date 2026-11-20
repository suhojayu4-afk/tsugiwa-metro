import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/car_guide.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';

void main() {
  final raw = jsonDecode(File('assets/cities/tokyo/cars.json').readAsStringSync()) as Map<String, dynamic>;
  final guide = CarGuide.fromJson(raw);
  final stations = {
    for (final s in jsonDecode(File('assets/cities/tokyo/stations.json').readAsStringSync()) as List)
      (s as Map<String, dynamic>)['id'] as String: s,
  };

  test('every entry is well formed, sourced and points at real lines/stations', () {
    var count = 0;
    for (final line in (raw['lines'] as Map<String, dynamic>).entries) {
      final cars = line.value['cars'] as int;
      final dirs = line.value['directions'] as Map<String, dynamic>;
      for (final dir in dirs.entries) {
        expect(dir.key, anyOf('forward', 'reverse'));
        final front = dir.value['frontCar'] as int;
        expect(front == 1 || front == cars, isTrue);
        for (final st in (dir.value['stations'] as Map<String, dynamic>).entries) {
          final station = stations[st.key];
          expect(station, isNotNull, reason: st.key);
          final served = List<String>.from(station!['lines'] as List);
          expect(served, contains(line.key), reason: '${line.key} at ${st.key}');
          for (final e in (st.value as List).cast<Map<String, dynamic>>()) {
            count++;
            final to = e['to'] as String;
            if (!to.startsWith('exit:')) expect(served, contains(to), reason: '$to at ${st.key}');
            expect(e['car'], inInclusiveRange(1, cars));
            if (e['door'] != null) expect(e['door'], inInclusiveRange(1, 4));
            expect((e['source'] as String).startsWith('https://'), isTrue, reason: '$to at ${st.key}');
          }
        }
      }
    }
    expect(count, greaterThan(0));
  });

  test('Yamanote layout: 内回り has 11号車 in front, door 4 first', () {
    final inner = guide.layout('tokyo.yamanote', true)!;
    expect(inner.frontToBack.first, 11);
    expect(inner.doorSlot(4), 0);
    final outer = guide.layout('tokyo.yamanote', false)!;
    expect(outer.frontToBack.first, 1);
    expect(outer.doorSlot(1), 0);
  });

  test('transfer lookup picks the spot for the next line (and its direction)', () {
    final s = guide.transfer('tokyo.yamanote', true, 'tokyo.shinjuku', 'tokyo.keio')!;
    expect((s.car, s.door), (9, 4));
    final east = guide.transfer('tokyo.yamanote', true, 'tokyo.akihabara', 'tokyo.chuo_sobu', toForward: true)!;
    final west = guide.transfer('tokyo.yamanote', true, 'tokyo.akihabara', 'tokyo.chuo_sobu', toForward: false)!;
    expect(east.door, isNot(west.door));
    expect(guide.transfer('tokyo.yamanote', true, 'tokyo.otsuka', 'tokyo.keio'), isNull);
  });

  test('forRoute: one advice per change plus the arrival gate', () {
    const route = RouteResult([
      RouteLeg(
        lineId: 'tokyo.yamanote',
        forward: false, // 外回り: 渋谷 → 新宿
        stationIds: ['tokyo.shibuya', 'tokyo.harajuku', 'tokyo.yoyogi', 'tokyo.shinjuku'],
      ),
      RouteLeg(lineId: 'tokyo.keio', forward: true, stationIds: ['tokyo.shinjuku', 'tokyo.sasazuka']),
    ]);
    final advice = guide.forRoute(route);
    expect(advice, hasLength(1)); // no Keio data: only the change at Shinjuku
    expect(advice.single.stationId, 'tokyo.shinjuku');
    expect(advice.single.spot.to, 'tokyo.keio');
    expect((advice.single.spot.car, advice.single.spot.door), (9, 3));

    const ride = RouteResult([
      RouteLeg(
        lineId: 'tokyo.yamanote',
        forward: true,
        stationIds: ['tokyo.shinjuku', 'tokyo.yoyogi', 'tokyo.harajuku', 'tokyo.shibuya'],
      ),
    ]);
    final end = guide.forRoute(ride);
    expect(end.single.spot.isExit, isTrue);
    expect(end.single.spot.exitName, isNotEmpty);
  });

  test('an empty guide gives no advice', () {
    const ride = RouteResult([
      RouteLeg(lineId: 'tokyo.yamanote', forward: true, stationIds: ['tokyo.shinjuku', 'tokyo.yoyogi']),
    ]);
    expect(CarGuide.empty.forRoute(ride), isEmpty);
  });
}
