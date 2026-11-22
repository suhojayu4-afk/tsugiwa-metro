// The route map's seasonal decorations (lib/features/route_map/map_seasons.dart)
// on a forced date for each season, drawn over the real terrain tiles, scenery,
// landmarks and lines the way the 路線図 tab layers them (lines simplified, no
// names), into docs/captures/map_seasons/ for review:
//   flutter test test/tools/render_map_seasons.dart
// On a device: flutter run --dart-define=MAP_SEASON_DATE=2027-04-01
// MAP_CITY=tottori renders the Tottori map's seasons into docs/captures/tottori/seasons/.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/models/route_map.dart';
import 'package:tsugiwa_metro/features/route_map/map_seasons.dart';

typedef Shot = ({String name, DateTime date, Offset? center, String? at, double scale, bool night, double phase});

DateTime _jst(int y, int m, int d) => DateTime.utc(y, m, d, 3);

const _phone = Size(412, 860);

final _shots = <Shot>[
  (name: 'hatsumode_tokyo', date: _jst(2027, 1, 2), center: null, at: null, scale: 0.3, night: false, phase: 0.1),
  (name: 'hatsumode_meiji', date: _jst(2027, 1, 2), center: null, at: '明治神宮', scale: 1.3, night: false, phase: 0.1),
  (name: 'hatsumode_night', date: _jst(2027, 1, 2), center: null, at: '浅草寺', scale: 1.0, night: true, phase: 0.3),
  (name: 'sakura_tokyo', date: _jst(2027, 4, 1), center: null, at: null, scale: 0.3, night: false, phase: 0.2),
  (name: 'sakura_ueno', date: _jst(2027, 4, 1), center: null, at: '上野恩賜公園', scale: 1.3, night: false, phase: 0.2),
  (name: 'sakura_meguro', date: _jst(2027, 4, 1), center: null, at: '目黒川', scale: 1.0, night: false, phase: 0.6),
  (name: 'hanabi_tokyo_day', date: _jst(2027, 7, 25), center: null, at: null, scale: 0.3, night: false, phase: 0),
  (name: 'hanabi_tokyo_night', date: _jst(2027, 7, 25), center: null, at: null, scale: 0.3, night: true, phase: 0.2),
  (
    name: 'hanabi_sumida_night',
    date: _jst(2027, 7, 25),
    center: null,
    at: '隅田川花火大会',
    scale: 1.0,
    night: true,
    phase: 0.3,
  ),
  (
    name: 'hanabi_sumida_night2',
    date: _jst(2027, 7, 25),
    center: null,
    at: '隅田川花火大会',
    scale: 1.0,
    night: true,
    phase: 0.62,
  ),
  (name: 'koyo_tokyo', date: _jst(2026, 11, 10), center: null, at: null, scale: 0.3, night: false, phase: 0),
  (name: 'koyo_gaien', date: _jst(2026, 11, 10), center: null, at: '神宮外苑いちょう並木', scale: 1.3, night: false, phase: 0),
  (name: 'koyo_takao', date: _jst(2026, 11, 10), center: null, at: '高尾山', scale: 0.7, night: false, phase: 0),
  (
    name: 'koyo_kanto',
    date: _jst(2026, 11, 10),
    center: Offset(5600, 6400),
    at: null,
    scale: 0.13,
    night: false,
    phase: 0,
  ),
  (
    name: 'illumination_tokyo_night',
    date: _jst(2026, 12, 15),
    center: null,
    at: null,
    scale: 0.3,
    night: true,
    phase: 0.4,
  ),
  (
    name: 'illumination_marunouchi',
    date: _jst(2026, 12, 15),
    center: null,
    at: '丸の内イルミネーション',
    scale: 1.3,
    night: false,
    phase: 0.4,
  ),
  (
    name: 'illumination_roppongi_night',
    date: _jst(2026, 12, 15),
    center: null,
    at: '六本木 東京ミッドタウン',
    scale: 1.2,
    night: true,
    phase: 0.4,
  ),
  (name: 'today_tokyo', date: _jst(2026, 11, 21), center: null, at: null, scale: 0.3, night: false, phase: 0),
];

Map<String, dynamic> _read(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

final _images = <String, ui.Image>{};

Future<ui.Image?> _img(String path) async {
  if (_images.containsKey(path)) return _images[path];
  final f = File(path);
  if (!f.existsSync()) return null;
  final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
  return _images[path] = (await codec.getNextFrame()).image;
}

const _nightGround = ColorFilter.matrix([
  0.22, 0, 0, 0, 4, //
  0, 0.22, 0, 0, 5,
  0.18, 0, 0.18, 0, 14,
  0, 0, 0, 1, 0,
]);
const _nightSoft = ColorFilter.matrix([0.55, 0, 0, 0, 6, 0, 0.55, 0, 0, 8, 0.1, 0, 0.62, 0, 22, 0, 0, 0, 1, 0]);

final _tottoriShots = <Shot>[
  (name: 'hatsumode_hakuto', date: _jst(2027, 1, 2), center: null, at: '白兎神社', scale: 1.0, night: false, phase: 0.1),
  (
    name: 'sakura_tottori',
    date: _jst(2027, 4, 5),
    center: null,
    at: '久松公園（鳥取城跡）',
    scale: 1.0,
    night: false,
    phase: 0.2,
  ),
  (name: 'sakura_yonago', date: _jst(2027, 4, 5), center: null, at: '湊山公園（米子城跡）', scale: 1.0, night: false, phase: 0.4),
  (
    name: 'hanabi_tottori_night',
    date: _jst(2027, 7, 25),
    center: null,
    at: '鳥取市民納涼花火大会',
    scale: 1.0,
    night: true,
    phase: 0.3,
  ),
  (
    name: 'hanabi_togo_night',
    date: _jst(2027, 7, 25),
    center: null,
    at: '東郷湖 水郷祭',
    scale: 0.8,
    night: true,
    phase: 0.6,
  ),
  (name: 'koyo_daisen', date: _jst(2026, 11, 5), center: null, at: '大山', scale: 0.6, night: false, phase: 0),
  (name: 'koyo_mitoku', date: _jst(2026, 11, 5), center: null, at: '三徳山', scale: 1.0, night: false, phase: 0),
  (
    name: 'illumination_yonago_night',
    date: _jst(2026, 12, 10),
    center: null,
    at: '米子駅前',
    scale: 1.0,
    night: true,
    phase: 0.2,
  ),
  (
    name: 'koyo_all',
    date: _jst(2026, 11, 5),
    center: Offset(3450, 1500),
    at: null,
    scale: 0.12,
    night: false,
    phase: 0,
  ),
];

void main() {
  final city = Platform.environment['MAP_CITY'] ?? 'tokyo';
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      final mapJson = _read('assets/cities/$city/map.json');
      final colors = {
        for (final l in (jsonDecode(
          File('assets/cities/$city/lines.json').readAsStringSync(),
        ) as List).cast<Map<String, dynamic>>())
          l['id'] as String: Color(int.parse((l['color'] as String).substring(1), radix: 16) | 0xFF000000),
      };
      final out = Directory(city == 'tokyo' ? 'docs/captures/map_seasons' : 'docs/captures/$city/seasons')
        ..createSync(recursive: true);
      for (final p in MapSeasons.images) {
        await _img(p);
      }
      for (final shot in city == 'tokyo' ? _shots : _tottoriShots) {
        final map = RouteMapData.fromJson(mapJson, const {}, now: shot.date);
        final seasons = MapSeasons.fromJson(_read('assets/cities/$city/seasons.json'), map: map);
        final spots = seasons.spotsAt(shot.date);
        final ring =
            map.lines.where((l) => l.lineId == 'tokyo.yamanote').firstOrNull?.bounds.center ??
            Offset(map.size.width / 2, map.size.height / 2);
        final center = shot.center ?? (shot.at == null ? ring : spots.firstWhere((s) => s.name.ja == shot.at).position);
        final s = shot.scale;
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
        canvas.drawRect(
          Offset.zero & _phone,
          Paint()..color = shot.night ? const Color(0xFF151A30) : const Color(0xFFF3F2EC),
        );

        // ---- ground: overview, then the tiles in view ----
        if (shot.night) canvas.saveLayer(Offset.zero & _phone, Paint()..colorFilter = _nightGround);
        canvas.save();
        canvas.transform(m.storage);
        final ov = (await _img(map.terrainImage))!;
        final px = Paint()..filterQuality = FilterQuality.none;
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
        if (shot.night) canvas.restore();

        // ---- scenery (zoomed in) ----
        final decorAlpha = ((s - 0.5) / 0.25).clamp(0.0, 1.0);
        if (decorAlpha > 0) {
          final paint = Paint()
            ..filterQuality = FilterQuality.none
            ..color = Color.fromRGBO(0, 0, 0, decorAlpha * 0.92);
          if (shot.night) paint.colorFilter = _nightSoft;
          for (final d in map.decor) {
            if (!view.inflate(100).contains(d.position)) continue;
            final img = await _img(d.image);
            if (img == null) continue;
            final fw = img.width / d.frames;
            final p = sp(d.position);
            final w = fw * 2 * s, h = img.height * 2 * s;
            canvas.drawImageRect(
              img,
              Rect.fromLTWH(0, 0, fw, img.height.toDouble()),
              Rect.fromLTWH(p.dx - w / 2, p.dy - h * 0.75, w, h),
              paint,
            );
          }
        }

        // ---- the seasons ----
        SeasonPainter(
          spots: spots,
          images: _images,
          matrix: TransformationController(m),
          clock: AlwaysStoppedAnimation(shot.phase),
          night: shot.night,
        ).paint(canvas, _phone);

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
          final paint = Paint()
            ..filterQuality = FilterQuality.none
            ..color = Color.fromRGBO(0, 0, 0, a);
          if (shot.night) paint.colorFilter = _nightSoft;
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, fw, img.height.toDouble()),
            Rect.fromLTWH(p.dx - w / 2, p.dy - h + 4 * k, w, h),
            paint,
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

        // ---- fireworks and petals, over the lines ----
        SeasonPainter(
          spots: spots,
          images: _images,
          matrix: TransformationController(m),
          clock: AlwaysStoppedAnimation(shot.phase),
          night: shot.night,
          sky: true,
        ).paint(canvas, _phone);

        final img = await rec.endRecording().toImage((_phone.width * 2).round(), (_phone.height * 2).round());
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/${shot.name}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    });
  });
}
