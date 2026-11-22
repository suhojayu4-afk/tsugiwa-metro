part of 'pixel_scene.dart';

/// The train on its track: where it is now, its light and its headlights.
extension _SceneTrain on _ScenePainter {
  /// The train under the same sky as the picture: darker and cooler under
  /// rain clouds, a little cooler in the snow.
  Paint _trainPaint(Paint art) => switch (underground ? null : sky) {
    'rain' =>
      Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = const ColorFilter.mode(Color(0xFFADB5C6), BlendMode.modulate),
    'umbrella' || 'snowsoon' =>
      Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = const ColorFilter.mode(Color(0xFFC3C8D4), BlendMode.modulate),
    'snow' =>
      Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = const ColorFilter.mode(Color(0xFFE4E8F0), BlendMode.modulate),
    _ => art,
  };

  /// Where the train is drawn now: it comes up the line, growing as it
  /// nears, rocking a little on the rails and dipping on its springs when it
  /// stops.
  Rect get _trainNow {
    final a = arrive?.value ?? 1;
    final d = depart?.value ?? 0;
    if (a >= 1 && d > 0) {
      // Pulling out: it speeds up down the line and gets smaller, its red
      // tail lights fading into the distance.
      final scale = _trainScale;
      final z = 1 / scale;
      final roll = math.sin(z * 2.2) * 0.45 + math.sin(z * 5.3) * 0.15;
      return SceneArt.trainAt(scale, vanishing).shift(Offset(roll * scale, 0));
    }
    if (a >= 1) return SceneArt.trainRect;
    final scale = _trainScale;
    final r = SceneArt.trainAt(scale, vanishing);
    if (_travel(a) < 1) {
      // Distance down the line (1 = at the platform). Rail joints come by
      // at a fixed spacing, so the clicks slow down as the train brakes.
      final z = 1 / scale;
      final joint = (z * 2.4) % 1;
      final bump = joint < 0.14 ? math.sin(joint / 0.14 * math.pi) : 0.0;
      final roll = math.sin(z * 2.2) * 0.45 + math.sin(z * 5.3) * 0.15;
      return r.shift(Offset(roll * scale, bump * 0.7 * scale));
    }
    // Stopped: the nose dips on the brakes, then springs back and settles.
    final q = (a - _travelEnd) / (1 - _travelEnd);
    final dip = 1.3 * math.exp(-4.5 * q) * math.sin(q * math.pi * 2.6);
    return r.shift(Offset(0, dip));
  }

  /// The train's size now (1 = at the platform). It runs down the line at
  /// a steady braking: its distance shrinks like (1 - t)², and things look
  /// 1/distance big, so it stays small far away, then grows quickly and
  /// eases to a stop at the platform.
  double get _trainScale {
    final d = depart?.value ?? 0;
    if (d > 0) {
      // Leaving: it starts off slowly and speeds up (distance grows like d³).
      const far = 1 / SceneArt.trainFarScale;
      return 1 / (1 + (far - 1) * d * d * d);
    }
    final a = _travel(arrive?.value ?? 1);
    if (a >= 1) return 1;
    const far = 1 / SceneArt.trainFarScale;
    final distance = 1 + (far - 1) * (1 - a) * (1 - a);
    return 1 / distance;
  }

  /// Draws [draw] (made for the train at its stop) where the train is now.
  void _atTrain(Canvas canvas, void Function() draw) {
    final r = _trainNow;
    if (r == SceneArt.trainRect) return draw();
    // Far down the line it comes out of the haze.
    final fade = ((_trainScale - SceneArt.trainFarScale) / 0.08).clamp(0.0, 1.0);
    if (fade < 1) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, fade));
    }
    canvas.save();
    canvas.translate(r.left, r.top);
    canvas.scale(r.width / SceneArt.trainRect.width, r.height / SceneArt.trainRect.height);
    canvas.translate(-SceneArt.trainRect.left, -SceneArt.trainRect.top);
    draw();
    canvas.restore();
    if (fade < 1) canvas.restore();
  }

  /// The two headlights: seen first as two bright points far down the line,
  /// growing as the train nears; brighter at dusk, at night and in the
  /// rain, when they also light up the rails in front of the train.
  void _headlights(Canvas canvas) {
    final wet =
        underground ||
        sky == 'rain' ||
        sky == 'umbrella' ||
        sky == 'snow' ||
        sky == 'snowsoon' ||
        weather == WeatherKind.rain ||
        weather == WeatherKind.snow;
    final strength = switch (part) {
      // In the tunnel the lamps show as they do at night.
      DayPart.day when underground => 1.0,
      DayPart.day => wet ? 0.6 : 0.4,
      DayPart.evening => 0.85,
      DayPart.night => 1.0,
    };
    final r = _trainNow;
    final s = r.width / SceneArt.trainWidth;
    // Leaving: what we see now is the back of the train, with red tail lights.
    final leaving = (depart?.value ?? 0) > 0;
    final warm = leaving ? const Color(0xFFFF5A4A) : const Color(0xFFFFF2C8);
    // Headlight centres in the train picture (75×96).
    for (final lamp in lamps) {
      final c = Offset(
        r.left + lamp.dx / SceneArt.trainWidth * r.width,
        r.top + lamp.dy / SceneArt.trainHeight * r.height,
      );
      // The halo stays a few pixels wide far away, so the lights read first.
      final halo = math.max(3.0, 9 * s);
      canvas.drawCircle(
        c,
        halo,
        Paint()
          ..shader = ui.Gradient.radial(c, halo, [warm.withValues(alpha: 0.55 * strength), warm.withValues(alpha: 0)]),
      );
      final core = math.max(0.7, 2.2 * s);
      canvas.drawRect(Rect.fromCenter(center: c, width: core * 2, height: core * 1.6), Paint()..color = warm);
    }
    // Light on the rails in front of the train.
    if ((part != DayPart.day || wet) && !leaving) {
      final foot = Offset(r.center.dx, r.bottom + 5 * s);
      final w = 46 * s, h = 12 * s;
      canvas.drawOval(
        Rect.fromCenter(center: foot, width: w, height: h),
        Paint()
          ..shader = ui.Gradient.radial(foot, w / 2, [
            warm.withValues(alpha: 0.28 * strength),
            warm.withValues(alpha: 0),
          ]),
      );
    }
  }
}
