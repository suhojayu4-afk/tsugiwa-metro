// The 路線図 map drawn by its own painters (ground tiles, scenery, landmarks,
// lines, stations, names; day or night) for any region and zoom, into
// docs/captures/map_polish/ for review:
//   flutter test test/tools/render_map_polish.dart
// Without settings it draws the survey: all of Kanto, then a grid of crops
// at a middle zoom. Other shots come from a JSON file named in the
// MAP_POLISH_JOBS environment variable, a list of
//   {"name": "nikko", "lat": 36.75, "lng": 139.6, "scale": 0.8, "night": false,
//    "w": 900, "h": 900, "date": "2027-06-15", "names": true,
//    "stickers": {"tokyo.tokyo": "heart"}, "unplaced": false}
// ("x"/"y" in map units or "station" (an id) instead of lat/lng; MAP_POLISH_PREFIX
// goes in front of every file name, e.g. before_ / after_; MAP_POLISH_OUT is
// another folder to write to; MAP_POLISH_MAP is another map.json to draw,
// e.g. a kept copy of the old one for "before").
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsugiwa_metro/data/models/route_map.dart';
import 'package:tsugiwa_metro/features/route_map/map_seasons.dart';
import 'package:tsugiwa_metro/features/route_map/my_location.dart';
import 'package:tsugiwa_metro/features/route_map/route_map_screen.dart';

import '../trip_logic_test.dart' show loadTokyo;

Map<String, dynamic> _read(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

final _images = <String, ui.Image>{};

Future<ui.Image?> _img(String path) async {
  if (_images.containsKey(path)) return _images[path];
  final f = File(path);
  if (!f.existsSync()) return null;
  final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
  return _images[path] = (await codec.getNextFrame()).image;
}

/// Draws the map with world point [center] in the middle of a [size] picture.
Future<ui.Image> renderMap({
  required RouteMapData map,
  required dynamic city,
  required Offset center,
  required double scale,
  required Size size,
  bool night = false,
  bool names = true,
  List<SeasonSpot> seasonal = const [],
  double phase = 0.1,
  Map<String, String> stickers = const {},
  DateTime? now,
  MapPlace? me,
  double? meHeading,
  double meAccuracy = 0,
}) async {
  final m = Matrix4.identity()
    ..translateByDouble(size.width / 2 - center.dx * scale, size.height / 2 - center.dy * scale, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1);
  final view = Rect.fromCenter(center: center, width: size.width / scale, height: size.height / scale);
  final tiles = <String, ui.Image>{};
  for (final asset in mapTilesFor(map, view, scale)) {
    final img = await _img(asset);
    if (img != null) tiles[asset] = img;
  }
  final layers = debugMapLayers(
    map: map,
    city: city,
    overview: (await _img(map.terrainImage))!,
    tiles: tiles,
    images: _images,
    matrix: TransformationController(m),
    clock: AlwaysStoppedAnimation(phase),
    night: night,
    seasonal: seasonal,
    now: now,
    stickers: stickers,
    stickerImages: {for (final name in stickers.values.toSet()) name: ?await _img('assets/art/stickers/$name.png')},
    me: me,
    meHeading: meHeading,
    meAccuracy: meAccuracy,
  );
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec, Offset.zero & size);
  canvas.clipRect(Offset.zero & size);
  canvas.drawRect(Offset.zero & size, Paint()..color = night ? const Color(0xFF151A30) : const Color(0xFFF3F2EC));
  for (final layer in layers) {
    if (!names && layer.name == 'names') continue;
    if (layer.filter != null) canvas.saveLayer(Offset.zero & size, Paint()..colorFilter = layer.filter);
    if (layer.world) {
      canvas.save();
      canvas.transform(m.storage);
      layer.painter.paint(canvas, map.size);
      canvas.restore();
    } else {
      layer.painter.paint(canvas, size);
    }
    if (layer.filter != null) canvas.restore();
  }
  return rec.endRecording().toImage(size.width.round(), size.height.round());
}

void main() {
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      for (final (family, file) in [('DotGothic16', 'DotGothic16-Regular.ttf'), ('Galmuri11', 'Galmuri11.ttf')]) {
        final font = FontLoader(family)..addFont(rootBundle.load('assets/fonts/$file'));
        await font.load();
      }
      final mapJson = _read(Platform.environment['MAP_POLISH_MAP'] ?? 'assets/cities/tokyo/map.json');
      final seasonsJson = _read('assets/cities/tokyo/seasons.json');
      final proj = SeasonProjection.fromJson(seasonsJson['projection'] as Map<String, dynamic>);
      final city = loadTokyo();
      final out = Directory(Platform.environment['MAP_POLISH_OUT'] ?? 'docs/captures/map_polish')
        ..createSync(recursive: true);
      final prefix = Platform.environment['MAP_POLISH_PREFIX'] ?? '';
      final jobsFile = Platform.environment['MAP_POLISH_JOBS'];
      final first = RouteMapData.fromJson(mapJson, const {});
      final List<Map<String, dynamic>> jobs;
      if (jobsFile != null) {
        jobs = (jsonDecode(File(jobsFile).readAsStringSync()) as List).cast<Map<String, dynamic>>();
      } else {
        // The survey: all of Kanto (day and night), then 3 x 3 crops at a middle zoom.
        final w = first.size.width, h = first.size.height;
        jobs = [
          for (final night in [false, true])
            {
              'name': 'survey_all_${night ? 'night' : 'day'}',
              'x': w / 2,
              'y': h / 2,
              'scale': 0.11,
              'w': w * 0.11,
              'h': h * 0.11,
              'night': night,
            },
          for (var gy = 0; gy < 3; gy++)
            for (var gx = 0; gx < 3; gx++)
              {
                'name': 'survey_mid_${gy}_$gx',
                'x': w * (gx + 0.5) / 3,
                'y': h * (gy + 0.5) / 3,
                'scale': 0.3,
                'w': w * 0.3 / 3,
                'h': h * 0.3 / 3,
              },
        ];
      }
      for (final j in jobs) {
        final date = DateTime.parse('${j['date'] ?? '2027-06-15'}T03:00:00Z');
        final map = RouteMapData.fromJson(mapJson, const {}, now: date);
        for (final p in [
          ...map.landmarks.map((l) => l.image),
          ...map.decor.map((d) => d.image),
          ...MapSeasons.images,
          ...MapSeasons.landmarkArt,
        ]) {
          await _img(p);
        }
        // "unplaced": the seasonal spots at their real places, not moved clear of the lines.
        final seasons = j['unplaced'] == true
            ? MapSeasons.fromJson(seasonsJson, landmarks: map.landmarks)
            : MapSeasons.fromJson(seasonsJson, map: map, nameEms: (id) => stationNameEms(city, id));
        final center = switch (j) {
          {'station': final String id} => map.stopsOf(id).first.position,
          {'lat': final num lat, 'lng': final num lng} => proj.toMap(lat.toDouble(), lng.toDouble()),
          _ => Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
        };
        final img = await renderMap(
          map: map,
          city: city,
          center: center,
          scale: (j['scale'] as num).toDouble(),
          size: Size((j['w'] as num? ?? 900).toDouble(), (j['h'] as num? ?? 900).toDouble()),
          night: j['night'] as bool? ?? false,
          names: j['names'] as bool? ?? true,
          seasonal: seasons.spotsAt(date),
          phase: (j['phase'] as num? ?? 0.1).toDouble(),
          now: date,
          stickers: (j['stickers'] as Map<String, dynamic>? ?? const {}).cast<String, String>(),
        );
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$prefix${j['name']}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        img.dispose();
      }
    });
  });
}
