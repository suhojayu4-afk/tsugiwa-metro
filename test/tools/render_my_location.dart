// The 現在地 marker on the route map (a dot, its accuracy ring and the cone
// showing which way the phone points), for review: a few places in Tokyo, by
// day and night, into docs/captures/my_location/ (MY_LOCATION_OUT = another folder).
//   flutter test test/tools/render_my_location.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/models/route_map.dart';
import 'package:tsugiwa_metro/features/route_map/my_location.dart';

import '../trip_logic_test.dart' show loadTokyo;
import 'render_map_polish.dart' show renderMap;

void main() {
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      for (final (family, file) in [('DotGothic16', 'DotGothic16-Regular.ttf'), ('Galmuri11', 'Galmuri11.ttf')]) {
        final font = FontLoader(family)..addFont(rootBundle.load('assets/fonts/$file'));
        await font.load();
      }
      final city = loadTokyo();
      final map = RouteMapData.fromJson(
        jsonDecode(File('assets/cities/tokyo/map.json').readAsStringSync()) as Map<String, dynamic>,
        const {},
      );
      final out = Directory(Platform.environment['MY_LOCATION_OUT'] ?? 'docs/captures/my_location')
        ..createSync(recursive: true);
      // name, lat, lng, heading (null = no compass), accuracy in metres, night
      final shots = <(String, double, double, double?, double, bool)>[
        ('shibuya_ne', 35.6591, 139.7016, 45, 12, false),
        ('tokyo_yurakucho_sw', 35.6782, 139.7650, 210, 25, false),
        ('shinjuku_west_night', 35.6903, 139.6975, 280, 40, true),
        ('asakusa_no_compass', 35.7118, 139.7968, null, 15, false),
        ('ueno_wide_fix', 35.7135, 139.7760, 135, 180, false),
      ];
      for (final (name, lat, lng, heading, acc, night) in shots) {
        final place = placeOnMap(city, map, lat, lng)!;
        final img = await renderMap(
          map: map,
          city: city,
          center: place.position,
          // A phone's width, the zoom 現在地 goes to.
          scale: 1.4,
          size: const ui.Size(390, 520),
          night: night,
          me: place,
          meHeading: heading,
          meAccuracy: acc,
        );
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        // ignore: avoid_print
        print('$name: nearest ${place.nearest.name.of('ja')} ${place.meters.round()} m, north ${place.north}');
      }
    });
  });
}
