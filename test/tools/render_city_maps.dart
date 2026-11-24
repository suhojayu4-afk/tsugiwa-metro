// Review captures of a new city's route map (the ground tiles, the coarse
// picture round it, landmarks and the lines, simplified the way
// render_map_seasons.dart draws them) into docs/captures/maps_<city>/:
//   MAP_CITY=osaka flutter test test/tools/render_city_maps.dart
// Shots: the whole map, the picture round it, the middle at two zooms, and
// each landmark close up.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/models/route_map.dart';

const _phone = Size(412, 860);

final _images = <String, ui.Image>{};

Future<ui.Image?> _img(String path) async {
  if (_images.containsKey(path)) return _images[path];
  final f = File(path);
  if (!f.existsSync()) return null;
  final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
  return _images[path] = (await codec.getNextFrame()).image;
}

Future<void> _shot(RouteMapData map, Map<String, Color> colors, String path, Offset center, double s) async {
  final m = Matrix4.identity()
    ..translateByDouble(_phone.width / 2 - center.dx * s, _phone.height / 2 - center.dy * s, 0, 1)
    ..scaleByDouble(s, s, 1, 1);
  final inv = Matrix4.inverted(m);
  final view = Rect.fromPoints(
    MatrixUtils.transformPoint(inv, Offset.zero),
    MatrixUtils.transformPoint(inv, Offset(_phone.width, _phone.height)),
  );
  Offset sp(Offset w) => MatrixUtils.transformPoint(m, w);

  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.scale(2);
  canvas.drawRect(Offset.zero & _phone, Paint()..color = const Color(0xFFF3F2EC));
  canvas.save();
  canvas.transform(m.storage);
  final px = Paint()..filterQuality = FilterQuality.none;
  final o = map.outer;
  final outer = o == null ? null : await _img(o.image);
  if (o != null && outer != null) {
    canvas.drawImageRect(
      outer,
      Rect.fromLTWH(0, 0, outer.width.toDouble(), outer.height.toDouble()),
      o.origin & Size(outer.width * o.scale, outer.height * o.scale),
      px,
    );
  }
  final ov = (await _img(map.terrainImage))!;
  canvas.drawImageRect(
    ov,
    Rect.fromLTWH(0, 0, ov.width.toDouble(), ov.height.toDouble()),
    map.terrainOrigin & Size(ov.width * map.terrainScale, ov.height * map.terrainScale),
    px,
  );
  for (final set in map.tileSets) {
    if (s < set.from) continue;
    for (
      var ty = ((view.top - set.origin.dy) / set.span).floor();
      ty <= ((view.bottom - set.origin.dy) / set.span).floor();
      ty++
    ) {
      for (
        var tx = ((view.left - set.origin.dx) / set.span).floor();
        tx <= ((view.right - set.origin.dx) / set.span).floor();
        tx++
      ) {
        final a = set.asset(tx, ty);
        final img = a == null ? null : await _img(a);
        if (img == null) continue;
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromLTWH(
            set.origin.dx + tx * set.span,
            set.origin.dy + ty * set.span,
            img.width * set.scale,
            img.height * set.scale,
          ),
          px,
        );
      }
    }
  }
  canvas.restore();

  // ---- landmarks ----
  final lmAll = ((s - 0.42) / 0.2).clamp(0.0, 1.0);
  final lpx = (s * 1.1).clamp(0.5, 2.2);
  for (final lm in map.landmarks) {
    final a = lm.giant ? 1.0 : lmAll;
    if (a <= 0 || !view.inflate(lm.giant ? 700 : 140 / s).contains(lm.position)) continue;
    final img = await _img(lm.image);
    if (img == null) continue;
    final k = !lm.ground ? lpx : (lm.giant ? math.max(lm.unit * s, 1.0) : lm.unit * s);
    final fw = img.width / lm.frames;
    final w = fw * k, h = img.height * k;
    final p = sp(lm.position);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, fw, img.height.toDouble()),
      Rect.fromLTWH(p.dx - w / 2, p.dy - h + 4 * k, w, h),
      Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(0, 0, 0, a),
    );
  }

  // ---- lines and stops (simplified) ----
  final width = (5.5 * s).clamp(2.0, 7.0);
  for (final line in map.lines) {
    if (!line.bounds.overlaps(view.inflate(50))) continue;
    final path = Path()..addPolygon([for (final p in line.path) sp(p)], line.closed);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..color = colors[line.lineId] ?? const Color(0xFF888888),
    );
  }
  if (s > 0.25) {
    for (final stop in map.allStops) {
      if (!view.contains(stop.position)) continue;
      final p = sp(stop.position);
      canvas.drawCircle(p, width * 0.75, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(
        p,
        width * 0.75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF30343C),
      );
    }
  }
  final img = await rec.endRecording().toImage((_phone.width * 2).round(), (_phone.height * 2).round());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  final city = Platform.environment['MAP_CITY'] ?? 'osaka';
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      final mapJson = jsonDecode(File('assets/cities/$city/map.json').readAsStringSync()) as Map<String, dynamic>;
      final colors = {
        for (final l in (jsonDecode(
          File('assets/cities/$city/lines.json').readAsStringSync(),
        ) as List).cast<Map<String, dynamic>>())
          l['id'] as String: Color(int.parse((l['color'] as String).substring(1), radix: 16) | 0xFF000000),
      };
      final out = Directory('docs/captures/maps_$city')..createSync(recursive: true);
      final map = RouteMapData.fromJson(mapJson, const {});
      final size = map.size;
      final mid = Offset(size.width / 2, size.height / 2);
      final fit = math.min(_phone.width / size.width, _phone.height / size.height);
      // The middle of the network: the median of all the stops.
      final xs = map.allStops.map((s) => s.position.dx).toList()..sort();
      final ys = map.allStops.map((s) => s.position.dy).toList()..sort();
      final centre = Offset(xs[xs.length ~/ 2], ys[ys.length ~/ 2]);
      await _shot(map, colors, '${out.path}/overview.png', mid, fit);
      await _shot(map, colors, '${out.path}/outer.png', mid, fit * 0.45);
      await _shot(map, colors, '${out.path}/centre_0.5.png', centre, 0.5);
      await _shot(map, colors, '${out.path}/centre_1.0.png', centre, 1.0);
      for (final lm in map.landmarks) {
        final name = lm.image.split('/').last.replaceAll('.png', '');
        await _shot(map, colors, '${out.path}/lm_$name.png', lm.position, 1.0);
      }
    });
  });
}
