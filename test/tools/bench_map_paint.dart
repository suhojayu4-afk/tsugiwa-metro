// How long the 路線図 painters take: every layer painted for N frames while
// panning (the clock running) at three zooms, day and night, into a
// PictureRecorder (the Dart side of a frame), plus a few frames rasterised.
//   flutter test test/tools/bench_map_paint.dart
// Prints a table and writes docs/captures/map_polish/bench_<MAP_BENCH_TAG>.json.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsugiwa_metro/data/models/route_map.dart';
import 'package:tsugiwa_metro/features/route_map/map_seasons.dart';
import 'package:tsugiwa_metro/features/route_map/map_trains.dart';
import 'package:tsugiwa_metro/features/route_map/route_map_screen.dart';

import '../trip_logic_test.dart' show loadTokyo;

const _phone = Size(412, 860);
const _frames = 240;

Map<String, dynamic> _read(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Future<ui.Image> _img(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

void main() {
  testWidgets('bench', (tester) async {
    await tester.runAsync(() async {
      for (final (family, file) in [('DotGothic16', 'DotGothic16-Regular.ttf'), ('Galmuri11', 'Galmuri11.ttf')]) {
        final font = FontLoader(family)..addFont(rootBundle.load('assets/fonts/$file'));
        await font.load();
      }
      // A winter evening: illuminations and autumn leaves are both on.
      final date = DateTime.utc(2026, 11, 25, 3);
      final map = RouteMapData.fromJson(
        _read(Platform.environment['MAP_POLISH_MAP'] ?? 'assets/cities/tokyo/map.json'),
        const {},
        now: date,
      );
      final city = loadTokyo();
      final images = <String, ui.Image>{};
      for (final p in {...map.landmarks.map((l) => l.image), ...map.decor.map((d) => d.image), ...MapSeasons.images}) {
        if (File(p).existsSync()) images[p] = await _img(p);
      }
      final overview = await _img(map.terrainImage);
      final seasonal = MapSeasons.fromJson(
        _read('assets/cities/tokyo/seasons.json'),
        landmarks: map.landmarks,
      ).spotsAt(date);
      final sim = TrainSim(map, city);
      final ring = map.lines.firstWhere((l) => l.lineId == 'tokyo.yamanote').bounds.center;
      final results = <String, dynamic>{};
      final table = StringBuffer();
      for (final night in [false, true]) {
        for (final scale in [0.12, 0.35, 1.2]) {
          final controller = TransformationController();
          final clock = ValueNotifier<double>(0);
          final anim = _Clock(clock);
          Matrix4 at(int i) {
            // A slow pan round the Yamanote ring.
            final c = ring + Offset(i * 3 / scale, i * 1.5 / scale);
            return Matrix4.identity()
              ..translateByDouble(_phone.width / 2 - c.dx * scale, _phone.height / 2 - c.dy * scale, 0, 1)
              ..scaleByDouble(scale, scale, 1, 1);
          }

          controller.value = at(0);
          final view = Rect.fromCenter(center: ring, width: _phone.width / scale, height: _phone.height / scale);
          final tiles = {for (final a in mapTilesFor(map, view.inflate(400 / scale), scale)) a: await _img(a)};
          final layers = debugMapLayers(
            map: map,
            city: city,
            overview: overview,
            tiles: tiles,
            images: images,
            matrix: controller,
            clock: anim,
            night: night,
            seasonal: seasonal,
            sim: sim,
          );
          void frame(Canvas canvas, MapLayer layer, int i) {
            if (layer.filter != null) canvas.saveLayer(Offset.zero & _phone, Paint()..colorFilter = layer.filter);
            if (layer.world) {
              canvas.save();
              canvas.transform(controller.value.storage);
              layer.painter.paint(canvas, map.size);
              canvas.restore();
            } else {
              layer.painter.paint(canvas, _phone);
            }
            if (layer.filter != null) canvas.restore();
          }

          final key = '${night ? 'night' : 'day'}@$scale';
          final per = <String, double>{};
          var total = 0.0;
          for (final layer in layers) {
            // Warm up (text layouts, paths), then time.
            for (var pass = 0; pass < 2; pass++) {
              final sw = Stopwatch()..start();
              for (var i = 0; i < _frames; i++) {
                controller.value = at(i);
                clock.value = (i / 360) % 1;
                final rec = ui.PictureRecorder();
                frame(Canvas(rec, Offset.zero & _phone), layer, i);
                rec.endRecording().dispose();
              }
              sw.stop();
              if (pass == 1) per[layer.name] = sw.elapsedMicroseconds / _frames / 1000;
            }
            total += per[layer.name]!;
          }
          // Raster: whole frames turned into pixels (software, so only for comparing).
          final sw = Stopwatch()..start();
          const rasterFrames = 12;
          for (var i = 0; i < rasterFrames; i++) {
            controller.value = at(i * 10);
            clock.value = (i / 12) % 1;
            final rec = ui.PictureRecorder();
            final canvas = Canvas(rec, Offset.zero & _phone);
            canvas.clipRect(Offset.zero & _phone);
            for (final layer in layers) {
              frame(canvas, layer, i);
            }
            final pic = rec.endRecording();
            final img = await pic.toImage(_phone.width.round(), _phone.height.round());
            img.dispose();
            pic.dispose();
          }
          final raster = sw.elapsedMicroseconds / rasterFrames / 1000;
          results[key] = {'paint_ms': per, 'paint_total_ms': total, 'raster_ms': raster};
          table.writeln(
            '$key  paint ${total.toStringAsFixed(3)} ms/frame  raster ${raster.toStringAsFixed(1)} ms  '
            '${per.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(3)}').join(', ')}',
          );
        }
      }
      // ignore: avoid_print
      print(table);
      final tag = Platform.environment['MAP_BENCH_TAG'] ?? 'run';
      File('docs/captures/map_polish/bench_$tag.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(results));
    });
  });
}

/// An animation that just reads a notifier (the bench moves the clock by hand).
class _Clock extends Animation<double> {
  _Clock(this.source);
  final ValueNotifier<double> source;

  @override
  void addListener(VoidCallback listener) => source.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => source.removeListener(listener);
  @override
  void addStatusListener(AnimationStatusListener listener) {}
  @override
  void removeStatusListener(AnimationStatusListener listener) {}
  @override
  AnimationStatus get status => AnimationStatus.forward;
  @override
  double get value => source.value;
}
