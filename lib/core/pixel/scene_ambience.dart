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
/// bubbles, confetti, dandelion fluff, paper planes, shooting stars,
/// dragonflies, butterflies, sky lanterns, the garland.
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
    if (effects.contains('confetti')) {
      // Paper confetti tumbling down, each piece turning.
      const colors = [Color(0xF0FF6B8B), Color(0xF0FFD54A), Color(0xF05BC8F5), Color(0xF07BDC8A), Color(0xF0FFFFFF)];
      for (var i = 0; i < 64; i++) {
        final x = (i * 59 + (i % 6) * 11 + ((f + i) % 4) - 1) % SceneArt.width;
        final y = (i * 31 + f * (2 + i % 3) + i * i * 5) % SceneArt.height;
        final flat = (f + i) % 3 == 0;
        p.color = colors[i % colors.length];
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), flat ? 4 : 2, flat ? 2 : 3), p);
      }
    }
    if (effects.contains('dandelion')) {
      // Dandelion fluff carried up and along on the breeze.
      for (var i = 0; i < 40; i++) {
        final x = (i * 73 + f * 2 + (i % 5) * 9) % (SceneArt.width + 10) - 5.0;
        final rise = (i * 47 + f + i * i * 3) % SceneArt.height;
        final y = (SceneArt.height - 1 - rise + math.sin((f + i * 5) * 0.4) * 2).roundToDouble();
        p.color = const Color(0xF0FFFFFF);
        canvas.drawRect(Rect.fromLTWH(x - 2, y, 5, 1), p);
        canvas.drawRect(Rect.fromLTWH(x - 1, y - 1, 3, 1), p);
        p.color = const Color(0xC0C8B890);
        canvas.drawRect(Rect.fromLTWH(x, y + 1, 1, 2), p);
      }
    }
    if (effects.contains('planes')) {
      // Paper planes gliding across, dipping and lifting.
      for (var i = 0; i < 5; i++) {
        const period = 150;
        final t = (f * (2 + i % 2) + i * 67) % period;
        final c = Offset(
          (-12.0 + t * (SceneArt.width + 24) / period).roundToDouble(),
          (18.0 + i * 13 + math.sin(t * 0.14 + i) * 6).roundToDouble(),
        );
        p.color = const Color(0xFFFFFFFF);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx + 9, c.dy)
            ..lineTo(c.dx - 8, c.dy - 5)
            ..lineTo(c.dx - 3, c.dy)
            ..close(),
          p,
        );
        p.color = const Color(0xFFC2CEE6);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx + 9, c.dy)
            ..lineTo(c.dx - 8, c.dy + 3)
            ..lineTo(c.dx - 3, c.dy)
            ..close(),
          p,
        );
      }
    }
    if (effects.contains('meteors') && !underground) {
      // A shower of shooting stars across the sky; faint by day.
      final strength = switch (part) {
        DayPart.day => 0.4,
        DayPart.evening => 0.8,
        DayPart.night => 1.0,
      };
      for (var i = 0; i < 11; i++) {
        final period = 22 + i * 4;
        final t = (f + i * 11) % period;
        if (t > 7) continue;
        final round = (f + i * 11) ~/ period;
        final head = Offset(40.0 + (i * 97 + round * 53) % 220 - t * 7, 4.0 + (i * 13) % 34 + t * 3.2);
        for (var k = 0; k < 12; k++) {
          p.color = Color.fromRGBO(255, 250, 220, strength * (1 - k / 12));
          final s = k == 0 ? 2.0 : 1.0;
          canvas.drawRect(Rect.fromLTWH((head.dx + k * 2.2).roundToDouble(), (head.dy - k).roundToDouble(), s, s), p);
        }
      }
    }
    if (effects.contains('dragonflies')) {
      // Red dragonflies: they hover, then dart to another spot.
      for (var i = 0; i < 9; i++) {
        final hop = (f + i * 5) ~/ 9;
        final x = 10.0 + (i * 83 + hop * 57) % 230 + ((f + i) % 3) - 1;
        final y = 40.0 + (i * 29 + hop * 31) % 90 + ((f ~/ 2 + i) % 2);
        p.color = Color(f.isEven ? 0xB0FFFFFF : 0x70FFFFFF);
        canvas.drawRect(Rect.fromLTWH(x + 3, y - 3, 4, 3), p);
        canvas.drawRect(Rect.fromLTWH(x + 3, y + 2, 4, 2), p);
        p.color = const Color(0xFFD8432C);
        canvas.drawRect(Rect.fromLTWH(x, y, 8, 2), p);
        p.color = const Color(0xFF7A1E14);
        canvas.drawRect(Rect.fromLTWH(x + 8, y, 2, 2), p);
      }
    }
    if (effects.contains('butterflies')) {
      // Butterflies wandering by, wings opening and closing.
      const colors = [Color(0xFFFFF0A0), Color(0xFFFFFFFF), Color(0xFFB9D8FF), Color(0xFFFFC2DA)];
      for (var i = 0; i < 10; i++) {
        final sway = (math.sin((f + i * 3) * 0.5) * 5).round();
        final x = (i * 71 + f * 2 + sway) % (SceneArt.width + 8) - 4.0;
        final y = (50.0 + (i * 37) % 110 + math.sin((f + i * 7) * 0.33) * 7).roundToDouble();
        p.color = colors[i % colors.length];
        if ((f + i).isEven) {
          canvas.drawRect(Rect.fromLTWH(x - 4, y - 3, 4, 3), p);
          canvas.drawRect(Rect.fromLTWH(x + 1, y - 3, 4, 3), p);
          canvas.drawRect(Rect.fromLTWH(x - 3, y, 3, 2), p);
          canvas.drawRect(Rect.fromLTWH(x + 1, y, 3, 2), p);
        } else {
          canvas.drawRect(Rect.fromLTWH(x - 2, y - 4, 2, 6), p);
          canvas.drawRect(Rect.fromLTWH(x + 1, y - 4, 2, 6), p);
        }
        p.color = const Color(0xFF4A3A30);
        canvas.drawRect(Rect.fromLTWH(x, y - 2, 1, 4), p);
      }
    }
    if (effects.contains('skylanterns')) {
      // Paper lanterns let go into the sky, glowing at dusk and at night.
      final glow = switch (part) {
        DayPart.day => 0.0,
        DayPart.evening => 0.6,
        DayPart.night => 1.0,
      };
      for (var i = 0; i < 14; i++) {
        final life = (f * (1 + i % 2) + i * 41) % 260;
        final big = i % 3 == 0;
        final c = Offset(
          ((20 + i * 67) % SceneArt.width + math.sin((f + i * 4) * 0.2) * 3).roundToDouble(),
          (196.0 - life * 0.85).roundToDouble(),
        );
        if (c.dy < -6) continue;
        final w = big ? 7.0 : 5.0, h = big ? 9.0 : 6.0;
        if (glow > 0) {
          canvas.drawCircle(
            c,
            w * 2.4,
            Paint()
              ..shader = ui.Gradient.radial(c, w * 2.4, [
                const Color(0xFFFFB45A).withValues(alpha: 0.45 * glow),
                const Color(0x00FFB45A),
              ]),
          );
        }
        p.color = const Color(0xFFFF9A48);
        canvas.drawRect(Rect.fromCenter(center: c, width: w, height: h), p);
        p.color = const Color(0xFFFFE2A0);
        canvas.drawRect(Rect.fromCenter(center: c.translate(0, 1), width: w - 2, height: h - 2), p);
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
