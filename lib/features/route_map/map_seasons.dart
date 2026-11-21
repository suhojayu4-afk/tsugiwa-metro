import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../../core/localized_text.dart';
import '../../data/models/route_map.dart';

/// Seasonal decorations on the route map (季節イベント), shown only in their
/// days in Japan: 初詣 crowds and a warm glow at the big shrines and temples,
/// cherry trees with drifting petals at the hanami spots, fireworks over the
/// fireworks festivals, red and golden trees in autumn and twinkling lights
/// for the winter illuminations. Spots: `assets/cities/<city>/seasons.json`.

/// What is drawn at a spot.
enum SeasonKind { shrine, temple, sakura, hanabi, momiji, icho, mixed, lights }

/// A season's days (month-day in Japan, both ends included).
class SeasonWindow {
  const SeasonWindow({required this.id, required this.from, required this.to, required this.name});

  final String id;
  final (int month, int day) from;
  final (int month, int day) to;
  final LocalizedText name;

  /// Is [jst] (a date in Japan) inside? Windows over New Year work too.
  bool contains(DateTime jst) {
    final d = jst.month * 100 + jst.day;
    final a = from.$1 * 100 + from.$2, b = to.$1 * 100 + to.$2;
    return a <= b ? d >= a && d <= b : d >= a || d <= b;
  }

  static (int, int) _md(String s) {
    final p = s.split('-');
    return (int.parse(p[0]), int.parse(p[1]));
  }

  factory SeasonWindow.fromJson(Map<String, dynamic> j) => SeasonWindow(
    id: j['id'] as String,
    from: _md(j['from'] as String),
    to: _md(j['to'] as String),
    name: LocalizedText.fromJson(j['name'] as Map<String, dynamic>),
  );
}

/// One seasonal place on the map.
class SeasonSpot {
  const SeasonSpot({
    required this.season,
    required this.kind,
    required this.name,
    required this.lat,
    required this.lng,
    required this.position,
    this.onLandmark = false,
    this.count = 4,
    this.seed = 0,
  });

  final SeasonWindow season;
  final SeasonKind kind;
  final LocalizedText name;
  final double lat, lng;

  /// Map units (by the landmark's picture when [onLandmark]).
  final Offset position;

  /// A landmark picture already stands here (the trees and crowds gather round it).
  final bool onLandmark;

  /// Trees in the cluster.
  final int count;

  /// Fixed per spot: the layout and colours vary, but never between frames.
  final int seed;

  /// 「お花見 · 上野恩賜公園」 for the snackbar.
  String label(String lang) => '${season.name.of(lang)} · ${name.of(lang)}';
}

/// The map's projection from tools/build_map.py (each axis spread on its
/// own: wide in the centre, squeezed further out), then shifted by [origin].
class SeasonProjection {
  const SeasonProjection({
    this.center = const (35.686, 139.760),
    this.kmLng = 90.9,
    this.kmLat = 111.0,
    this.units = 150,
    this.power = 0.75,
    this.far = 30,
    this.soft = 0.15,
    this.origin = const Offset(-7575.606, -6899.726),
  });

  final (double lat, double lng) center;
  final double kmLng, kmLat, units, power, far, soft;
  final Offset origin;

  double _spread(double t) {
    final a = t.abs();
    final farRate = power * math.pow(far + soft, power - 1);
    final s = a <= far
        ? math.pow(a + soft, power) - math.pow(soft, power)
        : math.pow(far + soft, power) - math.pow(soft, power) + (a - far) * farRate;
    return (t < 0 ? -s : s) * units;
  }

  Offset toMap(double lat, double lng) =>
      Offset(_spread((lng - center.$2) * kmLng), _spread((center.$1 - lat) * kmLat)) - origin;

  factory SeasonProjection.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num).toDouble();
    final c = j['center'] as List, o = j['origin'] as List;
    return SeasonProjection(
      center: ((c[0] as num).toDouble(), (c[1] as num).toDouble()),
      kmLng: d('kmLng'),
      kmLat: d('kmLat'),
      units: d('units'),
      power: d('power'),
      far: d('far'),
      soft: d('soft'),
      origin: Offset((o[0] as num).toDouble(), (o[1] as num).toDouble()),
    );
  }
}

/// All the seasons and their spots of one city.
class MapSeasons {
  const MapSeasons({this.seasons = const [], this.spots = const []});

  static const empty = MapSeasons();

  final List<SeasonWindow> seasons;
  final List<SeasonSpot> spots;

  /// The pictures the painter may need (small; all loaded with the map).
  static const images = [
    'assets/art/map_decor/sakura_a.png',
    'assets/art/map_decor/sakura_b.png',
    'assets/art/map_decor/sakura_c.png',
    'assets/art/map_decor/momiji_a.png',
    'assets/art/map_decor/momiji_b.png',
    'assets/art/map_decor/momiji_c.png',
    'assets/art/map_seasons/icho_a.webp',
    'assets/art/map_seasons/icho_b.webp',
    'assets/art/map_decor/shrine_a.png',
    'assets/art/map_decor/temple_a.png',
  ];

  /// [landmarks]: the map's landmarks, for spots that stand by one.
  factory MapSeasons.fromJson(Map<String, dynamic> json, {List<MapLandmark> landmarks = const []}) {
    final proj = json['projection'] is Map<String, dynamic>
        ? SeasonProjection.fromJson(json['projection'] as Map<String, dynamic>)
        : const SeasonProjection();
    final seasons = [for (final s in (json['seasons'] as List).cast<Map<String, dynamic>>()) SeasonWindow.fromJson(s)];
    final byId = {for (final s in seasons) s.id: s};
    final spots = <SeasonSpot>[];
    for (final j in (json['spots'] as List).cast<Map<String, dynamic>>()) {
      final season = byId[j['season']];
      if (season == null) continue;
      final lat = (j['lat'] as num).toDouble(), lng = (j['lng'] as num).toDouble();
      final lmName = j['landmark'] as String?;
      final lm = lmName == null
          ? null
          : landmarks.where((l) => l.image.endsWith('/$lmName.png') || l.image.endsWith('/$lmName.webp')).firstOrNull;
      final name = LocalizedText.fromJson(j['name'] as Map<String, dynamic>);
      spots.add(
        SeasonSpot(
          season: season,
          kind: SeasonKind.values.byName(j['kind'] as String),
          name: name,
          lat: lat,
          lng: lng,
          position: lm?.position ?? proj.toMap(lat, lng),
          onLandmark: lm != null,
          count: j['count'] as int? ?? 4,
          seed: _hash('${name.ja}${season.id}'),
        ),
      );
    }
    return MapSeasons(seasons: seasons, spots: spots);
  }

  /// Small stable hash (String.hashCode may differ between runs).
  static int _hash(String s) {
    var h = 17;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return h;
  }

  static final _cache = <String, Future<MapSeasons>>{};

  /// The city's seasons (none when it has no seasons.json).
  static Future<MapSeasons> load(String cityId, RouteMapData map) => _cache[cityId] ??= () async {
    try {
      final raw = await rootBundle.loadString('assets/cities/$cityId/seasons.json');
      return MapSeasons.fromJson(jsonDecode(raw) as Map<String, dynamic>, landmarks: map.landmarks);
    } catch (_) {
      return empty;
    }
  }();

  /// The date in Japan.
  static DateTime japan(DateTime now) => now.toUtc().add(const Duration(hours: 9));

  /// For previews on a device: `--dart-define=MAP_SEASON_DATE=2026-04-01`.
  static const _forced = String.fromEnvironment('MAP_SEASON_DATE');

  /// Now (or the forced preview day, at noon in Japan).
  static DateTime now() {
    final f = DateTime.tryParse(_forced);
    return f == null ? DateTime.now() : DateTime.utc(f.year, f.month, f.day, 3);
  }

  List<SeasonWindow> activeAt(DateTime now) {
    final jst = japan(now);
    return [
      for (final s in seasons)
        if (s.contains(jst)) s,
    ];
  }

  List<SeasonSpot> spotsAt(DateTime now) {
    final jst = japan(now);
    return [
      for (final s in spots)
        if (s.season.contains(jst)) s,
    ];
  }
}

/// The seasonal spot under [screen] (within a finger's reach), or null.
SeasonSpot? seasonSpotAt(List<SeasonSpot> spots, Matrix4 m, Offset screen) {
  final s = m.storage[0];
  if (SeasonPainter.fadeAt(s) <= 0) return null;
  SeasonSpot? best;
  var bestD = 30.0;
  for (final spot in spots) {
    final p = MatrixUtils.transformPoint(m, spot.position);
    var d = (p - screen).distance;
    if (spot.kind == SeasonKind.hanabi) {
      // The bursts are up in the sky above the river.
      d = math.min(d, (p.translate(0, -SeasonPainter.burstRadius(s) * 1.25) - screen).distance);
    }
    if (d < bestD) {
      bestD = d;
      best = spot;
    }
  }
  return best;
}

/// Draws the seasonal spots, in screen space like the moving scenery; repaints
/// with the map and the clock. Two layers: the ground one (glows, trees,
/// crowds, lights) lies under the lines and landmarks; the [sky] one
/// (fireworks, drifting petals) above them, below the names.
class SeasonPainter extends CustomPainter {
  SeasonPainter({
    required this.spots,
    required this.images,
    required this.matrix,
    required this.clock,
    this.night = false,
    this.still = false,
    this.sky = false,
  }) : super(repaint: Listenable.merge([matrix, clock]));

  final List<SeasonSpot> spots;
  final Map<String, ui.Image> images;
  final ValueListenable<Matrix4> matrix;

  /// 0..1 over a few seconds, repeating (the map's twinkle clock).
  final Animation<double> clock;
  final bool night;

  /// Reduce motion: no petals or bursts moving, fireworks stay small icons.
  final bool still;

  /// The layer above the lines: fireworks and petals only.
  final bool sky;

  /// Is there anything for the [sky] layer among [spots]?
  static bool hasSky(List<SeasonSpot> spots) =>
      spots.any((s) => s.kind == SeasonKind.hanabi || s.kind == SeasonKind.sakura);

  /// Shown from a little before the Tokyo overview; gone with all of Kanto on screen.
  static double fadeAt(double s) => ((s - 0.11) / 0.09).clamp(0.0, 1.0);

  /// Fireworks burst radius on screen.
  static double burstRadius(double s) => (130 * s).clamp(14.0, 80.0);

  /// Scenery dimmed at night (as the moving scenery layer).
  static const _nightTone = ColorFilter.matrix([
    0.55, 0, 0, 0, 6, //
    0, 0.55, 0, 0, 8,
    0.1, 0, 0.62, 0, 22,
    0, 0, 0, 1, 0,
  ]);

  static double _rnd(int seed, int i) {
    final x = math.sin(seed * 0.0137 + i * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final m = matrix.value;
    final s = m.storage[0];
    final fade = fadeAt(s);
    if (fade <= 0 || spots.isEmpty) return;
    Offset sp(Offset w) => MatrixUtils.transformPoint(m, w);
    final inv = Matrix4.inverted(m);
    final view = Rect.fromPoints(
      MatrixUtils.transformPoint(inv, Offset.zero),
      MatrixUtils.transformPoint(inv, Offset(size.width, size.height)),
    ).inflate(200 / s);
    final t = still ? 0.0 : clock.value;
    final here = [
      for (final spot in spots)
        if (view.contains(spot.position)) spot,
    ];
    if (here.isEmpty) return;

    if (sky) {
      for (final spot in here) {
        if (spot.kind == SeasonKind.sakura && !still) _petals(canvas, spot, s, sp, t);
        if (spot.kind == SeasonKind.hanabi) _fireworks(canvas, spot, s, sp, fade, t);
      }
      return;
    }
    for (final spot in here) {
      switch (spot.kind) {
        case SeasonKind.shrine || SeasonKind.temple:
          _hatsumode(canvas, spot, s, sp, fade, t);
        case SeasonKind.sakura || SeasonKind.momiji || SeasonKind.icho || SeasonKind.mixed:
          _trees(canvas, spot, s, sp, fade);
        case SeasonKind.lights:
          _lights(canvas, spot, s, sp, fade, t);
        case SeasonKind.hanabi:
          break;
      }
    }
  }

  // ---------------- trees (sakura, momiji, ginkgo) ----------------

  /// Sprite pixels on screen: the scenery's size (2 map units a pixel),
  /// kept from getting too small far out so the spot still reads.
  static double _treePx(double s) => 2 * math.max(s, 0.3);

  List<String> _treeImages(SeasonKind k) => switch (k) {
    SeasonKind.sakura => const [
      'assets/art/map_decor/sakura_a.png',
      'assets/art/map_decor/sakura_b.png',
      'assets/art/map_decor/sakura_c.png',
    ],
    SeasonKind.icho => const ['assets/art/map_seasons/icho_a.webp', 'assets/art/map_seasons/icho_b.webp'],
    SeasonKind.mixed => const [
      'assets/art/map_decor/momiji_a.png',
      'assets/art/map_seasons/icho_a.webp',
      'assets/art/map_decor/momiji_b.png',
      'assets/art/map_seasons/icho_b.webp',
    ],
    _ => const [
      'assets/art/map_decor/momiji_a.png',
      'assets/art/map_decor/momiji_b.png',
      'assets/art/map_decor/momiji_c.png',
    ],
  };

  /// Where the trees of a cluster stand, in map units from the spot
  /// (round a landmark: a ring, leaving its picture clear).
  static List<Offset> treeSpots(SeasonSpot spot) {
    final out = <Offset>[];
    for (var i = 0; i < spot.count; i++) {
      final a = spot.seed * 0.7 + i * 2.39996;
      final r = spot.onLandmark ? 78 + 22 * math.sqrt(i) : (i == 0 ? 0 : 30 + 22 * math.sqrt(i));
      out.add(Offset(math.cos(a) * r, math.sin(a) * r * 0.62));
    }
    return out..sort((a, b) => a.dy.compareTo(b.dy));
  }

  void _trees(Canvas canvas, SeasonSpot spot, double s, Offset Function(Offset) sp, double fade) {
    final names = _treeImages(spot.kind);
    final px = _treePx(s);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..color = Color.fromRGBO(0, 0, 0, fade);
    if (night) paint.colorFilter = _nightTone;
    // A soft blush on the ground under the cluster (pink / warm red).
    final c = sp(spot.position);
    final rr = (spot.onLandmark ? 120 : 70) * s + 10;
    final tint = switch (spot.kind) {
      SeasonKind.sakura => const Color(0xFFFFB7CF),
      SeasonKind.icho => const Color(0xFFFFD75E),
      _ => const Color(0xFFFF8A5B),
    };
    canvas.drawOval(
      Rect.fromCenter(center: c, width: rr * 2.2, height: rr * 1.3),
      Paint()
        ..color = tint.withValues(alpha: (night ? 0.12 : 0.22) * fade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rr * 0.35),
    );
    final at = treeSpots(spot);
    for (var i = 0; i < at.length; i++) {
      final img = images[names[(spot.seed + i) % names.length]];
      if (img == null) continue;
      final p = c + at[i] * s;
      final w = img.width * px, h = img.height * px;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(p.dx - w / 2, p.dy - h * 0.75, w, h),
        paint,
      );
    }
  }

  /// A few petals drifting down over the cherry trees (zoomed in only).
  void _petals(Canvas canvas, SeasonSpot spot, double s, Offset Function(Offset) sp, double t) {
    final a = ((s - 0.55) / 0.25).clamp(0.0, 1.0);
    if (a <= 0) return;
    final c = sp(spot.position);
    final q = (2.6 * s).clamp(2.0, 4.5);
    final paint = Paint();
    final n = 6 + spot.count * 2;
    final reach = (spot.onLandmark ? 120.0 : 80.0) * s;
    for (var j = 0; j < n; j++) {
      final speed = 1 + (j % 3);
      final ph = (t * speed + _rnd(spot.seed, j)) % 1.0;
      final x0 = (_rnd(spot.seed, j + 40) - 0.5) * 2 * reach;
      final y = -80 * s + ph * 130 * s;
      final x = x0 + math.sin((ph * 2 + _rnd(spot.seed, j + 80)) * math.pi * 2) * 9 * s + ph * 14 * s;
      final al = math.min(1.0, math.sin(ph * math.pi) * 1.8) * a;
      paint.color =
          (j % 3 == 0 ? const Color(0xFFFFF4F8) : (j.isEven ? const Color(0xFFFF6FA3) : const Color(0xFFEE4F8A)))
              .withValues(alpha: al * (night ? 0.7 : 0.95));
      final p = c.translate(x, y);
      // A petal turning as it falls: wide, then narrow.
      final wide = ((ph * 6 + j) % 2) < 1;
      canvas.drawRect(Rect.fromLTWH(p.dx, p.dy, q * (wide ? 1.6 : 0.9), q * (wide ? 0.9 : 1.4)), paint);
    }
  }

  // ---------------- 初詣 ----------------

  void _hatsumode(Canvas canvas, SeasonSpot spot, double s, Offset Function(Offset) sp, double fade, double t) {
    final c = sp(spot.position);
    // Warm glow round the shrine, breathing slowly (lanterns and bonfires).
    final r = (130 * s).clamp(16.0, 100.0);
    final pulse = 0.85 + 0.15 * math.sin(t * math.pi * 4);
    final glowAt = c.translate(0, -r * 0.3);
    canvas.drawCircle(
      glowAt,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          glowAt,
          r,
          [
            const Color(0xFFFFC060).withValues(alpha: (night ? 0.6 : 0.5) * fade * pulse),
            const Color(0xFFFF8A4A).withValues(alpha: (night ? 0.25 : 0.18) * fade * pulse),
            const Color(0x00FF8A4A),
          ],
          const [0, 0.5, 1],
        ),
    );
    // Far out: a small red torii (or temple gate) icon. Zoomed in: the
    // landmark picture, or the map's own little shrine / temple where no
    // landmark stands.
    final near = ((s - 0.42) / 0.2).clamp(0.0, 1.0);
    if (near < 1) _gateIcon(canvas, c, spot.kind == SeasonKind.temple, fade * (1 - near));
    final img =
        images[spot.kind == SeasonKind.temple
            ? 'assets/art/map_decor/temple_a.png'
            : 'assets/art/map_decor/shrine_a.png'];
    if (img != null && !spot.onLandmark && near > 0) {
      final px = _treePx(s);
      final w = img.width * px, h = img.height * px;
      final paint = Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(0, 0, 0, fade * near);
      if (night) paint.colorFilter = _nightTone;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(c.dx - w / 2, c.dy - h * 0.75, w, h),
        paint,
      );
    }
    final ca = ((s - 0.4) / 0.15).clamp(0.0, 1.0) * fade;
    if (ca <= 0) return;
    final q = (s * 1.5).clamp(1.0, 3.0);
    final paint = Paint();
    // A string of red paper lanterns over the approach, lit at night.
    final ly = c.dy + (spot.onLandmark ? 1 : 4) * q;
    for (var i = 0; i < 7; i++) {
      final x = c.dx + (i - 3) * 6 * q;
      final sag = (1 - math.pow((i - 3) / 3, 2)) * 2 * q;
      final at = Offset(x, ly + sag);
      if (night) {
        canvas.drawCircle(
          at,
          q * 3,
          Paint()
            ..color = const Color(0xFFFFB347).withValues(alpha: 0.35 * ca)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, q * 2),
        );
      }
      paint.color = (night ? const Color(0xFFFF6A4A) : const Color(0xFFD83A34)).withValues(alpha: ca);
      canvas.drawRect(Rect.fromCenter(center: at, width: 2 * q, height: 3 * q), paint);
      paint.color = const Color(0xFF2A2230).withValues(alpha: ca);
      canvas.drawRect(Rect.fromCenter(center: at.translate(0, -1.75 * q), width: 2 * q, height: q * 0.5), paint);
    }
    // The crowd on the approach, in furisode and winter coats, bobbing a little.
    const coats = [
      Color(0xFFD6334A), // red furisode
      Color(0xFF2B3A67), // navy coat
      Color(0xFFF2EDE4), // white
      Color(0xFFE58FB0), // pink
      Color(0xFF6B4A3A), // brown
      Color(0xFF3F7A5C), // green
      Color(0xFFE8A33A), // mustard
    ];
    final skin = (night ? const Color(0xFFB89A86) : const Color(0xFFF3CBA5)).withValues(alpha: ca);
    final hair = const Color(0xFF2A2230).withValues(alpha: ca);
    final top = ly + 6 * q;
    for (var i = 0; i < 13; i++) {
      final row = i < 7 ? 0 : 1;
      final col = row == 0 ? i : i - 7;
      final x = (col - (row == 0 ? 3 : 2.5)) * 4.5 * q + (_rnd(spot.seed, i + 60) - 0.5) * q;
      final y = top + row * 6 * q;
      final bob = !still && math.sin((t * 6 + _rnd(spot.seed, i)) * math.pi * 2) > 0.75 ? -q : 0.0;
      final o = Offset(c.dx + x, y + bob);
      var coat = coats[(spot.seed + i * 5) % coats.length];
      if (night) coat = Color.lerp(coat, const Color(0xFF1C2238), 0.35)!;
      paint.color = coat.withValues(alpha: ca);
      canvas.drawRect(Rect.fromLTWH(o.dx - 1.5 * q, o.dy, 3 * q, 3.5 * q), paint); // body
      paint.color = skin;
      canvas.drawRect(Rect.fromLTWH(o.dx - q, o.dy - 2 * q, 2 * q, 2 * q), paint); // face
      paint.color = hair;
      canvas.drawRect(Rect.fromLTWH(o.dx - q, o.dy - 2 * q, 2 * q, q), paint); // hair
    }
  }

  /// A crisp pixel torii (shrine) or temple gate, standing on [at].
  void _gateIcon(Canvas canvas, Offset at, bool temple, double alpha) {
    if (alpha <= 0) return;
    const u = 1.6;
    final o = Offset((at.dx / u).roundToDouble() * u, (at.dy / u).roundToDouble() * u);
    final paint = Paint();
    void px(double x, double y, double w, double h, Color c) {
      paint.color = c.withValues(alpha: alpha);
      canvas.drawRect(Rect.fromLTWH(o.dx + x * u, o.dy + y * u, w * u, h * u), paint);
    }

    const ink = Color(0xFF3A2228);
    if (temple) {
      // Grey tiled roof over a red gate with a dark doorway.
      px(-6, -10, 12, 1, ink);
      px(-5, -9, 10, 2, const Color(0xFF59606E));
      px(-6, -9, 1, 1, const Color(0xFF59606E));
      px(5, -9, 1, 1, const Color(0xFF59606E));
      px(-5, -7, 10, 1, ink);
      px(-4, -6, 8, 6, const Color(0xFFD8352A));
      px(-1, -4, 2, 4, ink);
      px(-5, 0, 10, 1, ink);
      return;
    }
    // Torii: the upturned top beam, the tie beam and two pillars.
    px(-6, -10, 12, 1, ink);
    px(-7, -11, 2, 1, ink);
    px(5, -11, 2, 1, ink);
    px(-5, -9, 10, 1, const Color(0xFFE2402F));
    px(-4, -7, 8, 1, const Color(0xFFE2402F));
    px(-4, -8, 8, 1, ink);
    px(-3, -8, 2, 8, const Color(0xFFE2402F));
    px(1, -8, 2, 8, const Color(0xFFE2402F));
    px(-3, -1, 2, 1, ink);
    px(1, -1, 2, 1, ink);
  }

  // ---------------- イルミネーション ----------------

  /// Light palettes: champagne gold, blue and white, colourful.
  static const _lightSets = [
    [Color(0xFFFFD86B), Color(0xFFFFF3C4), Color(0xFFFFB347)],
    [Color(0xFF7CC8FF), Color(0xFFE4F4FF), Color(0xFFA9C4FF)],
    [Color(0xFFFF6B6B), Color(0xFFFFD86B), Color(0xFF7CE0A0), Color(0xFF7CC8FF)],
  ];

  void _lights(Canvas canvas, SeasonSpot spot, double s, Offset Function(Offset) sp, double fade, double t) {
    final c = sp(spot.position);
    final g = s.clamp(0.36, 1.5); // screen px per layout unit
    final colors = _lightSets[spot.seed % _lightSets.length];
    final paint = Paint();
    final u = (3 * g).clamp(1.5, 4.0); // one pixel of the drawing
    Offset snap(Offset p) => Offset((p.dx / u).roundToDouble() * u, (p.dy / u).roundToDouble() * u);

    // An avenue of lit street trees, leaning like the map's streets.
    final lean = _rnd(spot.seed, 1) < 0.5 ? -1 : 1;
    final trees = <Offset>[
      for (var j = 0; j < 6; j++)
        for (final side in const [-1, 1])
          if (j != 2 && j != 3 || side > 0) Offset((j - 2.5) * 17.0, 20 + lean * (j - 2.5) * 5.0 + side * 9.0) * g,
    ];
    if (night) {
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(0, 0), width: 150 * g, height: 120 * g),
        Paint()
          ..color = colors.first.withValues(alpha: 0.28 * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 26 * g),
      );
    }
    for (var i = 0; i < trees.length; i++) {
      final p = snap(c + trees[i]);
      final col = colors[i % colors.length];
      final tw = 0.6 + 0.4 * math.sin((t * 3 + i * 0.618) * math.pi * 2);
      if (night) {
        canvas.drawCircle(
          p,
          u * 3.2,
          Paint()
            ..color = col.withValues(alpha: 0.75 * tw * fade)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 1.8),
        );
        paint.color = Color.lerp(col, const Color(0xFFFFFFFF), 0.5)!.withValues(alpha: tw * fade);
        canvas.drawRect(Rect.fromCenter(center: p, width: u * 2, height: u * 2), paint);
      } else {
        // By day: little round trees hung with lights.
        paint.color = const Color(0xFF3E7A4E).withValues(alpha: fade);
        canvas.drawRect(Rect.fromCenter(center: p, width: u * 3, height: u * 2), paint);
        canvas.drawRect(Rect.fromCenter(center: p, width: u * 2, height: u * 3), paint);
        paint.color = col.withValues(alpha: (0.8 + 0.2 * tw) * fade);
        canvas.drawRect(Rect.fromLTWH(p.dx - u, p.dy - u, u, u), paint);
        canvas.drawRect(Rect.fromLTWH(p.dx, p.dy, u, u), paint);
      }
    }

    // A big Christmas tree in the middle: a stepped pixel fir, covered in lights.
    const steps = [(1, 0), (3, 1), (3, 2), (5, 3), (5, 4), (7, 5), (7, 6), (9, 7), (9, 8), (11, 9)];
    final top = snap(c.translate(0, -18 * g - steps.length * u));
    final fir = (night ? const Color(0xFF1E3B33) : const Color(0xFF2E6B47)).withValues(alpha: fade);
    final edge = const Color(0xFF173226).withValues(alpha: fade);
    for (final (w, row) in steps) {
      paint.color = edge;
      canvas.drawRect(Rect.fromLTWH(top.dx - (w / 2 + 0.5) * u, top.dy + row * u, (w + 1) * u, u), paint);
    }
    for (final (w, row) in steps) {
      paint.color = fir;
      canvas.drawRect(Rect.fromLTWH(top.dx - w / 2 * u, top.dy + row * u, w * u, u), paint);
    }
    paint.color = const Color(0xFF6B4A3A).withValues(alpha: fade);
    canvas.drawRect(Rect.fromLTWH(top.dx - u, top.dy + steps.length * u, 2 * u, 2 * u), paint);
    // Its lights: a few twinkling dots along the rows.
    var k = 0;
    for (final (w, row) in steps.skip(1)) {
      for (var j = 0; j < w; j += 2) {
        if ((row + j) % 3 == 0) continue;
        k++;
        final col = colors[k % colors.length];
        final tw = 0.5 + 0.5 * math.sin((t * 4 + k * 0.618) * math.pi * 2);
        final p = Offset(top.dx + (j - (w - 1) / 2) * u, top.dy + (row + 0.5) * u);
        if (night) {
          canvas.drawCircle(
            p,
            u * 1.4,
            Paint()
              ..color = col.withValues(alpha: 0.5 * tw * fade)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, u),
          );
        }
        paint.color = col.withValues(alpha: (night ? 0.5 + 0.5 * tw : 0.75 + 0.25 * tw) * fade);
        canvas.drawRect(Rect.fromCenter(center: p, width: u, height: u), paint);
      }
    }
    // The star on top.
    final star = top.translate(0, -u);
    final sa = (0.75 + 0.25 * math.sin(t * math.pi * 6)) * fade;
    if (night) {
      canvas.drawCircle(
        star,
        u * 3,
        Paint()
          ..color = const Color(0xFFFFE27A).withValues(alpha: 0.5 * sa)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 2),
      );
    }
    paint.color = const Color(0xFFFFE27A).withValues(alpha: sa);
    canvas.drawRect(Rect.fromCenter(center: star, width: u * 3, height: u), paint);
    canvas.drawRect(Rect.fromCenter(center: star, width: u, height: u * 3), paint);
  }

  // ---------------- 花火 ----------------

  static const _fireColors = [
    Color(0xFFFF5A6E),
    Color(0xFFFFD45A),
    Color(0xFF6FE3FF),
    Color(0xFFFF8AD8),
    Color(0xFF8CFF8A),
    Color(0xFFC9A2FF),
    Color(0xFFFFA24A),
  ];

  /// Deeper colours for the still icons on the pale day map.
  static const _dayColors = [
    Color(0xFFE5304A),
    Color(0xFFF08C00),
    Color(0xFF1F8FE0),
    Color(0xFFD63AAF),
    Color(0xFF2FA84F),
    Color(0xFF7B4FE0),
  ];

  void _fireworks(Canvas canvas, SeasonSpot spot, double s, Offset Function(Offset) sp, double fade, double t) {
    final base = sp(spot.position);
    final r = burstRadius(s);
    if (!night || still) {
      // By day (or without motion): a small still fireworks icon.
      final at = base.translate(0, -r * 0.75);
      final cs = night ? _fireColors : _dayColors;
      _burst(canvas, at, r * 0.5, 1, cs[spot.seed % cs.length], cs[(spot.seed + 3) % cs.length], fade, glow: night);
      _burst(
        canvas,
        at.translate(r * 0.5, r * 0.2),
        r * 0.32,
        1,
        cs[(spot.seed + 1) % cs.length],
        cs[(spot.seed + 4) % cs.length],
        fade,
        glow: night,
      );
      return;
    }
    // At night: three shells in turn, each 3 s: up, burst, fade and droop.
    for (var b = 0; b < 3; b++) {
      final run = t * 2 + b / 3 + _rnd(spot.seed, 7);
      final ph = run % 1.0;
      final shot = run.floor() * 3 + b;
      final dx = (_rnd(spot.seed, shot + 11) - 0.5) * r * 1.5;
      final hi = r * (1.1 + _rnd(spot.seed, shot + 23) * 0.6);
      final at = base.translate(dx, -hi);
      final size = r * (0.65 + _rnd(spot.seed, shot + 31) * 0.4);
      final c1 = _fireColors[(spot.seed + shot * 3) % 7], c2 = _fireColors[(spot.seed + shot * 5 + 2) % 7];
      const rise = 0.2;
      if (ph < rise) {
        // The shell going up: a short trail of sparks.
        final k = ph / rise;
        final p = Offset.lerp(base.translate(dx * 0.7, 0), at, Curves.easeOut.transform(k))!;
        final q = (size / 18).clamp(1.5, 3.0);
        for (var i = 0; i < 4; i++) {
          canvas.drawRect(
            Rect.fromCenter(center: p.translate(0, i * q * 1.8), width: q, height: q),
            Paint()..color = const Color(0xFFFFF0C0).withValues(alpha: fade * (1 - i * 0.24)),
          );
        }
        continue;
      }
      _burst(canvas, at, size, (ph - rise) / (1 - rise), c1, c2, fade, glow: true);
    }
  }

  /// One firework at expansion [e] (0 = just burst, 1 = still, fully open).
  void _burst(Canvas canvas, Offset at, double size, double e, Color c1, Color c2, double fade, {bool glow = false}) {
    final open = e >= 1;
    final grow = open ? 1.0 : 1 - math.pow(1 - math.min(e * 1.4, 1.0), 3).toDouble();
    final rad = size * grow;
    // Full for a while, then fading out while the sparks droop.
    final alpha = (open ? 1.0 : (e < 0.45 ? 1.0 : math.pow(1 - (e - 0.45) / 0.55, 1.5).toDouble())) * fade;
    final droop = open ? 0.0 : size * 0.3 * e * e;
    final q = (size / 13).clamp(1.5, 4.0);
    if (glow) {
      canvas.drawCircle(
        at.translate(0, droop * 0.5),
        rad + 3,
        Paint()
          ..color = c1.withValues(alpha: 0.3 * alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.45 + 3),
      );
    }
    final paint = Paint();
    const n = 20;
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2;
      final dir = Offset(math.cos(a), math.sin(a));
      // Each spark with a tail back towards the centre.
      for (var k = 0; k < 3; k++) {
        final f = 1 - k * 0.13;
        paint.color = (k == 0 && e < 0.3 && !open ? Color.lerp(c1, const Color(0xFFFFFFFF), 0.6)! : c1).withValues(
          alpha: alpha * (1 - k * 0.3),
        );
        final w = q * (1 - k * 0.2);
        canvas.drawRect(
          Rect.fromCenter(center: at + dir * (rad * f) + Offset(0, droop * f), width: w, height: w),
          paint,
        );
      }
    }
    for (var i = 0; i < 10; i++) {
      final a = (i + 0.5) / 10 * math.pi * 2;
      paint.color = c2.withValues(alpha: alpha);
      canvas.drawRect(
        Rect.fromCenter(
          center: at + Offset(math.cos(a), math.sin(a)) * (rad * 0.5) + Offset(0, droop * 0.6),
          width: q,
          height: q,
        ),
        paint,
      );
    }
    paint.color = c2.withValues(alpha: alpha);
    canvas.drawRect(Rect.fromCenter(center: at.translate(0, droop * 0.4), width: q, height: q), paint);
    if (!open && e < 0.1) {
      paint.color = const Color(0xFFFFFFFF).withValues(alpha: (1 - e / 0.1) * fade);
      canvas.drawCircle(at, q * 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(SeasonPainter old) =>
      old.spots != spots ||
      old.night != night ||
      old.still != still ||
      old.sky != sky ||
      old.images.length != images.length;
}
