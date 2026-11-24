import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show PictureRecorder;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/models/route_map.dart';
import 'package:tsugiwa_metro/features/route_map/my_location.dart';

import 'trip_logic_test.dart' show loadTokyo;

/// 現在地 on the route map: the user's spot is found from the stations round
/// it, and the compass is turned onto the drawing.
void main() {
  final city = loadTokyo();
  final map = RouteMapData.fromJson(
    jsonDecode(File('assets/cities/tokyo/map.json').readAsStringSync()) as Map<String, dynamic>,
    const {},
  );

  test('standing at a station: the marker is on that station', () {
    final s = city.station('tokyo.shibuya');
    final place = placeOnMap(city, map, s.lat, s.lng)!;
    expect(place.nearest.id, 'tokyo.shibuya');
    expect(place.meters, lessThan(5));
    final at = map.stopsOf('tokyo.shibuya').first.position;
    expect((place.position - at).distance, lessThan(12));
  });

  test('between two stations: the marker lies between them on the drawing', () {
    final a = city.station('tokyo.tokyo'), b = city.station('tokyo.yurakucho');
    final place = placeOnMap(city, map, (a.lat + b.lat) / 2, (a.lng + b.lng) / 2)!;
    final pa = map.stopsOf(a.id).first.position, pb = map.stopsOf(b.id).first.position;
    final span = (pa - pb).distance;
    expect((place.position - pa).distance, lessThan(span * 1.2));
    expect((place.position - pb).distance, lessThan(span * 1.2));
  });

  test('north is a unit direction, roughly up on Tokyo\'s map; the compass turns clockwise from it', () {
    final s = city.station('tokyo.shinjuku');
    final place = placeOnMap(city, map, s.lat + 0.002, s.lng - 0.002)!;
    expect(place.north.distance, closeTo(1, 0.01));
    expect(place.north.dy, lessThan(-0.7)); // up on the screen
    expect(place.metersPerUnit, greaterThan(1));
    // Facing north points along north; east is a quarter turn clockwise on screen.
    final north = place.angleOf(0), east = place.angleOf(90);
    expect(Offset(math.cos(north), math.sin(north)).dx, closeTo(place.north.dx, 0.01));
    final turn = ((east - north) + 2 * math.pi) % (2 * math.pi);
    expect(turn, closeTo(math.pi / 2, 0.01));
  });

  test('far from every station (another city): no marker', () {
    expect(placeOnMap(city, map, 34.7025, 135.4959), isNull); // Osaka
    expect(placeOnMap(city, map, 37.5665, 126.9780), isNull); // Seoul
  });

  test('the marker paints with and without a compass', () {
    final s = city.station('tokyo.ueno');
    final place = placeOnMap(city, map, s.lat, s.lng)!;
    for (final heading in <double?>[null, 0, 135, 359]) {
      final rec = PictureRecorder();
      MyLocationPainter(
        place: place,
        matrix: TransformationController(),
        clock: const AlwaysStoppedAnimation(0.3),
        heading: heading,
        accuracyM: 60,
      ).paint(Canvas(rec), const Size(390, 700));
      rec.endRecording().dispose();
    }
  });
}
