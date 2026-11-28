import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/pixel/pixel_scene.dart';
import '../trip_estimator.dart';
import '../trip_plan.dart';

/// Whether the train is in a tunnel right now: the current stop's flag while
/// standing, and on a run between an underground and an open-air stop, the
/// portal is taken to be half-way.
bool sideTrainUnderground(TripPlan plan, TripSnapshot s) {
  final cur = plan.stops[s.currentIndex];
  final ni = s.nextIndex;
  if (s.atStation || ni == null) return cur.underground;
  final next = plan.stops[ni];
  if (cur.underground == next.underground) return cur.underground;
  final run = next.arriveSec - cur.departSec;
  final f = run <= 0 ? 1.0 : (s.elapsedSec - cur.departSec) / run;
  return f < 0.5 ? cur.underground : next.underground;
}

/// The pictures of the side view (GPT-drawn pixel art, see
/// tools/gen_side_train_gpt.py and tools/cut_side_train.py). Any of them may
/// still be loading (null); the painter skips what is missing.
class SideTrainArt {
  const SideTrainArt({
    this.far,
    this.mid,
    this.tunnel,
    this.platform,
    this.platformUnderground,
    this.mast,
    this.lead,
    this.leadStripe,
    this.car,
    this.carStripe,
    this.leadGlass,
    this.carGlass,
  });

  /// Sky with the distant skyline, and the nearer houses and trees
  /// (transparent sky), for the time of day being shown.
  final ui.Image? far;
  final ui.Image? mid;
  final ui.Image? tunnel;
  final ui.Image? platform;
  final ui.Image? platformUnderground;
  final ui.Image? mast;

  /// The leading car (cab on the right) and a middle car, each with a white
  /// mask of its line-colour bands and one of its window glass (passengers
  /// darker), lit up warm after dark.
  final ui.Image? lead;
  final ui.Image? leadStripe;
  final ui.Image? car;
  final ui.Image? carStripe;
  final ui.Image? leadGlass;
  final ui.Image? carGlass;

  /// The scenery sets: Tokyo's city, and the themes of tools/gen_side_scenery_gpt.py.
  static const themes = [
    'city',
    'seaside',
    'country',
    'mountain',
    'oldtown',
    'river',
    'suburb',
    'snow',
    'harbor',
    'flower',
  ];

  static String _set(String theme) => theme == 'city' ? '' : '${theme}_';
  static String farAsset(DayPart p, [String theme = 'city']) => 'assets/art/side_${_set(theme)}far_${p.name}.webp';
  static String midAsset(DayPart p, [String theme = 'city']) => 'assets/art/side_${_set(theme)}mid_${p.name}.webp';
  static const tunnelAsset = 'assets/art/side_tunnel.webp';
  static const platformAsset = 'assets/art/side_platform.webp';
  static const platformUndergroundAsset = 'assets/art/side_platform_ug.webp';
  static const mastAsset = 'assets/art/side_mast.webp';
  static const leadAsset = 'assets/art/side_car_lead.webp';
  static const leadStripeAsset = 'assets/art/side_car_lead_stripe.webp';
  static const carAsset = 'assets/art/side_car_mid.webp';
  static const carStripeAsset = 'assets/art/side_car_mid_stripe.webp';
  static const leadGlassAsset = 'assets/art/side_car_lead_glass.webp';
  static const carGlassAsset = 'assets/art/side_car_mid_glass.webp';

  /// Loads everything for [part] with [load] (an asset path → image).
  static Future<SideTrainArt> loadWith(
    DayPart part,
    Future<ui.Image> Function(String) load, {
    String theme = 'city',
  }) async {
    Future<ui.Image?> get(String a) async {
      try {
        return await load(a);
      } catch (_) {
        return null;
      }
    }

    final r = await Future.wait([
      get(farAsset(part, theme)),
      get(midAsset(part, theme)),
      get(tunnelAsset),
      get(platformAsset),
      get(platformUndergroundAsset),
      get(mastAsset),
      get(leadAsset),
      get(leadStripeAsset),
      get(carAsset),
      get(carStripeAsset),
      get(leadGlassAsset),
      get(carGlassAsset),
    ]);
    return SideTrainArt(
      far: r[0],
      mid: r[1],
      tunnel: r[2],
      platform: r[3],
      platformUnderground: r[4],
      mast: r[5],
      lead: r[6],
      leadStripe: r[7],
      car: r[8],
      carStripe: r[9],
      leadGlass: r[10],
      carGlass: r[11],
    );
  }
}

/// The train seen from the side, running past scenery (or through a tunnel)
/// at the top of the trip screen. Pixel art on a 384×112 grid.
class SideTrainView extends StatefulWidget {
  const SideTrainView({super.key, required this.underground, required this.moving, required this.lineColor, this.now});

  final bool underground;

  /// false = standing at a station: the train slows down and stops at a platform.
  final bool moving;
  final Color lineColor;

  /// Only for tests and previews; defaults to Japan time now.
  final DateTime? now;

  @override
  State<SideTrainView> createState() => _SideTrainViewState();
}

class _SideTrainViewState extends State<SideTrainView> with SingleTickerProviderStateMixin {
  late final SideTrainSim _sim = SideTrainSim(moving: widget.moving, underground: widget.underground);
  late final Ticker _ticker = createTicker(_onTick);
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  SideTrainArt _art = const SideTrainArt();
  DayPart? _loaded;

  DayPart get _part => dayPartOf(widget.now ?? DateTime.now().toUtc().add(const Duration(hours: 9)));

  @override
  void initState() {
    super.initState();
    _load();
    _wake();
  }

  void _load() {
    final part = _part;
    if (part == _loaded) return;
    _loaded = part;
    SideTrainArt.loadWith(part, SceneArt.load).then((a) {
      if (mounted && _loaded == part) setState(() => _art = a);
    });
  }

  @override
  void didUpdateWidget(SideTrainView old) {
    super.didUpdateWidget(old);
    _load();
    _wake();
  }

  void _wake() {
    if (!_sim.idle(widget.moving, widget.underground) && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _sim.step(dt, moving: widget.moving, underground: widget.underground);
    _frame.value++;
    // Standing still at a platform: nothing moves, so stop ticking.
    if (_sim.idle(widget.moving, widget.underground)) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: SideTrainPainter.gridW / SideTrainPainter.gridH,
        child: CustomPaint(
          painter: SideTrainPainter(sim: _sim, part: _part, lineColor: widget.lineColor, art: _art, repaint: _frame),
        ),
      ),
    );
  }
}

/// The moving state of the view: how far the world has scrolled, how fast,
/// where the platform is, and the dark fade at a tunnel portal.
class SideTrainSim {
  SideTrainSim({required bool moving, required bool underground})
    : speed = moving ? maxSpeed : 0,
      shownUnderground = underground,
      platformX = moving ? null : SideTrainPainter.platformScreenX;

  static const maxSpeed = 460.0; // grid px / s on the track layer
  static const accel = 150.0;
  static const brake = 220.0;
  static const fadeSec = 0.7;

  /// World scroll of the track layer, in grid pixels.
  double offset = 0;
  double speed;

  /// Seconds since start, for bobbing and blinking.
  double time = 0;

  /// World x of the platform centre, while one is near.
  double? platformX;
  bool shownUnderground;

  /// Tunnel portal fade: null = none, else 0 → 1 (the scene swaps at 0.5).
  double? _fadeT;

  /// 0 = clear, 1 = black.
  double get darkness => _fadeT == null ? 0 : 1 - (2 * _fadeT! - 1).abs();

  bool idle(bool moving, bool underground) =>
      !moving && speed == 0 && _fadeT == null && underground == shownUnderground;

  void step(double dt, {required bool moving, required bool underground}) {
    time += dt;
    if (moving) {
      speed = math.min(maxSpeed, speed + accel * dt);
      if (platformX != null && platformX! - offset < -SideTrainPainter.platformHalf - 80) platformX = null;
    } else {
      // Pick the stopping point from the braking distance, then brake into it.
      platformX ??= offset + SideTrainPainter.platformScreenX + speed * speed / (2 * brake);
      final remaining = platformX! - SideTrainPainter.platformScreenX - offset;
      if (remaining <= 0.5) {
        offset += math.max(0, remaining);
        speed = 0;
      } else {
        speed = math.min(speed, math.sqrt(2 * brake * remaining));
        speed = math.max(speed, 12);
      }
    }
    offset += speed * dt;

    if (_fadeT == null && underground != shownUnderground) _fadeT = 0;
    if (_fadeT != null) {
      final before = _fadeT!;
      _fadeT = before + dt / fadeSec;
      if (before < 0.5 && _fadeT! >= 0.5) shownUnderground = underground;
      if (_fadeT! >= 1) _fadeT = null;
    }
  }
}

/// How the shared pictures (train, platform, mast) and the procedural parts
/// (grass, track, wires, fence) are lit for the time of day.
class _Pal {
  const _Pal({required this.tint, required this.train, required this.lamps, required this.sky});

  /// Multiplied into the pictures and colours drawn for every time of day.
  final Color tint;
  final Color train;

  /// Platform lamps and train windows lit.
  final bool lamps;

  /// Fills the sky above the skyline picture, if it ends below the top.
  final Color sky;

  static const day = _Pal(tint: Color(0xFFFFFFFF), train: Color(0xFFFFFFFF), lamps: false, sky: Color(0xFF6FBDEB));
  static const evening = _Pal(tint: Color(0xFFF2C6B6), train: Color(0xFFF6D9CB), lamps: true, sky: Color(0xFF8C6BA8));
  static const night = _Pal(tint: Color(0xFF6A7096), train: Color(0xFF9198B8), lamps: true, sky: Color(0xFF0F1630));

  static _Pal of(DayPart p) => switch (p) {
    DayPart.day => day,
    DayPart.evening => evening,
    DayPart.night => night,
  };

  Color t(Color c) => Color.from(alpha: c.a, red: c.r * tint.r, green: c.g * tint.g, blue: c.b * tint.b);
}

/// Paints one frame of [SideTrainSim]. Public so preview tools can render it.
///
/// Layers, back to front, each scrolling at its own share of the track speed:
/// sky + skyline (far picture, 0.06), houses and trees (mid picture, 0.3), the
/// grass bank, track, masts and wires (1.0), the train (still), the fence
/// (1.5). Underground the tunnel wall picture scrolls at 0.85. When the train
/// stops, a platform (picture behind the train, edge in front) slides in.
/// The depths of the side view, back to front, for a view that stands
/// them apart in 3D (see LayeredTrainView).
enum SideLayer {
  /// Sky and skyline, or the tunnel wall.
  back,

  /// Houses and trees.
  mid,

  /// Grass bank, track, masts and wires, the platform behind the train.
  track,

  /// The platform edge, the fence and the speed lines in front of the train.
  front,
}

class SideTrainPainter extends CustomPainter {
  SideTrainPainter({
    required this.sim,
    required this.part,
    required this.lineColor,
    required this.art,
    this.only,
    this.drawTrain = true,
    this.wireY,
    this.wires = true,
    this.snow = false,
    super.repaint,
  });

  /// Paint just these layers (null = all, with the portal dark on top).
  final Set<SideLayer>? only;

  /// false = leave the train out (a 3D train is drawn in its place).
  final bool drawTrain;

  /// Height of the contact wire (null = at the top of the side view's pantographs).
  final double? wireY;

  /// false = a line without overhead wires: no masts, no wire.
  final bool wires;

  /// The ground under snow (the snowy scenery).
  final bool snow;

  bool _on(SideLayer l) => only == null || only!.contains(l);

  static const gridW = 384.0;
  static const gridH = 112.0;
  static const railY = 96.0;

  /// Bottom of the skyline picture; the houses stand a little lower.
  static const groundY = 90.0;

  /// Where the lead car's nose is on screen.
  static const noseX = 356.0;
  static const carGap = 1.0;

  /// Where on screen the platform centre ends up when the train has stopped.
  static const platformScreenX = 200.0;
  static const platformHalf = 280.0;

  static const farSpeed = 0.06;
  static const midSpeed = 0.3;
  static const tunnelSpeed = 0.85;
  static const fenceSpeed = 1.5;
  static const mastGap = 224;

  final SideTrainSim sim;
  final DayPart part;
  final Color lineColor;
  final SideTrainArt art;

  final _p = Paint()..isAntiAlias = false;

  void _r(Canvas c, double x, double y, double w, double h, Color color) {
    _p.color = color;
    c.drawRect(Rect.fromLTWH(x.floorToDouble(), y, w, h), _p);
  }

  static int _h(int i, int salt) {
    var x = (i * 374761393 + salt * 668265263) & 0xFFFFFFFF;
    x = ((x ^ (x >> 13)) * 1274126177) & 0xFFFFFFFF;
    return (x ^ (x >> 16)) & 0x7FFFFFFF;
  }

  double get _run => sim.speed / SideTrainSim.maxSpeed;

  static Paint _imagePaint(Color? tint) {
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    if (tint != null && tint != const Color(0xFFFFFFFF)) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
    return paint;
  }

  /// [img] repeated sideways over [rect], scrolled left by [scroll] (whole
  /// pixels), its top at [y]. One shader, so the tiles never show a seam.
  void _tiled(Canvas c, ui.Image? img, double scroll, double y, Rect rect, {Color? tint}) {
    if (img == null) return;
    final dx = -(scroll.floorToDouble() % img.width);
    final m = Matrix4.translationValues(dx, y, 0);
    final paint = _imagePaint(tint)
      ..shader = ui.ImageShader(img, TileMode.repeated, TileMode.decal, m.storage, filterQuality: FilterQuality.none);
    c.drawRect(rect, paint);
  }

  void _image(Canvas c, ui.Image img, double x, double y, {Color? tint}) =>
      c.drawImage(img, Offset(x.floorToDouble(), y.floorToDouble()), _imagePaint(tint));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / gridW, size.height / gridH);
    if (sim.shownUnderground) {
      _tunnel(canvas);
    } else {
      _outside(canvas);
    }
    final d = only == null ? sim.darkness : 0;
    if (d > 0) _r(canvas, 0, 0, gridW, gridH, Color.fromRGBO(6, 6, 10, ((d * 4).ceil() / 4).clamp(0, 0.96)));
    canvas.restore();
  }

  // ---------------------------------------------------------------- outside

  void _outside(Canvas c) {
    final pal = _Pal.of(part);
    if (_on(SideLayer.back)) {
      _r(c, 0, 0, gridW, groundY, pal.sky);
      final far = art.far;
      if (far != null) {
        final top = groundY - far.height;
        _tiled(c, far, sim.offset * farSpeed, top, Rect.fromLTWH(0, top, gridW, far.height.toDouble()));
      }
    }
    final mid = art.mid;
    if (mid != null && _on(SideLayer.mid)) {
      // Stood apart in 3D, the houses' plane rises over the track's: grass under them closes the gap.
      if (only != null) {
        final ground = snow ? const Color(0xFFDCE4EE) : const Color(0xFF4F8C45);
        _r(c, 0, railY - 4, gridW, gridH - railY + 4, pal.t(ground));
      }
      final top = railY - 2 - mid.height;
      _tiled(c, mid, sim.offset * midSpeed, top, Rect.fromLTWH(0, top, gridW, mid.height.toDouble()));
    }
    if (_on(SideLayer.track)) {
      _embankment(c, pal);
      _track(
        c,
        pal.t(const Color(0xFF9C9488)),
        pal.t(const Color(0xFF7F776C)),
        pal.t(const Color(0xFFB8B0A2)),
        pal.t(const Color(0xFF6E5A48)),
        pal.t(const Color(0xFFE2E6EC)),
        pal.t(const Color(0xFF7D8188)),
      );
      // Masts first: a platform canopy hides them.
      if (wires) _masts(c, pal);
      if (_platformOn) _platformBack(c, pal, false);
    }
    if (drawTrain && only == null) {
      _train(c, pal.lamps, pal.train);
      if (part == DayPart.night) _beam(c, 0.18);
    }
    if (_on(SideLayer.front)) {
      if (_platformOn) _platformFront(c, pal, false);
      _fence(c, pal);
      _speedLines(c, const Color(0xFFFFFFFF), part == DayPart.night ? 0.18 : 0.4);
    }
  }

  /// Grass bank between the houses and the track.
  void _embankment(Canvas c, _Pal pal) {
    const top = railY - 4;
    final g = pal.t(snow ? const Color(0xFFE6ECF4) : const Color(0xFF6FAE52));
    final gl = pal.t(snow ? const Color(0xFFFFFFFF) : const Color(0xFF8CC461));
    final gd = pal.t(snow ? const Color(0xFFB9C6D6) : const Color(0xFF4F8C45));
    _r(c, 0, top, gridW, railY - top, g);
    _r(c, 0, top, gridW, 1, gl);
    final o = sim.offset * 0.9;
    final first = (o / 3).floor();
    for (var i = first; i <= first + gridW ~/ 3 + 1; i++) {
      final x = i * 3 - o;
      final k = _h(i, 71) % 7;
      if (k < 2) _r(c, x, top - 1, 1, 1, gl);
      if (k == 3) _r(c, x, top + 2, 2, 1, gd);
      if (k == 5 && _h(i, 72) % 4 == 0) _r(c, x, top + 1, 1, 1, pal.t(const Color(0xFFF7E27A)));
    }
  }

  void _track(Canvas c, Color ballast, Color dark, Color light, Color sleeper, Color rail, Color railShade) {
    _r(c, 0, railY, gridW, gridH - railY, ballast);
    final o = sim.offset;
    // Stones in the ballast.
    final first = o.floor();
    for (var x = first - first % 2; x < first + gridW; x += 2) {
      final k = _h(x, 41) % 5;
      final y = railY + 5 + (_h(x, 42) % (gridH - railY - 5).toInt()).toDouble();
      if (k == 0) _r(c, x - o, y, 2, 1, dark);
      if (k == 1) _r(c, x - o, y, 1, 1, light);
    }
    // Sleeper ends.
    const gap = 10;
    final s0 = (o / gap).floor();
    final sleeperShade = Color.lerp(sleeper, const Color(0xFF000000), 0.3)!;
    for (var i = s0; i <= s0 + gridW ~/ gap + 1; i++) {
      _r(c, i * gap - o, railY + 2, 6, 3, sleeper);
      _r(c, i * gap - o, railY + 4, 6, 1, sleeperShade);
    }
    _r(c, 0, railY, gridW, 1, rail);
    _r(c, 0, railY + 1, gridW, 1, railShade);
  }

  /// Overhead-wire masts (picture) and the wires between them.
  void _masts(Canvas c, _Pal pal) {
    final wire = pal.t(const Color(0xFF3E424B));
    // At the top of the pantographs.
    final contactY = (wireY ?? railY + 1 - (art.car?.height ?? 88) * carScale).floorToDouble();
    _r(c, 0, contactY, gridW, 1, wire);
    final m = art.mast;
    final o = sim.offset;
    final first = (o / mastGap).floor();
    for (var i = first - 1; i <= first + gridW ~/ mastGap + 1; i++) {
      final x = i * mastGap - o;
      // Messenger wire sagging between the masts, with droppers.
      const n = 8;
      for (var k = 0; k < n; k++) {
        final t = (k + 0.5) / n;
        final sag = (4 * t * (1 - t) * 5).roundToDouble();
        _r(c, x + k * mastGap / n, contactY - 10 + sag, mastGap / n + 1, 1, wire);
        if (k.isOdd) _r(c, x + k * mastGap / n, contactY - 9 + sag, 1, 9 - sag, wire);
      }
      if (m != null) {
        _image(c, m, x - m.width * 0.3, railY + 1 - m.height, tint: pal.tint);
      } else {
        _r(c, x, contactY - 14, 3, railY - contactY + 14, pal.t(const Color(0xFF7C808A)));
      }
    }
  }

  void _fence(Canvas c, _Pal pal) {
    final post = pal.t(const Color(0xFFE9E6DF));
    final shade = pal.t(const Color(0xFFB9B4AA));
    final hi = pal.t(const Color(0xFFFFFFFF));
    const gap = 36;
    final o = sim.offset * fenceSpeed;
    final first = (o / gap).floor();
    // No fence along a platform.
    final pl = _platformOn ? _platformL : double.infinity;
    final pr = pl + platformHalf * 2;
    for (final y in const [103.0, 107.0]) {
      if (pl > 0) _r(c, 0, y, math.min(pl, gridW), 1, shade);
      if (pr < gridW) _r(c, pr, y, gridW - pr, 1, shade);
    }
    for (var i = first; i <= first + gridW ~/ gap + 1; i++) {
      final x = i * gap - o;
      if (x + 10 > pl && x < pr) continue;
      // Faster than the train: smear the posts when running.
      final w = 3 + (_run * 6).floorToDouble();
      _r(c, x, 100, w, gridH - 100, post);
      _r(c, x + w - 1, 100, 1, gridH - 100, shade);
      _r(c, x, 100, w, 1, hi);
    }
  }

  // ---------------------------------------------------------------- tunnel

  void _tunnel(Canvas c) {
    final o = sim.offset;
    final t = art.tunnel;
    if (_on(SideLayer.back)) {
      _r(c, 0, 0, gridW, gridH, const Color(0xFF1C1E24));
      if (t != null) {
        final top = railY - t.height;
        _tiled(c, t, o * tunnelSpeed, top, Rect.fromLTWH(0, math.max(0, top), gridW, railY - math.max(0, top)));
      }
      _tunnelStreaks(c);
    }
    if (_on(SideLayer.track)) {
      if (_platformOn) _platformBack(c, _Pal.day, true);
      _track(
        c,
        const Color(0xFF26282F),
        const Color(0xFF1A1B20),
        const Color(0xFF3A3D46),
        const Color(0xFF34363E),
        const Color(0xFFA9AEB9),
        const Color(0xFF4E525C),
      );
    }
    if (drawTrain && only == null) {
      _train(c, true, const Color(0xFFB4B9CC));
      _reflections(c);
      _beam(c, 0.22);
    }
    if (_on(SideLayer.front)) {
      if (_platformOn) _platformFront(c, _Pal.day, true);
      _speedLines(c, const Color(0xFFFFF1C2), 0.22);
    }
  }

  static const _lightGap = 128;

  /// Light streaks rushing past along the wall, on top of the picture.
  void _tunnelStreaks(Canvas c) {
    final trail = (_run * 40).floorToDouble();
    if (trail <= 0) return;
    final o = sim.offset;
    final first = (o / _lightGap).floor();
    for (var i = first; i <= first + gridW ~/ _lightGap + 1; i++) {
      final x = i * _lightGap - o + 40;
      _r(c, x, 12, trail * 0.5, 1, const Color(0x50FFEDB2));
      _r(c, x + trail * 0.5, 12, trail * 0.5, 1, const Color(0x24FFEDB2));
    }
  }

  /// Tunnel lights sliding over the train roof.
  void _reflections(Canvas c) {
    final o = sim.offset;
    final first = (o / _lightGap).floor();
    final top = _trainTop;
    for (var i = first; i <= first + gridW ~/ _lightGap + 1; i++) {
      final x = i * _lightGap - o + 44;
      _r(c, x, top + 3, 6, 2, const Color(0x40FFF6D8));
      _r(c, x - 2, top + 5, 10, 20, const Color(0x12FFF6D8));
    }
  }

  // ---------------------------------------------------------------- platform

  bool get _platformOn {
    final p = sim.platformX;
    if (p == null) return false;
    final x = p - sim.offset;
    return x + platformHalf > 0 && x - platformHalf < gridW;
  }

  double get _platformL => (sim.platformX! - sim.offset - platformHalf).floorToDouble();

  /// Behind the train: the platform picture (canopy, pillars and benches; or
  /// the tiled wall underground), with dark ends.
  void _platformBack(Canvas c, _Pal pal, bool underground) {
    final l = _platformL;
    const w = platformHalf * 2;
    final img = underground ? art.platformUnderground : art.platform;
    if (img == null) return;
    final top = math.max(0.0, railY - img.height);
    final rect = Rect.fromLTWH(l, top, w, railY - top);
    _tiled(c, img, -l, railY - img.height, rect, tint: underground ? null : pal.tint);
    if (!underground && pal.lamps) _r(c, l, top, w, img.height * 0.35, const Color(0x1CFFE6A0));
    final end = underground ? const Color(0xFF1C1E24) : pal.t(const Color(0xFF8E887E));
    _r(c, l, top, 2, rect.height, end);
    _r(c, l + w - 2, top, 2, rect.height, end);
  }

  /// In front of the train: the platform edge hiding the bogies.
  void _platformFront(Canvas c, _Pal pal, bool underground) {
    final l = _platformL;
    const w = platformHalf * 2;
    final top = underground ? const Color(0xFFB8BBC2) : pal.t(const Color(0xFFC9C3B6));
    final face = underground ? const Color(0xFF8E929B) : pal.t(const Color(0xFFA9A396));
    const y = railY - 8;
    _r(c, l, y, w, 4, top);
    _r(c, l, y + 1, w, 2, pal.t(const Color(0xFFF2C230)));
    _r(c, l, y + 4, w, gridH - y - 4, face);
    _r(c, l, y + 4, w, 1, Color.lerp(face, const Color(0xFF000000), 0.25)!);
    final light = Color.lerp(face, const Color(0xFFFFFFFF), 0.12)!;
    final dark = Color.lerp(face, const Color(0xFF000000), 0.1)!;
    for (var x = 4.0; x < w; x += 16) {
      _r(c, l + x, y + 10, 8, 1, light);
      _r(c, l + x + 8, y + 16, 8, 1, dark);
    }
  }

  // ---------------------------------------------------------------- train

  /// The car pictures have twice the grid's resolution (finer detail).
  static const carScale = 0.5;

  double get _trainTop => railY + 1 - (art.lead?.height ?? 88) * carScale;

  /// [img] at [carScale], its top-left at grid ([x], [y]).
  void _carImage(Canvas c, ui.Image img, double x, double y, Color tint) {
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final dst = Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), img.width * carScale, img.height * carScale);
    c.drawImageRect(img, src, dst, _imagePaint(tint));
  }

  void _train(Canvas c, bool litWindows, Color tint) {
    final lead = art.lead;
    final mid = art.car ?? lead;
    if (lead == null || mid == null) return;
    final stripeTint = Color.from(
      alpha: 1,
      red: lineColor.r * tint.r,
      green: lineColor.g * tint.g,
      blue: lineColor.b * tint.b,
    );
    var x = noseX - lead.width * carScale;
    for (var car = 0; car < 4; car++) {
      final img = car == 0 ? lead : mid;
      final stripe = car == 0 ? art.leadStripe : art.carStripe;
      final glass = car == 0 ? art.leadGlass : art.carGlass;
      final w = img.width * carScale;
      final h = img.height * carScale;
      if (car > 0) x -= w + carGap;
      // A gentle clatter while running.
      final bob = sim.speed > 40 && math.sin(sim.time * 11 + car * 1.9) > 0.6 ? -1.0 : 0.0;
      final y = railY + 1 - h + bob;
      if (car > 0) {
        // Gangway between the bellows of this car and the one in front.
        _r(c, x + w - 1, y + h * 0.35, carGap + 2, h * 0.4, const Color(0xFF2A2830));
      }
      _carImage(c, img, x, y, tint);
      if (stripe != null) _carImage(c, stripe, x, y, stripeTint);
      if (litWindows && glass != null) _carImage(c, glass, x, y, const Color(0xE0FFE4A6));
    }
  }

  /// Headlight beam ahead of the lead car.
  void _beam(Canvas c, double alpha) {
    const x = noseX;
    const y = railY - 16;
    for (var k = 0; k < 4; k++) {
      final a = alpha * (1 - k * 0.22);
      _r(c, x + k * 8, y - k * 2, 8, 4 + k * 4.0, Color.fromRGBO(255, 242, 176, a));
    }
  }

  void _speedLines(Canvas c, Color color, double alpha) {
    final run = _run;
    if (run < 0.55) return;
    final a = alpha * ((run - 0.55) / 0.45);
    final o = sim.offset * 2.2;
    final top = _trainTop;
    for (var i = 0; i < 7; i++) {
      final len = 20.0 + _h(i, 61) % 44;
      final y = top + 4 + (_h(i, 62) % 30);
      final x = (_h(i, 63) % 520 - o) % 520 - 80;
      _r(c, x, y, len, 1, color.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(SideTrainPainter old) =>
      old.part != part || old.lineColor != lineColor || old.art != art || old.sim != sim || old.only != only;
}
