part of 'pixel_scene.dart';

/// After the stop, the two passengers waiting at the door get on
/// (see _ScenePainter._passengers).
const _platformMs = 3600;

/// The first door, just behind the driver's cab, and the two places in the
/// queue in front of it (feet, in the
/// station pictures where the floor's horizon is at row 92; other pictures
/// shift with their horizon). In Japan people queue at the door marks, so
/// the second one stands beside the first, a step further from the edge.
const _door = Offset(254, 118), _queue1 = Offset(268, 121), _queue2 = Offset(281, 121.5);

/// A step inside the car: whoever gets on walks on to here, going behind
/// the car's side as they pass the doorway.
const _inside = Offset(238, 116.5);

/// The passengers waiting at the door who get on.
extension _ScenePassengers on _ScenePainter {
  /// Two passengers wait in the queue at the train door while it pulls in
  /// (they come into view with it), then get on: the first walks the few
  /// steps into the door, the second moves up and follows. The door's warm
  /// light spills onto the floor while it is open. Sizes follow the
  /// platform's perspective (measured on the station pictures: height =
  /// 1.33 × (feet row − horizon)).
  void _passengers(Canvas canvas) {
    if (walkers.isEmpty || closed) return;
    final a = arrive?.value ?? 1;
    final t = platform?.value ?? 0;
    final arriving = a < 1;
    final boarding = t > 0 && t < 1;
    if (!arriving && !boarding) return;
    final sec = t * _platformMs / 1000;
    // The floor's horizon in this picture: 92 where the rails meet at 89.4.
    final horizon = vanishing.dy + 2.6;
    final dz = horizon - 92;
    Offset at(Offset p) => Offset(p.dx, p.dy + dz);
    final light = switch (part) {
      DayPart.day => null,
      DayPart.evening => const Color(0xFFF0DCD8),
      DayPart.night => const Color(0xFF8E96B8),
    };
    final wet = sky == 'rain' || weather == WeatherKind.rain;
    final tint = wet ? Color.lerp(light ?? const Color(0xFFFFFFFF), const Color(0xFFADB5C6), 0.6) : light;

    // The open door's light on the floor.
    if (boarding) {
      final open = math.min(1.0, math.min(t / 0.08, (1 - t) / 0.12));
      final d = at(_door);
      final glow = (part == DayPart.day ? 0.22 : 0.4) * open;
      final w = 1.33 * (d.dy - horizon) * 1.1;
      canvas.drawOval(
        Rect.fromCenter(center: d + const Offset(4, 1), width: w, height: w * 0.32),
        Paint()
          ..shader = ui.Gradient.radial(d + const Offset(4, 1), w / 2, [
            const Color(0xFFFFF0C8).withValues(alpha: glow),
            const Color(0x00FFF0C8),
          ]),
      );
    }

    // Where each one is now, how much of it shows, and whether it walks.
    ({Offset foot, double alpha, bool walking}) where(int who) {
      // While the train pulls in: standing in the queue, fading in with it.
      final show = arriving ? (a / 0.15).clamp(0.0, 1.0) : 1.0;
      Offset lerp(Offset p, Offset q, double u) => Offset.lerp(at(p), at(q), u)!;
      // Getting on: up to the doorway (slowing a little for the step), then
      // on into the car, where the car's side hides them bit by bit.
      ({Offset foot, double alpha, bool walking}) board(double u) {
        if (u < 0.55) {
          final e = u / 0.55;
          return (foot: lerp(_queue1, _door, e * (2 - e)), alpha: 1, walking: true);
        }
        return (foot: lerp(_door, _inside, (u - 0.55) / 0.45), alpha: u > 0.97 ? 0 : 1, walking: true);
      }

      if (who == 0) {
        final u = ((sec - 0.5) / 1.3).clamp(0.0, 1.0);
        if (!boarding || u <= 0) return (foot: at(_queue1), alpha: show, walking: false);
        return board(u);
      }
      final up = ((sec - 0.9) / 0.6).clamp(0.0, 1.0);
      final inn = ((sec - 1.9) / 1.3).clamp(0.0, 1.0);
      if (!boarding || up <= 0) return (foot: at(_queue2), alpha: show, walking: false);
      if (inn <= 0) return (foot: lerp(_queue2, _queue1, up), alpha: 1, walking: up < 1);
      return board(inn);
    }

    // The car's side runs from the train's front right edge to where the
    // rails meet: at a person's depth, everything left of it is inside.
    const tr = SceneArt.trainRect;
    double sideX(double foot) => tr.right + (foot - tr.bottom) * (tr.right - vanishing.dx) / (tr.bottom - vanishing.dy);

    // The one further back first, so the nearer one is drawn over it.
    for (final who in const [1, 0]) {
      if (who >= walkers.length) continue;
      final w = walkers[who];
      final p = where(who);
      if (p.alpha <= 0) continue;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(sideX(p.foot.dy), 0, SceneArt.width.toDouble(), SceneArt.height.toDouble()));
      final h = 1.33 * (p.foot.dy - horizon);
      final img = w.away;
      final fw = img.width / w.frames;
      // Frame 0 stands; the walk loops over the others (the 6-frame strips
      // have no standing frame: they stand on their first step).
      final walk = w.frames == 7 ? 6 : w.frames;
      final frame = p.walking ? (w.frames - walk) + ((sec * 8).floor() + who * 3) % walk : 0;
      final scale = h / img.height;
      final paint = Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(0, 0, 0, p.alpha);
      if (tint != null) paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
      canvas.drawOval(
        Rect.fromCenter(center: p.foot, width: fw * scale * 0.75, height: math.max(1.5, h * 0.07)),
        Paint()..color = Color.fromRGBO(20, 16, 24, 0.28 * p.alpha),
      );
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(frame * fw, 0, fw, img.height.toDouble()),
        Rect.fromLTWH(p.foot.dx - fw * scale / 2, p.foot.dy - h, fw * scale, h),
        paint,
      );
      canvas.restore();
    }
  }
}
