import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/pixel/pixel_scene.dart';
import 'side_train_view.dart';
import 'trip_props.dart';

/// The train at the top of the trip screen, HD-2D: the side view's pixel
/// art (skyline, houses, track and masts, fence; or the tunnel) stood up on
/// planes at their own depths, and between them a train modelled in
/// Blender and drawn as pixel art from the angle the camera looks at it
/// (tools/blender/train3d.py). A slow camera sway, and a finger dragging
/// it, turn the whole stack, so it reads as 3D from any angle. Speed,
/// braking into a platform and the dark at a tunnel portal come from
/// [SideTrainSim].
class LayeredTrainView extends StatefulWidget {
  const LayeredTrainView({
    super.key,
    required this.underground,
    required this.moving,
    required this.lineColor,
    this.theme = 'city',
    this.electric = true,
    this.now,
    this.camera,
  });

  final bool underground;

  /// false = standing at a station: the train brakes into a platform.
  final bool moving;
  final Color lineColor;

  /// The scenery set outside (see [sceneryFor]); a change fades over.
  final String theme;

  /// false = a diesel railcar on a line without overhead wires.
  final bool electric;

  /// Only for tests and previews; defaults to Japan time now.
  final DateTime? now;

  /// Only for previews: a fixed camera turn (yaw, pitch in radians) on top of the sway.
  final (double, double)? camera;

  @override
  State<LayeredTrainView> createState() => _LayeredTrainViewState();
}

class _LayeredTrainViewState extends State<LayeredTrainView> with SingleTickerProviderStateMixin {
  late final SideTrainSim _sim = SideTrainSim(moving: widget.moving, underground: widget.underground);
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  Train3dArt? _train;
  Props3dArt? _props;

  // The scenery shown, the one it fades from, and how far the fade is (1 = done).
  final _arts = <String, SideTrainArt>{};
  DayPart? _artsPart;
  late String _theme = widget.theme;
  String? _from;
  double _fade = 1;

  // Where a finger has turned the camera; springs back when let go.
  double _dragYaw = 0;
  double _dragPitch = 0;
  bool _dragging = false;

  DayPart get _part => dayPartOf(widget.now ?? DateTime.now().toUtc().add(const Duration(hours: 9)));

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _load(widget.theme);
    Train3dArt.load(electric: widget.electric).then((t) {
      if (mounted) setState(() => _train = t);
    });
    Props3dArt.load(SceneArt.load).then((p) {
      if (mounted) setState(() => _props = p);
    });
  }

  @override
  void didUpdateWidget(LayeredTrainView old) {
    super.didUpdateWidget(old);
    _load(widget.theme);
    // Changed onto a line with (or without) wires: the other train.
    if (old.electric != widget.electric) {
      Train3dArt.load(electric: widget.electric).then((t) {
        if (mounted) setState(() => _train = t);
      });
    }
  }

  /// Loads the pictures of [theme] (for the time of day now); when they are
  /// in and it is still the wanted one, the view fades over to it.
  void _load(String theme) {
    final part = _part;
    if (part != _artsPart) {
      _arts.clear();
      _artsPart = part;
    }
    if (_arts.containsKey(theme)) {
      _show(theme);
      return;
    }
    SideTrainArt.loadWith(part, SceneArt.load, theme: theme).then((a) async {
      // A set not in the app (yet): the city's instead.
      if (a.far == null && theme != 'city') a = await SideTrainArt.loadWith(part, SceneArt.load);
      if (!mounted || _artsPart != part) return;
      setState(() => _arts[theme] = a);
      if (widget.theme == theme) _show(theme);
    });
  }

  void _show(String theme) {
    if (theme == _theme) return;
    _from = _arts.containsKey(_theme) ? _theme : null;
    _theme = theme;
    _fade = _from == null ? 1 : 0;
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _sim.step(dt, moving: widget.moving, underground: widget.underground);
    if (_fade < 1) _fade = math.min(1, _fade + dt / 1.4);
    if (!_dragging) {
      final k = math.exp(-dt * 3);
      _dragYaw *= k;
      _dragPitch *= k;
    }
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  static const _persp = 0.0016;

  /// Every plane is a little larger than the view (far ones more), so a turn never shows an edge.
  static const _grow = 1.1;

  /// The planes' depths (+ = farther), in grid pixels.
  static const _zBack = 260.0;
  static const _zMid = 120.0;
  static const _zFront = -40.0;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return AspectRatio(
      aspectRatio: SideTrainPainter.gridW / SideTrainPainter.gridH,
      child: LayoutBuilder(
        builder: (context, box) {
          final k = box.maxWidth / SideTrainPainter.gridW;
          return GestureDetector(
            onPanStart: (_) => _dragging = true,
            onPanUpdate: (d) {
              _dragYaw = (_dragYaw + d.delta.dx * 0.006).clamp(-0.4, 0.4);
              _dragPitch = (_dragPitch + d.delta.dy * 0.004).clamp(-0.12, 0.2);
            },
            onPanEnd: (_) => _dragging = false,
            onPanCancel: () => _dragging = false,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RepaintBoundary(
                child: ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (context, _, _) {
                    final t = _sim.time;
                    final yaw = ((still ? 0 : 0.16 * math.sin(t * 0.33)) + _dragYaw + (widget.camera?.$1 ?? 0)).clamp(
                      -0.26,
                      0.26,
                    );
                    final pitch =
                        0.06 + (still ? 0 : 0.03 * math.sin(t * 0.21 + 1)) + _dragPitch + (widget.camera?.$2 ?? 0);
                    final size = box.biggest;
                    Matrix4 at(double z) => _plane(size, z, k, yaw, pitch);
                    SideTrainPainter layer(SideLayer l, String theme) => SideTrainPainter(
                      sim: _sim,
                      part: _part,
                      lineColor: widget.lineColor,
                      art: _arts[theme] ?? _arts[_from] ?? const SideTrainArt(),
                      only: {l},
                      drawTrain: false,
                      wireY: _Train3dPainter.wireY,
                      wires: widget.electric,
                      snow: theme == 'snow',
                    );
                    Widget paintAt(double z, CustomPainter painter, [double opacity = 1]) {
                      final p = Transform(
                        transform: at(z),
                        child: CustomPaint(size: size, painter: painter),
                      );
                      return opacity >= 1 ? p : Opacity(opacity: opacity, child: p);
                    }

                    // The scenery planes: while a new set fades in, the old one stays under it.
                    List<Widget> plane(SideLayer l, double z) => [
                      if (_fade < 1 && _from != null) paintAt(z, layer(l, _from!)),
                      paintAt(z, layer(l, _theme), _fade < 1 && _from != null ? _fade : 1),
                    ];
                    final under = _sim.shownUnderground;
                    final tint = tripTint(_part, under);
                    final lit = under || _part != DayPart.day;
                    List<Widget> props(PropLayer l, double z) {
                      final art = _props;
                      if (art == null || under) return const [];
                      TripPropsPainter painter(String theme, double o) => TripPropsPainter(
                        art: art,
                        sim: _sim,
                        theme: theme,
                        layer: l,
                        tint: tint,
                        lit: lit,
                        opacity: o,
                      );
                      return [
                        if (_fade < 1 && _from != null) paintAt(z, painter(_from!, 1 - _fade)),
                        paintAt(z, painter(_theme, _fade < 1 && _from != null ? _fade : 1)),
                      ];
                    }

                    return Stack(
                      children: [
                        Positioned.fill(child: ColoredBox(color: under ? const Color(0xFF15171D) : _skyOf(_part))),
                        ...plane(SideLayer.back, _zBack),
                        if (!under) ...plane(SideLayer.mid, _zMid),
                        ...props(PropLayer.side, 40),
                        ...plane(SideLayer.track, 0),
                        ...props(PropLayer.trussBack, 6),
                        // The train stands upright on the track, seen from the camera's angle.
                        if (_train case final train?)
                          CustomPaint(
                            size: size,
                            painter: _Train3dPainter(
                              art: train,
                              plane: at(0),
                              k: k,
                              yawDeg: yaw * 180 / math.pi,
                              pitchDeg: pitch * 180 / math.pi,
                              lineColor: widget.lineColor,
                              part: _part,
                              underground: under,
                              bob: _sim.speed > 40 && math.sin(t * 11) > 0.6,
                            ),
                          ),
                        ...props(PropLayer.trussFront, -8),
                        ...plane(SideLayer.front, _zFront),
                        // Evening light and a soft vignette, like the platform scenes.
                        IgnorePointer(
                          child: CustomPaint(size: size, painter: _Mood(_part, under)),
                        ),
                        if (_sim.darkness > 0)
                          Positioned.fill(
                            child: ColoredBox(color: Color.fromRGBO(6, 6, 10, _sim.darkness.clamp(0, 0.96))),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// A plane [zGrid] (grid pixels) away, turned with the camera about the
  /// view's centre and grown back to fill the view (a little more, so a
  /// turn never shows its edge).
  static Matrix4 _plane(Size size, double zGrid, double k, double yaw, double pitch) {
    final z = zGrid * k;
    final s = (1 + _persp * z) * (_grow + zGrid.abs() * 0.0012);
    final c = Offset(size.width / 2, size.height / 2);
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..setEntry(3, 2, _persp)
      ..rotateX(pitch)
      ..rotateY(yaw)
      ..translateByDouble(0, 0, z, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

  static Color _skyOf(DayPart p) => switch (p) {
    DayPart.day => const Color(0xFF6FBDEB),
    DayPart.evening => const Color(0xFF8C6BA8),
    DayPart.night => const Color(0xFF0F1630),
  };
}

/// The Blender train: three atlases (the train, its line band, its window
/// glass) of one frame per camera angle, and where each frame's rail and
/// nose fall. See tools/blender/pack_train3d.py.
class Train3dArt {
  Train3dArt._(this.base, this.stripe, this.glass, this.meta);

  final ui.Image base;
  final ui.Image stripe;
  final ui.Image glass;
  final Map<String, dynamic> meta;

  static final _cache = <String, Future<Train3dArt>>{};

  static const dir = 'assets/art/train3d';

  /// The three-car EMU, or ([electric] false) the two-car diesel railcar.
  static Future<Train3dArt> load({bool electric = true}) {
    final name = electric ? 'train3d' : 'train3d_dmu';
    return _cache[name] ??= () async {
      final r = await Future.wait([
        SceneArt.load('$dir/${name}_base.webp'),
        SceneArt.load('$dir/${name}_stripe.webp'),
        SceneArt.load('$dir/${name}_glass.webp'),
      ]);
      final meta = jsonDecode(await rootBundle.loadString('$dir/$name.json')) as Map<String, dynamic>;
      return Train3dArt._(r[0], r[1], r[2], meta);
    }();
  }

  int get w => meta['w'] as int;
  int get h => meta['h'] as int;
  List<int> get yaws => (meta['yaws'] as List).cast<int>();
  List<int> get pitches => (meta['pitches'] as List).cast<int>();

  /// Metres across a frame, and the train's length in metres.
  double get ortho => (meta['ortho'] as num).toDouble();
  double get span => (meta['span'] as num).toDouble();

  /// The frame nearest to the camera's turn.
  Map<String, dynamic> frame(double yawDeg, double pitchDeg) {
    int nearest(List<int> xs, double v) => xs.reduce((a, b) => (a - v).abs() <= (b - v).abs() ? a : b);
    return (meta['frames'] as Map<String, dynamic>)['${nearest(yaws, yawDeg)}_${nearest(pitches, pitchDeg)}']
        as Map<String, dynamic>;
  }
}

class _Train3dPainter extends CustomPainter {
  _Train3dPainter({
    required this.art,
    required this.plane,
    required this.k,
    required this.yawDeg,
    required this.pitchDeg,
    required this.lineColor,
    required this.part,
    required this.underground,
    required this.bob,
  });

  final Train3dArt art;
  final Matrix4 plane;
  final double k;
  final double yawDeg;
  final double pitchDeg;
  final Color lineColor;
  final DayPart part;
  final bool underground;
  final bool bob;

  /// Grid pixels per metre (the frames are packed at this scale), and where
  /// the train stands: its nose a little before the right edge, so the
  /// scenery shows around it.
  static const unitsPerMetre = 6.5;
  static const noseX = 330.0;

  /// The contact wire, where the pantograph (5.9 m above the rail in the model) reaches.
  static const wireY = SideTrainPainter.railY + 1 - 5.9 * unitsPerMetre;

  /// The body's light for the time of day (as the side view's train).
  Color get _tint => tripTint(part, underground);

  bool get _lit => underground || part != DayPart.day;

  @override
  void paint(Canvas canvas, Size size) {
    final f = art.frame(yawDeg, pitchDeg);
    final rail = (f['rail'] as List).cast<num>();
    final nose = (f['nose'] as List).cast<num>();
    // The rail under the train's middle, on the track plane, as the camera sees it.
    final mid = Offset((noseX - art.span * unitsPerMetre / 2) * k, (SideTrainPainter.railY + 1) * k);
    final anchor = MatrixUtils.transformPoint(plane, mid);
    // How big a frame pixel is on screen: the frame's metres over its pixels.
    final px = art.ortho / art.w * unitsPerMetre * k * _LayeredTrainViewState._grow;
    final src = Rect.fromLTWH(
      (f['x'] as num).toDouble(),
      (f['y'] as num).toDouble(),
      art.w.toDouble(),
      art.h.toDouble(),
    );
    final dst = Rect.fromLTWH(
      anchor.dx - rail[0] * px,
      anchor.dy - rail[1] * px + (bob ? -px : 0),
      art.w * px,
      art.h * px,
    );
    Paint paint(Color tint) => Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    final t = _tint;
    canvas.drawImageRect(art.base, src, dst, paint(t));
    canvas.drawImageRect(
      art.stripe,
      src,
      dst,
      paint(Color.from(alpha: 1, red: lineColor.r * t.r, green: lineColor.g * t.g, blue: lineColor.b * t.b)),
    );
    if (_lit) {
      canvas.drawImageRect(art.glass, src, dst, paint(const Color(0xE6FFE2A0)));
      // Headlight beam ahead of the nose.
      final n = Offset(dst.left + nose[0] * px, dst.top + nose[1] * px - 9 * px);
      final beam = Path()
        ..moveTo(n.dx, n.dy - 3 * k)
        ..lineTo(n.dx + 60 * k, n.dy - 14 * k)
        ..lineTo(n.dx + 60 * k, n.dy + 12 * k)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..shader = ui.Gradient.linear(n, n + Offset(60 * k, 0), [const Color(0x55FFF2B0), const Color(0x00FFF2B0)]),
      );
    }
  }

  @override
  bool shouldRepaint(_Train3dPainter old) => true;
}

/// Light over the whole view: a warm glow low in the evening sky, a cool
/// one at night, and darker corners.
class _Mood extends CustomPainter {
  _Mood(this.part, this.underground);
  final DayPart part;
  final bool underground;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final glow = underground
        ? null
        : switch (part) {
            DayPart.day => null,
            DayPart.evening => const Color(0x40FF9E5E),
            DayPart.night => const Color(0x223A5BC8),
          };
    if (glow != null) {
      canvas.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.radial(Offset(size.width * 0.78, size.height * 0.45), size.width * 0.6, [
            glow,
            glow.withValues(alpha: 0),
          ]),
      );
    }
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          r.center,
          size.width * 0.62,
          [const Color(0x00000000), Color.fromRGBO(0, 0, 10, underground || part == DayPart.night ? 0.32 : 0.16)],
          [0.6, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_Mood old) => old.part != part || old.underground != underground;
}
