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

/// The train seen from the side, running past scenery (or through a tunnel)
/// at the top of the trip screen. Pixel art drawn on a 192×56 grid.
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
  ui.Image? _base;
  ui.Image? _stripe;

  @override
  void initState() {
    super.initState();
    SceneArt.load('assets/art/train_side_base.png').then((i) => mounted ? setState(() => _base = i) : null);
    SceneArt.load('assets/art/train_side_stripe.png').then((i) => mounted ? setState(() => _stripe = i) : null);
    _wake();
  }

  @override
  void didUpdateWidget(SideTrainView old) {
    super.didUpdateWidget(old);
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
    final part = dayPartOf(widget.now ?? DateTime.now().toUtc().add(const Duration(hours: 9)));
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: SideTrainPainter.gridW / SideTrainPainter.gridH,
        child: CustomPaint(
          painter: SideTrainPainter(
            sim: _sim,
            part: part,
            lineColor: widget.lineColor,
            base: _base,
            stripe: _stripe,
            repaint: _frame,
          ),
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

  static const maxSpeed = 230.0; // grid px / s on the track layer
  static const accel = 75.0;
  static const brake = 110.0;
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
      if (platformX != null && platformX! - offset < -SideTrainPainter.platformHalf - 40) platformX = null;
    } else {
      // Pick the stopping point from the braking distance, then brake into it.
      platformX ??= offset + SideTrainPainter.platformScreenX + speed * speed / (2 * brake);
      final remaining = platformX! - SideTrainPainter.platformScreenX - offset;
      if (remaining <= 0.5) {
        offset += math.max(0, remaining);
        speed = 0;
      } else {
        speed = math.min(speed, math.sqrt(2 * brake * remaining));
        speed = math.max(speed, 6);
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

class _Pal {
  const _Pal({
    required this.sky,
    required this.far,
    required this.farHi,
    required this.tint,
    required this.tintAmount,
    required this.litWindows,
    required this.train,
  });

  final List<Color> sky;
  final Color far;
  final Color farHi;
  final Color tint;
  final double tintAmount;

  /// Share of building windows that are lit.
  final double litWindows;
  final Color train;

  static const day = _Pal(
    sky: [Color(0xFF6FBDEB), Color(0xFF8DCDF1), Color(0xFFABDBF5), Color(0xFFCBE9F7)],
    far: Color(0xFFA9C4D8),
    farHi: Color(0xFFBCD2E2),
    tint: Color(0xFFFFFFFF),
    tintAmount: 0,
    litWindows: 0,
    train: Color(0xFFFFFFFF),
  );
  static const evening = _Pal(
    sky: [Color(0xFF8C6BA8), Color(0xFFE07A72), Color(0xFFF39C6B), Color(0xFFFBC883)],
    far: Color(0xFFB57589),
    farHi: Color(0xFFC88A93),
    tint: Color(0xFFB0605E),
    tintAmount: 0.28,
    litWindows: 0.35,
    train: Color(0xFFF4D6C8),
  );
  static const night = _Pal(
    sky: [Color(0xFF0F1630), Color(0xFF151E3C), Color(0xFF1C2849), Color(0xFF253458)],
    far: Color(0xFF26304F),
    farHi: Color(0xFF2E3A5C),
    tint: Color(0xFF16203E),
    tintAmount: 0.68,
    litWindows: 0.55,
    train: Color(0xFF9097B4),
  );

  static _Pal of(DayPart p) => switch (p) {
    DayPart.day => day,
    DayPart.evening => evening,
    DayPart.night => night,
  };

  Color t(Color c) => tintAmount == 0 ? c : Color.lerp(c, tint, tintAmount)!;
}

/// Paints one frame of [SideTrainSim]. Public so preview tools can render it.
class SideTrainPainter extends CustomPainter {
  SideTrainPainter({
    required this.sim,
    required this.part,
    required this.lineColor,
    this.base,
    this.stripe,
    super.repaint,
  });

  static const gridW = 192.0;
  static const gridH = 56.0;
  static const railY = 46.0;
  static const trainTop = railY - 20;
  static const leadX = 116.0;
  static const carStep = 57.0;

  /// Where on screen the platform centre ends up when the train has stopped.
  static const platformScreenX = 100.0;
  static const platformHalf = 140.0;

  final SideTrainSim sim;
  final DayPart part;
  final Color lineColor;
  final ui.Image? base;
  final ui.Image? stripe;

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

  static double _u(int i, int salt) => (_h(i, salt) % 1000) / 1000;

  double get _run => sim.speed / SideTrainSim.maxSpeed;

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
    final d = sim.darkness;
    if (d > 0) _r(canvas, 0, 0, gridW, gridH, Color.fromRGBO(6, 6, 10, ((d * 4).ceil() / 4).clamp(0, 0.96)));
    canvas.restore();
  }

  // ---------------------------------------------------------------- outside

  void _outside(Canvas c) {
    final pal = _Pal.of(part);
    _sky(c, pal);
    _far(c, pal);
    _mid(c, pal);
    _bushes(c, pal);
    // Ground.
    _r(c, 0, 43, gridW, 3, pal.t(const Color(0xFF7DBE5A)));
    _r(c, 0, 43, gridW, 1, pal.t(const Color(0xFF94CC6C)));
    _track(
      c,
      pal.t(const Color(0xFFA39A8C)),
      pal.t(const Color(0xFF8A8174)),
      pal.t(const Color(0xFF6E5A48)),
      pal.t(const Color(0xFFD3D7DE)),
      pal.t(const Color(0xFF7D8188)),
    );
    _poles(c, pal);
    if (_platformOn) _platformBack(c, pal, false);
    _train(c, part == DayPart.night, pal.train);
    if (part == DayPart.night) _beam(c, 0.18);
    if (_platformOn) _platformFront(c, pal, false);
    _fence(c, pal);
    _speedLines(c, const Color(0xFFFFFFFF), part == DayPart.night ? 0.18 : 0.45);
  }

  void _sky(Canvas c, _Pal pal) {
    const bands = [0.0, 10.0, 20.0, 29.0, 44.0];
    for (var b = 0; b < 4; b++) {
      _r(c, 0, bands[b], gridW, bands[b + 1] - bands[b], pal.sky[b]);
      // Dithered seam into the next band.
      if (b < 3) {
        _p.color = pal.sky[b + 1];
        for (var x = 0; x < gridW; x += 2) {
          c.drawRect(Rect.fromLTWH(x.toDouble(), bands[b + 1] - 1, 1, 1), _p);
        }
      }
    }
    if (part == DayPart.night) {
      for (var i = 0; i < 26; i++) {
        final x = (_h(i, 1) % 192).toDouble();
        final y = (_h(i, 2) % 26).toDouble();
        final blink = (sim.time * 1.3 + i * 0.37) % 3 < 0.25;
        _r(c, x, y, 1, 1, blink ? const Color(0xFF8C96B8) : const Color(0xFFE8ECFF));
      }
      // Moon.
      const m = Color(0xFFFFF4C8);
      _r(c, 152, 5, 4, 6, m);
      _r(c, 151, 6, 6, 4, m);
      _r(c, 154, 6, 2, 2, const Color(0xFFF0E2A8));
    } else {
      // Clouds drift slowly.
      final cloud = part == DayPart.day ? const Color(0xFFFFFFFF) : const Color(0xFFFFD9C0);
      final shade = part == DayPart.day ? const Color(0xFFE3F1FA) : const Color(0xFFF3B79E);
      final o = sim.offset * 0.03 + sim.time * 2;
      for (var i = 0; i < 4; i++) {
        final x = ((i * 61 + _h(i, 3) % 30) - o) % 240 - 24;
        final y = 4.0 + _h(i, 4) % 14;
        final w = 14.0 + _h(i, 5) % 12;
        _r(c, x, y + 2, w, 3, cloud);
        _r(c, x + 3, y, w - 8, 2, cloud);
        _r(c, x + 1, y + 5, w - 2, 1, shade);
      }
    }
  }

  void _far(Canvas c, _Pal pal) {
    const slot = 9;
    final o = sim.offset * 0.12;
    final first = (o / slot).floor();
    for (var i = first; i <= first + 192 ~/ slot + 1; i++) {
      final x = i * slot - o;
      final h = 5.0 + _h(i, 11) % 13;
      final w = 6.0 + _h(i, 12) % 5;
      final col = _h(i, 13) % 3 == 0 ? pal.farHi : pal.far;
      _r(c, x, 44 - h, w, h, col);
      if (_h(i, 14) % 41 == 0) {
        // A red-and-white lattice tower now and then.
        final tw = x + 2;
        for (var k = 0; k < 7; k++) {
          _r(
            c,
            tw - (k > 4 ? 1 : 0),
            44 - h - 22 + k * 3 + 6,
            k > 4 ? 5 : 3,
            3,
            pal.t(k.isEven ? const Color(0xFFE2574C) : const Color(0xFFF4F1EC)),
          );
        }
        _r(c, tw + 1, 44 - h - 19, 1, 3, pal.t(const Color(0xFFE2574C)));
      }
      if (part == DayPart.night) {
        for (var k = 0; k < 3; k++) {
          if (_h(i * 3 + k, 15) % 3 != 0) continue;
          _r(
            c,
            x + 1 + (_h(i, 16 + k) % (w - 2)),
            44 - h + 2 + (_h(i, 19 + k) % (h - 3)),
            1,
            1,
            const Color(0xFFE8C46A),
          );
        }
        if (h > 15 && (sim.time + i) % 2 < 1) _r(c, x + 1, 44 - h - 1, 1, 1, const Color(0xFFFF4A4A));
      }
    }
  }

  static const _walls = [Color(0xFFEFE4D2), Color(0xFFD7E1E8), Color(0xFFF2D7C0), Color(0xFFDCE3CF), Color(0xFFE7D2D6)];
  static const _roofs = [Color(0xFFC96F5A), Color(0xFF6F8FB5), Color(0xFF5E7F6A), Color(0xFF8C6E9B)];

  void _mid(Canvas c, _Pal pal) {
    const slot = 26;
    final o = sim.offset * 0.42;
    final first = (o / slot).floor();
    for (var i = first; i <= first + 192 ~/ slot + 1; i++) {
      final x = i * slot - o + _h(i, 21) % 5;
      final kind = _h(i, 22) % 7;
      final wall = pal.t(_walls[_h(i, 23) % _walls.length]);
      if (kind <= 2) {
        // Block of flats / office.
        final w = 15.0 + _h(i, 24) % 8;
        final h = 12.0 + _h(i, 25) % 14;
        final top = 44 - h;
        _r(c, x, top, w, h, wall);
        _r(c, x + w - 2, top, 2, h, Color.lerp(wall, const Color(0xFF000000), 0.12)!);
        _r(c, x, top, w, 1, Color.lerp(wall, const Color(0xFF000000), 0.2)!);
        for (var wy = top + 3; wy < 41; wy += 4) {
          for (var wx = x + 2; wx < x + w - 3; wx += 4) {
            final lit = _u((wx * 7 + wy * 13).floor() + i * 101, 26) < pal.litWindows;
            _r(c, wx, wy, 2, 2, lit ? const Color(0xFFFFD66B) : pal.t(const Color(0xFF8FAABF)));
          }
        }
      } else if (kind <= 4) {
        // Little house with a stepped roof.
        final w = 14.0 + _h(i, 27) % 5;
        final roof = pal.t(_roofs[_h(i, 28) % _roofs.length]);
        _r(c, x, 36, w, 8, wall);
        for (var k = 0; k < 3; k++) {
          _r(c, x - 1 + k * 2, 35 - k * 2.0, w + 2 - k * 4, 2, roof);
        }
        final lit = _u(i, 29) < pal.litWindows + 0.15;
        _r(c, x + 3, 38, 3, 3, part != DayPart.day && lit ? const Color(0xFFFFD66B) : pal.t(const Color(0xFF8FAABF)));
        _r(c, x + w - 6, 39, 3, 5, Color.lerp(roof, const Color(0xFF000000), 0.25)!);
      } else {
        // Trees.
        final g = pal.t(kind == 5 ? const Color(0xFF5FAE62) : const Color(0xFF4E9B5A));
        final gd = Color.lerp(g, const Color(0xFF000000), 0.18)!;
        _r(c, x + 4, 38, 2, 6, pal.t(const Color(0xFF7A5A40)));
        _r(c, x + 1, 31, 8, 7, g);
        _r(c, x + 2, 29, 6, 2, g);
        _r(c, x + 1, 36, 8, 2, gd);
        _r(c, x + 11, 34, 7, 6, g);
        _r(c, x + 12, 33, 5, 1, g);
        _r(c, x + 14, 40, 1, 4, pal.t(const Color(0xFF7A5A40)));
      }
    }
  }

  void _bushes(Canvas c, _Pal pal) {
    const slot = 14;
    final o = sim.offset * 0.7;
    final first = (o / slot).floor();
    final g = pal.t(const Color(0xFF6DBB5E));
    final gd = pal.t(const Color(0xFF559E4C));
    for (var i = first; i <= first + 192 ~/ slot + 1; i++) {
      if (_h(i, 31) % 3 == 0) continue;
      final x = i * slot - o;
      final w = 8.0 + _h(i, 32) % 7;
      _r(c, x, 40, w, 4, g);
      _r(c, x + 2, 39, w - 4, 1, g);
      _r(c, x, 42, w, 1, gd);
    }
  }

  void _track(Canvas c, Color ballast, Color speck, Color sleeper, Color rail, Color railShade) {
    _r(c, 0, railY, gridW, gridH - railY, ballast);
    final o = sim.offset;
    // Specks in the ballast.
    final first = o.floor();
    for (var x = first - first % 3; x < first + 192; x += 3) {
      if (_h(x, 41) % 4 != 0) continue;
      _r(c, x - o, 48 + (_h(x, 42) % 7).toDouble(), 1, 1, speck);
    }
    // Sleepers.
    const gap = 6;
    final s0 = (o / gap).floor();
    for (var i = s0; i <= s0 + 192 ~/ gap + 1; i++) {
      _r(c, i * gap - o, railY + 1, 3, 2, sleeper);
    }
    _r(c, 0, railY, gridW, 1, rail);
    _r(c, 0, railY + 1, gridW, 1, railShade);
  }

  void _poles(Canvas c, _Pal pal) {
    final pole = pal.t(const Color(0xFF7C808A));
    final hi = pal.t(const Color(0xFFA4A8B0));
    final wire = pal.t(const Color(0xFF4A4E57));
    const gap = 70;
    final o = sim.offset;
    final first = (o / gap).floor();
    // Contact wire, and the messenger wire sagging between poles.
    _r(c, 0, 22, gridW, 1, wire);
    for (var i = first; i <= first + 192 ~/ gap + 1; i++) {
      final x = i * gap - o;
      for (var k = 0; k < 5; k++) {
        final sag = (k == 0 || k == 4) ? 0 : (k == 2 ? 2 : 1);
        _r(c, x + k * gap / 5, 16 + sag.toDouble(), gap / 5, 1, wire);
      }
      _r(c, x, 13, 2, railY - 13, pole);
      _r(c, x, 13, 1, railY - 13, hi);
      _r(c, x - 1, 15, 12, 1, pole);
      _r(c, x + 9, 15, 1, 8, wire);
    }
  }

  void _fence(Canvas c, _Pal pal) {
    final post = pal.t(const Color(0xFFE9E6DF));
    final shade = pal.t(const Color(0xFFB9B4AA));
    const gap = 20;
    final o = sim.offset * 1.5;
    final first = (o / gap).floor();
    // No fence along a platform.
    final pl = _platformOn ? _platformL : double.infinity;
    final pr = pl + platformHalf * 2;
    if (pl > 0) _r(c, 0, 52, math.min(pl, gridW), 1, shade);
    if (pr < gridW) _r(c, pr, 52, gridW - pr, 1, shade);
    for (var i = first; i <= first + 192 ~/ gap + 1; i++) {
      final x = i * gap - o;
      if (x + 6 > pl && x < pr) continue;
      // Faster than the train: smear the posts when running.
      final w = 2 + (_run * 3).floorToDouble();
      _r(c, x, 50, w, 6, post);
      _r(c, x + w - 1, 50, 1, 6, shade);
    }
  }

  // ---------------------------------------------------------------- tunnel

  void _tunnel(Canvas c) {
    final o = sim.offset;
    _r(c, 0, 0, gridW, gridH, const Color(0xFF30343E));
    _r(c, 0, 0, gridW, 3, const Color(0xFF1A1C22));
    _r(c, 0, 3, gridW, 3, const Color(0xFF24272F));
    // Concrete rings, alternately shaded so the scroll reads.
    const ring = 32;
    final first = (o / ring).floor();
    for (var i = first; i <= first + 192 ~/ ring + 1; i++) {
      final x = i * ring - o;
      if (i.isEven) _r(c, x, 6, ring.toDouble(), 40, const Color(0xFF2C3039));
      _r(c, x, 6, 1, 40, const Color(0xFF23262E));
      _r(c, x + 1, 6, 1, 40, const Color(0xFF393E49));
    }
    // Cables on hangers.
    for (var i = first; i <= first + 192 ~/ ring + 1; i++) {
      final x = i * ring - o;
      _r(c, x + 1, 13, 1, 3, const Color(0xFF50555F));
      for (var k = 0; k < 4; k++) {
        final sag = (k == 0 || k == 3) ? 0.0 : 1.0;
        _r(c, x + k * 8, 15 + sag, 8, 1, const Color(0xFF17181D));
        _r(c, x + k * 8, 17 + sag, 8, 1, const Color(0xFF3E2C2A));
        _r(c, x + k * 8, 19 + sag, 8, 1, const Color(0xFF1C1F26));
      }
    }
    // Signs now and then: a green exit sign, a signal.
    const signGap = 180;
    final s0 = (o / signGap).floor();
    for (var i = s0; i <= s0 + 2; i++) {
      final x = i * signGap - o + 40;
      if (i.isEven) {
        _r(c, x, 22, 8, 4, const Color(0xFF2FA35A));
        _r(c, x + 2, 23, 1, 2, const Color(0xFFE8FFEE));
        _r(c, x + 4, 23, 3, 1, const Color(0xFFE8FFEE));
      } else {
        _r(c, x, 22, 4, 7, const Color(0xFF15171B));
        _r(c, x + 1, 23, 2, 2, (sim.time % 1.6) < 1.2 ? const Color(0xFF52E07A) : const Color(0xFF214A2E));
        _r(c, x + 1, 26, 2, 2, const Color(0xFF4A1F1F));
      }
    }
    _lights(c);
    if (_platformOn) _platformBack(c, _Pal.day, true);
    _track(
      c,
      const Color(0xFF1F2127),
      const Color(0xFF2C2F37),
      const Color(0xFF2A2C33),
      const Color(0xFF9DA2AD),
      const Color(0xFF4E525C),
    );
    _train(c, true, const Color(0xFFA6ACC0));
    _reflections(c);
    _beam(c, 0.22);
    if (_platformOn) _platformFront(c, _Pal.day, true);
    _speedLines(c, const Color(0xFFFFF1C2), 0.22);
  }

  static const _lightGap = 64;

  void _lights(Canvas c) {
    final o = sim.offset;
    final first = (o / _lightGap).floor();
    final trail = (_run * 16).floorToDouble();
    for (var i = first; i <= first + 192 ~/ _lightGap + 1; i++) {
      final x = i * _lightGap - o + 20;
      _r(c, x - 3, 6, 13, 12, const Color(0x14FFE6A0));
      _r(c, x - 1, 7, 9, 5, const Color(0x22FFE6A0));
      _r(c, x, 8, 7, 2, const Color(0xFFFFEDB2));
      _r(c, x, 10, 7, 1, const Color(0xFF6A6458));
      // Streak left behind as the light rushes past.
      if (trail > 0) {
        _r(c, x + 7, 8, trail * 0.5, 2, const Color(0x88FFEDB2));
        _r(c, x + 7 + trail * 0.5, 8, trail * 0.5, 2, const Color(0x40FFEDB2));
      }
    }
  }

  /// Tunnel lights sliding over the train roof.
  void _reflections(Canvas c) {
    final o = sim.offset;
    final first = (o / _lightGap).floor();
    for (var i = first; i <= first + 192 ~/ _lightGap + 1; i++) {
      final x = i * _lightGap - o + 22;
      _r(c, x, trainTop + 1, 3, 2, const Color(0x40FFF6D8));
      _r(c, x - 1, trainTop + 3, 5, 9, const Color(0x14FFF6D8));
    }
  }

  // ---------------------------------------------------------------- platform

  bool get _platformOn {
    final p = sim.platformX;
    if (p == null) return false;
    final x = p - sim.offset;
    return x + platformHalf > 0 && x - platformHalf < gridW;
  }

  double get _platformL => sim.platformX! - sim.offset - platformHalf;

  /// Behind the train: roof, pillars, and (underground) a tiled lit wall.
  void _platformBack(Canvas c, _Pal pal, bool underground) {
    final l = _platformL;
    const w = platformHalf * 2;
    if (underground) {
      _r(c, l, 0, w, railY, const Color(0xFFDCDFE5));
      for (var y = 8.0; y < railY; y += 5) {
        _r(c, l, y, w, 1, const Color(0xFFC9CDD5));
      }
      _r(c, l, 0, w, 4, const Color(0xFFB4B8C0));
      _r(c, l, 4, w, 2, const Color(0xFFFFF8DE));
      _r(c, l, 18, w, 3, lineColor);
      _r(c, l, 0, 2, railY, const Color(0xFF1C1E24));
      _r(c, l + w - 2, 0, 2, railY, const Color(0xFF1C1E24));
      for (var x = 10.0; x < w; x += 44) {
        _r(c, l + x, 8, 12, 5, const Color(0xFF2C3A55));
        _r(c, l + x + 1, 9, 3, 3, lineColor);
        _r(c, l + x + 5, 10, 6, 1, const Color(0xFFE8ECF4));
      }
      return;
    }
    final roof = pal.t(const Color(0xFFE9E4DA));
    final pillar = pal.t(const Color(0xFFCFC9BE));
    _r(c, l, 7, w, 3, roof);
    _r(c, l, 10, w, 1, pal.t(const Color(0xFF9E978C)));
    _r(c, l, 6, w, 1, pal.t(lineColor));
    for (var x = 18.0; x < w; x += 56) {
      _r(c, l + x, 11, 2, railY - 11, pillar);
      // Station sign under the roof.
      _r(c, l + x + 8, 12, 16, 5, pal.t(const Color(0xFFF8F8F4)));
      _r(c, l + x + 8, 16, 16, 1, pal.t(lineColor));
      _r(c, l + x + 10, 13, 2, 2, pal.t(lineColor));
      _r(c, l + x + 14, 13, 8, 1, pal.t(const Color(0xFF55596A)));
    }
    if (part != DayPart.day) {
      for (var x = 6.0; x < w; x += 28) {
        _r(c, l + x, 11, 8, 1, const Color(0xFFFFF1C2));
      }
    }
  }

  /// In front of the train: the platform edge hiding the bogies.
  void _platformFront(Canvas c, _Pal pal, bool underground) {
    final l = _platformL;
    const w = platformHalf * 2;
    final top = underground ? const Color(0xFFB8BBC2) : pal.t(const Color(0xFFC9C3B6));
    final face = underground ? const Color(0xFF8E929B) : pal.t(const Color(0xFFA9A396));
    _r(c, l, 40, w, 3, top);
    _r(c, l, 41, w, 1, pal.t(const Color(0xFFF2C230)));
    _r(c, l, 43, w, gridH - 43, face);
    _r(c, l, 43, w, 1, Color.lerp(face, const Color(0xFF000000), 0.2)!);
    for (var x = 4.0; x < w; x += 12) {
      _r(c, l + x, 47, 6, 1, Color.lerp(face, const Color(0xFFFFFFFF), 0.12)!);
    }
  }

  // ---------------------------------------------------------------- train

  void _train(Canvas c, bool litWindows, Color tint) {
    final b = base;
    final s = stripe;
    if (b == null) return;
    final src = Rect.fromLTWH(0, 0, b.width.toDouble(), b.height.toDouble());
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    final stripePaint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..colorFilter = ColorFilter.mode(
        Color.from(alpha: 1, red: lineColor.r * tint.r, green: lineColor.g * tint.g, blue: lineColor.b * tint.b),
        BlendMode.modulate,
      );
    for (var car = 0; car < 4; car++) {
      final x = leadX - car * carStep;
      // A gentle clatter while running.
      final bob = sim.speed > 20 && math.sin(sim.time * 11 + car * 1.9) > 0.6 ? -1.0 : 0.0;
      final y = trainTop + bob;
      // Coupler.
      if (car > 0) _r(c, x + 55, y + 14, 3, 2, const Color(0xFF2A2333));
      c.drawImageRect(b, src, Rect.fromLTWH(x, y, 56, 20), paint);
      if (s != null) c.drawImageRect(s, src, Rect.fromLTWH(x, y, 56, 20), stripePaint);
      if (litWindows) {
        for (final wx in const [17.0, 31.0]) {
          _r(c, x + wx, y + 5, 7, 4, const Color(0xD8FFE9A6));
          _r(c, x + wx, y + 5, 7, 1, const Color(0xFFFFF6D0));
        }
      }
      // Passengers: a head or two in the windows.
      for (var k = 0; k < 2; k++) {
        if (_h(car * 2 + k, 51) % 3 == 0) continue;
        final hx = x + (k == 0 ? 18 : 32) + _h(car * 2 + k, 52) % 4;
        _r(c, hx, y + 7, 2, 2, litWindows ? const Color(0xFF5A4A5E) : const Color(0xFF3B4A66));
        _r(c, hx - 1, y + 9, 4, 1, litWindows ? const Color(0xFF5A4A5E) : const Color(0xFF3B4A66));
      }
    }
  }

  /// Headlight beam ahead of the lead car.
  void _beam(Canvas c, double alpha) {
    final x = leadX + 56;
    final y = trainTop + 12;
    for (var k = 0; k < 4; k++) {
      final a = alpha * (1 - k * 0.22);
      _r(c, x + k * 6, y - k, 6, 2 + k * 2.0, Color.fromRGBO(255, 242, 176, a));
    }
  }

  void _speedLines(Canvas c, Color color, double alpha) {
    final run = _run;
    if (run < 0.55) return;
    final a = alpha * ((run - 0.55) / 0.45);
    final o = sim.offset * 2.2;
    for (var i = 0; i < 5; i++) {
      final len = 10.0 + _h(i, 61) % 22;
      final y = trainTop + 2 + (_h(i, 62) % 16);
      final x = (_h(i, 63) % 260 - o) % 260 - 40;
      _r(c, x, y.toDouble(), len, 1, color.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(SideTrainPainter old) =>
      old.part != part || old.lineColor != lineColor || old.base != base || old.stripe != stripe || old.sim != sim;
}
