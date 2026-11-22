part of 'pixel_scene.dart';

/// Gentle life drawn over any platform picture, so every scene (also the
/// crowd and weather versions, which have no animation of their own) moves
/// a little: birds crossing by day and at dusk, windows going on and off in
/// the evening and at night, stars and a plane's blinking light at night.
///
/// The dark sky and the lit windows are found once per picture from its pixels.
class SceneAmbience {
  SceneAmbience._(this.stars, this.windows, this.seed);

  /// Spots of dark night sky where a star can twinkle.
  final List<Offset> stars;

  /// Lit windows (scene pixels) on the city side.
  final List<Offset> windows;
  final int seed;

  static final _cache = <String, SceneAmbience>{};

  static Future<SceneAmbience?> of(ui.Image bg, String asset) async {
    final hit = _cache[asset];
    if (hit != null) return hit;
    const w = SceneArt.width;
    if (bg.width != w) return null;
    final data = await bg.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    int at(int x, int y, int c) => data.getUint8((y * w + x) * 4 + c);
    final seed = _seedOf(asset);
    final rnd = math.Random(seed);
    final windows = <Offset>[], stars = <Offset>[];
    for (var y = 2; y < 125; y++) {
      for (var x = 0; x < 230; x++) {
        final r = at(x, y, 0), g = at(x, y, 1), b = at(x, y, 2);
        if (x < 175 && r > 205 && g > 150 && b < 175 && r >= g && rnd.nextDouble() < 0.18) {
          windows.add(Offset(x.toDouble(), y.toDouble()));
        }
        // Night sky: dark blue, and the same all round (not a dark window).
        if (y < 60 && b > r && b < 110 && r + g < 110 && rnd.nextDouble() < 0.02) {
          var flat = true;
          for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final xx = x + dx, yy = y + dy;
            if (xx < 0 || yy < 0) continue;
            if ((at(xx, yy, 2) - b).abs() > 14 || (at(xx, yy, 0) - r).abs() > 14) flat = false;
          }
          if (flat) stars.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }
    windows.shuffle(rnd);
    stars.shuffle(rnd);
    return _cache[asset] = SceneAmbience._(stars.take(30).toList(), windows.take(70).toList(), seed);
  }

  /// The pictures were PNGs when each scene's stars, lit windows and birds
  /// were picked from its name; they are WebP now. Seeding with the old
  /// name keeps every scene's life exactly as it was.
  static int _seedOf(String asset) => asset.replaceFirst(RegExp(r'\.webp$'), '.png').hashCode;

  /// [tick] steps every 320 ms.
  void paint(Canvas canvas, DayPart part, int tick, {bool weathered = false}) {
    final p = Paint();
    if (part == DayPart.night) {
      if (!weathered) _stars(canvas, p, tick);
      _plane(canvas, p, tick);
    } else if (!weathered) {
      _birds(canvas, p, tick, dusk: part == DayPart.evening);
    }
    if (part != DayPart.day) _windows(canvas, p, tick);
  }

  /// A few birds crossing now and then, wings up and down.
  void _birds(Canvas canvas, Paint p, int tick, {bool dusk = false}) {
    const period = 150, flight = 70;
    final t = (tick + seed % period) % period;
    if (t >= flight) return;
    final f = t / flight;
    p.color = dusk ? const Color(0xCC40304A) : const Color(0xCC3A4050);
    for (var k = 0; k < 3; k++) {
      final x = -10 + f * 250 + k * 7;
      final y = 26 - f * 12 + (k == 1 ? -4 : 0) + math.sin(f * 9 + k) * 1.5;
      final up = (tick + k) % 2 == 0;
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), p);
      canvas.drawRect(Rect.fromLTWH(x - 1.5, y + (up ? -1 : 0.5), 1.5, 1), p);
      canvas.drawRect(Rect.fromLTWH(x + 1, y + (up ? -1 : 0.5), 1.5, 1), p);
    }
  }

  /// Stars twinkling in the dark sky.
  void _stars(Canvas canvas, Paint p, int tick) {
    for (var i = 0; i < stars.length; i++) {
      final tw = 0.5 + 0.5 * math.sin(tick * 0.35 + i * 1.7);
      p.color = Color.fromRGBO(255, 250, 225, 0.25 + 0.7 * tw);
      canvas.drawRect(Rect.fromLTWH(stars[i].dx, stars[i].dy, 1, 1), p);
    }
  }

  /// A plane's lights crossing high up, blinking.
  void _plane(Canvas canvas, Paint p, int tick) {
    const period = 260, flight = 160;
    final t = (tick + seed % period) % period;
    if (t >= flight) return;
    final f = t / flight;
    final x = 240 - f * 250, y = 10 + f * 5;
    p.color = const Color(0xE6FFFFFF);
    canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), p);
    if (tick % 3 == 0) {
      p.color = const Color(0xFFFF4A4A);
      canvas.drawRect(Rect.fromLTWH(x + 2, y, 1, 1), p);
    }
  }

  /// Windows going dark and coming back on, a few at a time.
  void _windows(Canvas canvas, Paint p, int tick) {
    for (var i = 0; i < windows.length; i++) {
      final slow = 18 + (i * 7) % 23;
      if (((tick + i * 13) ~/ slow) % 5 != 0) continue;
      p.color = const Color(0xB0302A40);
      canvas.drawRect(Rect.fromLTWH(windows[i].dx, windows[i].dy, 1, 1), p);
    }
  }
}

/// Decorations bought in MY: petals, fireflies, snow, autumn leaves, soap
/// bubbles, the garland.
extension _SceneEffects on _ScenePainter {
  /// Small drawn decorations: falling petals, fireflies, a fairy-light garland.
  void _effects(Canvas canvas, int f) {
    if (effects.isEmpty) return;
    final p = Paint();
    if (effects.contains('petals')) {
      p.color = const Color(0xE6FFC4D8);
      for (var i = 0; i < 46; i++) {
        final x = (i * 53 + f * 2 + (i % 5) * 7) % SceneArt.width;
        final y = (i * 37 + f * 3 + i * i) % SceneArt.height;
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 2, 1), p);
      }
    }
    if (effects.contains('fireflies')) {
      for (var i = 0; i < 16; i++) {
        if ((f + i * 3) % 7 > 3) continue;
        final x = 8 + (i * 29) % 150 + ((f + i) % 5) - 2;
        final y = 80 + (i * 17) % 80 + ((f ~/ 2 + i) % 3) - 1;
        p.color = const Color(0x55D8FF7A);
        canvas.drawRect(Rect.fromLTWH(x - 1.0, y - 1.0, 3, 3), p);
        p.color = const Color(0xFFF2FFB0);
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), p);
      }
    }
    if (effects.contains('snow')) {
      // Soft flakes drifting down, the near ones bigger; they sway a little.
      for (var i = 0; i < 120; i++) {
        final big = i % 3 == 0;
        final sway = ((f ~/ 2 + i) % 4) - 1.5;
        final x = (i * 61 + (i % 7) * 13 + sway) % SceneArt.width;
        final y = (i * 43 + f * (big ? 3 : 2) + i * i * 7) % SceneArt.height;
        p.color = big ? const Color(0xFFFFFFFF) : const Color(0xE0F0F4FF);
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), big ? 2 : 1, big ? 2 : 1), p);
      }
    }
    if (effects.contains('leaves')) {
      // Autumn leaves blown across: red, orange and gold, turning as they fall.
      const colors = [Color(0xF0D8402C), Color(0xF0EE8A2A), Color(0xF0F2C23C), Color(0xF0B8301E)];
      for (var i = 0; i < 48; i++) {
        final x = (i * 67 + f * 3 + (i % 4) * 9) % (SceneArt.width + 8) - 4;
        final y = (i * 41 + f * 2 + i * i * 3 + ((f + i) % 6 < 3 ? 1 : 0)) % SceneArt.height;
        final flat = (f + i) % 4 < 2;
        p.color = colors[i % colors.length];
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), flat ? 4 : 2, flat ? 2 : 4), p);
        // The leaf's point.
        canvas.drawRect(Rect.fromLTWH(x + (flat ? 4.0 : 0.0), y + (flat ? 0.0 : 4.0), 1, 1), p);
      }
    }
    if (effects.contains('bubbles')) {
      // Soap bubbles rising and drifting, a glint on each.
      final ring = Paint()..style = PaintingStyle.stroke;
      for (var i = 0; i < 22; i++) {
        final r = 2.0 + (i % 4);
        final life = (f * (1 + i % 3) + i * 37) % 230;
        final x = (30 + i * 71) % SceneArt.width + math.sin((f + i * 4) * 0.35) * 4;
        final y = 190.0 - life;
        // They pop near the top.
        if (y < 14 + (i % 5) * 9) continue;
        final c = Offset(x.roundToDouble(), y.roundToDouble());
        ring
          ..strokeWidth = 1
          ..color = const [Color(0xCCBFEFFF), Color(0xCCFFD0F0), Color(0xCCD8FFD8)][i % 3];
        canvas.drawCircle(c, r, ring);
        p.color = const Color(0x30FFFFFF);
        canvas.drawCircle(c, r, p);
        p.color = const Color(0xF0FFFFFF);
        canvas.drawRect(Rect.fromLTWH(c.dx - r * 0.5, c.dy - r * 0.6, 1, 1), p);
      }
    }
    if (effects.contains('garland')) {
      // The roof it hangs from is lower in some pictures.
      canvas.save();
      canvas.translate(0, decorShift.toDouble());
      _garland(canvas, f);
      canvas.restore();
    }
  }

  /// Warm festoon lights hanging in swags between the platform pillars,
  /// smaller and closer together towards the far end (the same roof in
  /// every scene). They glow at dusk and at night and twinkle slowly.
  void _garland(Canvas canvas, int f) {
    // Hanging line: from near the vanishing point to the top right, through the pillars.
    double lineY(double x) => 93 - 0.404 * (x - 228);
    const pillars = <double>[384, 358, 311, 290, 278, 268, 261];
    final glow = switch (part) {
      DayPart.day => 0.0,
      DayPart.evening => 0.7,
      DayPart.night => 1.0,
    };
    final wire = Paint()
      ..color = const Color(0xB0302838)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    var n = 0;
    for (var k = 0; k + 1 < pillars.length; k++) {
      final x1 = pillars[k], x2 = pillars[k + 1];
      final span = x1 - x2;
      final sag = span * 0.2;
      Offset at(double t) {
        final x = x1 - span * t;
        return Offset(x, lineY(x) + sag * 4 * t * (1 - t));
      }

      final path = Path()..moveTo(x1, lineY(x1));
      for (var i = 1; i <= 12; i++) {
        final q = at(i / 12);
        path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(path, wire);
      // Bulbs: nearer ones bigger and further apart.
      final depth = ((x1 - 240) / 144).clamp(0.25, 1.0);
      final count = math.max(3, (span / (6 * depth)).round());
      for (var i = 1; i < count; i++) {
        final q = at(i / count);
        n++;
        final tw = 0.72 + 0.28 * math.sin((f + n * 5) * 0.45);
        final r = 0.9 + 0.9 * depth;
        final color = n % 5 == 0 ? const Color(0xFFFFE6A8) : const Color(0xFFFFC870);
        if (glow > 0) {
          canvas.drawCircle(
            q,
            r * 5,
            Paint()
              ..shader = ui.Gradient.radial(q, r * 5, [
                color.withValues(alpha: 0.55 * glow * tw),
                color.withValues(alpha: 0),
              ]),
          );
        }
        canvas.drawRect(
          Rect.fromCenter(center: q, width: r * 1.6, height: r * 1.6),
          Paint()..color = Color.lerp(const Color(0xFF8A7050), color, 0.55 + 0.45 * math.max(glow, 0.4) * tw)!,
        );
      }
    }
  }
}
