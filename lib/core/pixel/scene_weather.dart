part of 'pixel_scene.dart';

/// Weather drawn over the picture: the grey veil and the train's wind.
extension _SceneWeather on _ScenePainter {
  /// The wind of the arriving train: leaves (or snow, or spray in the rain)
  /// blow from the track over the platform.
  void _wind(Canvas canvas) {
    final a = arrive?.value ?? 1;
    if (_gust(a) <= 0) return;
    final snow = sky == 'snow' || weather == WeatherKind.snow;
    final rain = sky == 'rain' || weather == WeatherKind.rain;
    final colors = snow
        ? const [Color(0xF2FFFFFF), Color(0xCCE6ECF8)]
        : rain
        ? const [Color(0x99C8D8EE), Color(0x77A8B8D0)]
        : const [Color(0xFF6E8F3A), Color(0xFFA0702E), Color(0xFF8DA84A), Color(0xFFC49A4A)];
    final p = Paint();
    for (var i = 0; i < 26; i++) {
      // Each one lifts off a little after the one before, from the track
      // beside the train, and blows out over the platform.
      final t = ((a - 0.58 - i * 0.008) / 0.32).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final ease = 1 - (1 - t) * (1 - t);
      final x = 228 + (i * 7) % 30 + ease * (70 + (i * 13) % 80);
      final y = 150 - (i * 5) % 34 - ease * (14 + (i * 3) % 22) + math.sin(t * 9 + i) * 3;
      final c = colors[i % colors.length];
      p.color = c.withValues(alpha: c.a * (1 - t * t * t));
      // Leaves flutter: lying flat, then on their side.
      final flat = ((t * 10 + i) % 2) < 1;
      final big = i % 3 == 0 ? 1.0 : 0.0;
      canvas.drawRect(Rect.fromLTWH(x, y, (flat || snow || rain ? 3 : 1) + big, (flat ? 1 : 3) + (snow ? 1 : 0)), p);
    }
  }

  /// Grey veil on cloudy, rainy and snowy days.
  void _weather(Canvas canvas) {
    final veil = switch (weather) {
      WeatherKind.cloudy => const Color(0x2E7A7F8C),
      WeatherKind.rain => const Color(0x40535A6B),
      WeatherKind.snow => const Color(0x26D0D6E2),
      WeatherKind.sunny || WeatherKind.unknown => null,
    };
    if (veil == null) return;
    canvas.drawRect(Rect.fromLTWH(0, 0, SceneArt.width.toDouble(), SceneArt.height.toDouble()), Paint()..color = veil);
  }
}

/// Falling rain or snow. The particles are drawn once into a tile image;
/// each frame only moves that tile (4 image draws), which keeps the
/// animation cheap on any phone.
class _FallPainter extends CustomPainter {
  _FallPainter({required this.view, required this.weather, required this.frame, this.arrive})
    : super(repaint: arrive == null ? frame : Listenable.merge([frame, arrive]));

  /// The arriving train's wind pushes the rain or snow aside.
  final Animation<double>? arrive;

  final SceneView view;
  final WeatherKind weather;
  final ValueNotifier<int> frame;

  static final _tiles = <WeatherKind, ui.Image>{};

  static ui.Image _tile(WeatherKind weather) => _tiles[weather] ??= () {
    const w = SceneArt.width, h = SceneArt.height;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final rain = weather == WeatherKind.rain;
    final p = Paint()..color = rain ? const Color(0x99C8D8EE) : const Color(0xE6FFFFFF);
    final (stepY, stepX, len) = rain ? (9, 11, 3.0) : (8, 10, 1.0);
    for (var y = 0; y < h; y += stepY) {
      for (var x = (y * (rain ? 5 : 3)) % stepX; x < w; x += stepX) {
        c.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, len), p);
      }
    }
    return recorder.endRecording().toImageSync(w, h);
  }();

  @override
  void paint(Canvas canvas, Size size) {
    const w = SceneArt.width, h = SceneArt.height;
    final f = frame.value;
    final rain = weather == WeatherKind.rain;
    // Rain falls fast and slants; snow drifts down and sways a little.
    final dy = (rain ? f * 3 : f) % h;
    final push = (_gust(arrive?.value ?? 1) * (rain ? 9 : 14)).round();
    final dx = ((rain ? -f : ((f ~/ 4) % 3) - 1) + push) % w;
    final tile = _tile(weather);
    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.save();
    canvas.scale(view.scale);
    canvas.translate(-view.src.left, -view.src.top);
    canvas.clipRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    for (final ox in [dx - w, dx]) {
      for (final oy in [dy - h, dy]) {
        canvas.drawImage(tile, Offset(ox.toDouble(), oy.toDouble()), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FallPainter old) =>
      old.weather != weather || old.view.src != view.src || old.view.scale != view.scale;
}
