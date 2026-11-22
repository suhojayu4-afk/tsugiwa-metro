part of 'pixel_scene.dart';

/// The train's arrival over the banner's arrival animation (0 … 1): it
/// runs down the line until [_travelEnd], then settles on its springs.
const _travelEnd = 0.86;

/// How far along the line the train is (0 far away … 1 stopped).
double _travel(double a) => (a / _travelEnd).clamp(0.0, 1.0);

/// The wind the train pushes ahead of it (0 … 1): it builds as the train
/// gets close and dies down soon after it stops.
double _gust(double a) {
  double smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  return smooth(0.5, 0.82, a) * (1 - smooth(0.9, 1.0, a));
}

/// At night the stripe is in shadow like the rest of the train.
Color stripeColor(Color color, DayPart part) =>
    part == DayPart.night ? Color.lerp(color, const Color(0xFF1A2050), 0.3)! : color;

/// The whole scene (384×192 art pixels, each [scale]×[scale]) as one still
/// image, for the home screen widget and share cards. [arrive] (0 … 1)
/// draws the train part way through its arrival (review renders).
Future<ui.Image> renderSceneImage({
  required SceneLook look,
  required DayPart part,
  required Color lineColor,
  WeatherKind weather = WeatherKind.sunny,
  int scale = 2,
  String? sky,
  double? arrive,
  double? platform,
  double? depart,
  double? gather,
  int tick = 0,
  SceneEventDirector? events,
}) async {
  final art = await loadSceneArt(look, part, sky: sky);
  await events?.prepare(art.bg);
  final view = SceneView(scale.toDouble(), Rect.fromLTWH(0, 0, SceneArt.width.toDouble(), SceneArt.height.toDouble()));
  final life = ValueNotifier<int>(tick);
  final recorder = ui.PictureRecorder();
  final size = Size(SceneArt.width * scale.toDouble(), SceneArt.height * scale.toDouble());
  _ScenePainter(
    view: view,
    bg: art.bg,
    trainBase: art.base,
    trainStripe: art.stripe,
    lamps: SceneArt.lampsOf(look.trainArt),
    hasLed: SceneArt.hasLed(look.trainArt),
    lineColor: stripeColor(look.trainColor ?? lineColor, art.part),
    weather: weather,
    life: life,
    graded: art.graded,
    overlays: art.overlays,
    mark: art.mark,
    markAt: SceneArt.markOf(look.trainArt),
    skies: art.skies,
    weathered: art.weathered,
    sky: art.sky,
    closed: art.closed,
    trainWeather: art.trainWeather,
    trainWeatherTint: art.trainWeatherTint,
    part: art.part,
    vanishing: art.vanishing,
    front: art.front,
    decorShift: art.decorShift,
    overlayLights: art.overlayLights,
    ambience: art.ambience,
    // Review renders: the train part way through its arrival.
    arrive: arrive == null ? null : AlwaysStoppedAnimation(arrive),
    platform: platform == null ? null : AlwaysStoppedAnimation(platform),
    depart: depart == null ? null : AlwaysStoppedAnimation(depart),
    gather: gather == null ? null : AlwaysStoppedAnimation(gather),
    underground: art.underground,
    walkIn: art.walkIn,
    walkers: art.walkers,
    effects: look.effects,
    led: look.led,
    ledColors: look.ledColors,
    sign: look.sign,
    events: events,
  ).paint(Canvas(recorder), size);
  life.dispose();
  return recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
}

/// Which part of the picture is visible and how big one art pixel is.
/// Every art pixel becomes a whole number of device pixels, so the pixel art
/// stays perfectly crisp; the sides are cropped to fit.
class SceneView {
  SceneView(this.scale, this.src);

  /// Logical pixels per art pixel.
  final double scale;
  final Rect src;

  double get logicalHeight => src.height * scale;

  static SceneView fit(double logicalWidth, double dpr, {double aspect = 2.0}) {
    final device = logicalWidth * dpr;
    final perArt = (device / SceneArt.width).ceil().clamp(1, 64);
    final scale = perArt / dpr;
    final cols = (logicalWidth / scale).clamp(1.0, SceneArt.width.toDouble());
    final rows = (cols / aspect).clamp(1.0, SceneArt.height.toDouble());
    final left = (SceneArt.focusX - cols / 2).clamp(0.0, SceneArt.width - cols);
    final top = (SceneArt.height - rows) / 2;
    return SceneView(scale, Rect.fromLTWH(left, top, cols, rows));
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.view,
    required this.bg,
    required this.trainBase,
    required this.trainStripe,
    this.lamps = SceneArt.lampsDefault,
    required this.lineColor,
    required this.weather,
    required this.life,
    this.arrive,
    this.platform,
    this.depart,
    this.gather,
    this.underground = false,
    this.walkIn = true,
    this.walkers = const [],
    this.weathered = false,
    this.sky,
    this.closed = false,
    this.trainWeather,
    this.trainWeatherTint = const Color(0xFFFFFFFF),
    this.graded,
    this.overlays = const [],
    this.mark,
    this.markAt = SceneArt.markDefault,
    this.skies = const [],
    this.effects = const {},
    this.led = const [],
    this.ledColors = const [ledOrange],
    this.sign,
    this.part = DayPart.day,
    this.vanishing = SceneArt.vanishing,
    this.front,
    this.decorShift = 0,
    this.overlayLights = const [],
    this.ambience,
    this.events,
    this.hasLed = true,
  }) : super(repaint: Listenable.merge([life, ?arrive, ?platform, ?depart, ?gather, ?events]));

  /// Easter-egg events (scene_events.dart), or null.
  final SceneEventDirector? events;

  /// The train has a destination LED (a steam locomotive has none).
  final bool hasLed;

  final StationSign? sign;

  /// Time of day of the picture: how bright the headlights look.
  final DayPart part;

  /// Where the picture's rails meet: the arriving train comes from there.
  final Offset vanishing;

  /// People standing where the platform decorations go (alpha mask, one
  /// per animation frame of the picture, stacked), or null.
  final ui.Image? front;

  /// Rows the decorations are moved down: this picture's platform is that
  /// much lower than the built-in scene's.
  final int decorShift;

  /// Per overlay: its lights for dusk and night, or null.
  final List<ui.Image?> overlayLights;

  /// Sky and window lights of the picture (clouds, birds, stars, windows).
  final SceneAmbience? ambience;

  /// Train arrival, 0 far away … 1 at the platform (null = always arrived).
  final Animation<double>? arrive;

  /// Leaving after the stop (0 … 1 = gone); null = it stays.
  final Animation<double>? depart;

  /// The next passengers walk in along the platform to the door's queue
  /// (0 … 1 over [_gatherMs]); null = they stand there already.
  final Animation<double>? gather;

  /// The next passengers can walk in along the platform (see [gather]);
  /// false = it is full of people: they come into view in the queue.
  final bool walkIn;

  /// The subway platform: no sky and no weather, lit like a station at
  /// midday with the lamps on as at night.
  final bool underground;

  /// The train has left and the track is empty.
  bool get _gone => (depart?.value ?? 0) >= 1;

  /// After the stop: the passengers at the door get on (0 … 1 over [_platformMs]).
  final Animation<double>? platform;
  final List<Walker> walkers;

  /// The picture is already a rainy / snowy version: do not grey it again.
  final bool weathered;

  /// Which weather picture is shown; the train is matched to it.
  final String? sky;
  final ui.Image? trainWeather;

  /// After the last train: the train's display says 「運行終了」.
  final bool closed;
  final Color trainWeatherTint;

  final List<String> led;
  final List<Color> ledColors;

  /// Set when the picture is another time of day's, to be colour-graded.
  final DayPart? graded;
  final List<ui.Image> overlays;

  /// The head mark on the train's face (its centre in the train picture: [markAt]).
  final ui.Image? mark;
  final Offset markAt;

  /// Things floating in the sky: the near one, then the far one.
  final List<ui.Image> skies;
  final Set<String> effects;

  final SceneView view;
  final ValueNotifier<int> life;

  /// Animation sheet (or one still frame).
  final ui.Image bg;
  final ui.Image trainBase;
  final ui.Image trainStripe;

  /// Headlight centres in the train picture.
  final List<Offset> lamps;
  final Color lineColor;
  final WeatherKind weather;

  @override
  void paint(Canvas canvas, Size size) {
    final crisp = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    canvas.save();
    canvas.scale(view.scale);
    canvas.translate(-view.src.left, -view.src.top);

    // Grey days: take most of the colour out of the picture and the train
    // (blue sky → overcast); the stripe keeps its line colour.
    final overcast =
        !underground &&
        !(weathered && SceneArt.wetSkies.contains(sky)) &&
        (weather == WeatherKind.cloudy || weather == WeatherKind.rain || weather == WeatherKind.snow);
    final art = overcast
        ? (Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = _desaturate(0.6))
        : crisp;
    final bgPaint = graded == null
        ? art
        : (Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = _grade(graded!));
    final frames = (bg.height ~/ SceneArt.height).clamp(1, 64);
    final f = life.value % frames;
    canvas.drawImageRect(
      bg,
      Rect.fromLTWH(0, f * SceneArt.height.toDouble(), SceneArt.width.toDouble(), SceneArt.height.toDouble()),
      Rect.fromLTWH(0, 0, SceneArt.width.toDouble(), SceneArt.height.toDouble()),
      bgPaint,
    );
    ambience?.paint(canvas, part, life.value, weathered: weathered);
    // Easter eggs in the sky (shooting star, rainbow, airship), behind the train.
    if (!underground) events?.paintSky(canvas, bg: bg, part: part);
    _skyThings(canvas);
    final trainSrc = Rect.fromLTWH(0, 0, trainBase.width.toDouble(), trainBase.height.toDouble());
    if (!_gone) {
      _atTrain(canvas, () {
        // Contact shadow on the rails under the train, so it sits on the track
        // instead of floating (the art's bottom edge is at train row 95).
        const l = SceneArt.trainLeft, t = SceneArt.trainTop;
        canvas.drawOval(Rect.fromLTWH(l + 1, t + 91, 69, 16), Paint()..color = const Color(0x55141018));
        canvas.drawOval(Rect.fromLTWH(l + 8, t + 93, 55, 10), Paint()..color = const Color(0x77141018));
        canvas.drawRect(Rect.fromLTWH(l + 12, t + 95, 47, 4), Paint()..color = const Color(0x99100c14));
        final trainPaint = _trainPaint(art);
        // Wet platform: the train shows faintly in the water on the track.
        if (sky == 'rain') {
          const r = SceneArt.trainRect;
          canvas.save();
          canvas.clipRect(Rect.fromLTWH(r.left, r.bottom - 1, r.width, 16));
          canvas.translate(0, r.bottom * 2 - 2);
          canvas.scale(1, -1);
          canvas.drawImageRect(
            trainBase,
            trainSrc,
            r,
            Paint()
              ..filterQuality = FilterQuality.none
              ..colorFilter = const ColorFilter.mode(Color(0x30C0C8DC), BlendMode.modulate),
          );
          canvas.restore();
        }
        canvas.drawImageRect(trainBase, trainSrc, SceneArt.trainRect, trainPaint);
        final stripe = sky == 'rain' || sky == 'umbrella'
            ? Color.lerp(lineColor, const Color(0xFF4A5068), 0.22)!
            : lineColor;
        canvas.drawImageRect(
          trainStripe,
          trainSrc,
          SceneArt.trainRect,
          Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = ColorFilter.mode(stripe, BlendMode.modulate),
        );
        _headMark(canvas);
        if (trainWeather != null) {
          canvas.drawImageRect(
            trainWeather!,
            trainSrc,
            SceneArt.trainRect,
            Paint()
              ..filterQuality = FilterQuality.none
              ..colorFilter = ColorFilter.mode(trainWeatherTint, BlendMode.modulate),
          );
        }
      });
    }

    _decorations(canvas, f, bgPaint);
    _passengers(canvas);
    // Easter eggs on the platform (cat, pigeons, attendant, dragonflies).
    events?.paintGround(
      canvas,
      part: part,
      vanishing: vanishing,
      weather: underground ? WeatherKind.sunny : weather,
      sky: sky,
    );
    _effects(canvas, life.value);

    _weather(canvas);
    // After the last train the subway platform is half lit.
    if (underground && closed) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, SceneArt.width.toDouble(), SceneArt.height.toDouble()),
        Paint()..color = const Color(0x7A10142A),
      );
    }
    // Lights glow through the grey weather veil.
    if (!closed && !_gone) _headlights(canvas);
    _wind(canvas);
    // The station sign is lit too, so it reads in the rain and at night.
    if (sign != null) paintStationSign(canvas, SceneArt.signRect, sign!);
    // The LED is lit: drawn after the grey weather veil so it keeps glowing.
    // After the last train the display just says so.
    if (_gone) {
      // Empty track: nothing to light.
    } else if (closed) {
      _atTrain(canvas, () => paintLed(canvas, SceneArt.ledRect, '運行終了', ledColors.first));
    } else if (led.isNotEmpty && hasLed) {
      // A page lasts about 3 seconds (life ticks every 320 ms).
      final page = (life.value ~/ 10) % led.length;
      // Dark far down the line; it flickers on as the train comes close.
      final a = arrive?.value ?? 1;
      final p = _travel(a);
      final on = (depart?.value ?? 0) == 0 && (p >= 0.72 || (p >= 0.56 && (a * 173).floor() % 3 != 0));
      _atTrain(
        canvas,
        () => on
            ? paintLed(canvas, SceneArt.ledRect, led[page], ledColors[page % ledColors.length])
            : canvas.drawRect(SceneArt.ledRect, Paint()..color = const Color(0xFF0E0C14)),
      );
    }
    canvas.restore();
  }

  /// The light of the hour and the weather on the decorations (they are
  /// drawn in daylight colours), as on the waiting passengers.
  Color? get _decorLight {
    final light = switch (part) {
      DayPart.day => null,
      DayPart.evening => const Color(0xFFF2DCD4),
      DayPart.night => const Color(0xFF8E96BC),
    };
    final grey =
        !underground &&
        (SceneArt.wetSkies.contains(sky) ||
            weather == WeatherKind.cloudy ||
            weather == WeatherKind.rain ||
            weather == WeatherKind.snow);
    return grey ? Color.lerp(light ?? const Color(0xFFFFFFFF), const Color(0xFFB4BAC8), 0.5) : light;
  }

  /// MY decorations: they stand on this picture's platform ([decorShift]),
  /// in the light of the hour, their lamps lit at dusk and at night, behind
  /// the people of the picture ([front]).
  void _decorations(Canvas canvas, int frame, Paint bgPaint) {
    if (overlays.isEmpty) return;
    final at = Offset(0, decorShift.toDouble());
    final light = _decorLight;
    final paint = Paint()..filterQuality = FilterQuality.none;
    if (light != null) paint.colorFilter = ColorFilter.mode(light, BlendMode.modulate);
    final glow = underground
        ? 1.0
        : switch (part) {
            DayPart.day => 0.0,
            DayPart.evening => 0.75,
            DayPart.night => 1.0,
          };
    for (var i = 0; i < overlays.length; i++) {
      canvas.drawImage(overlays[i], at, paint);
      final lit = i < overlayLights.length ? overlayLights[i] : null;
      if (lit != null && glow > 0 && !closed) {
        canvas.drawImage(
          lit,
          at,
          Paint()
            ..filterQuality = FilterQuality.none
            ..color = Color.fromRGBO(0, 0, 0, glow),
        );
      }
    }
    // The people standing there are drawn again over the decorations.
    final mask = front;
    if (mask == null) return;
    const w = SceneArt.width * 1.0, h = SceneArt.height * 1.0;
    const full = Rect.fromLTWH(0, 0, w, h);
    final maskFrames = (mask.height ~/ SceneArt.height).clamp(1, 64);
    canvas.saveLayer(full, Paint());
    canvas.drawImageRect(bg, Rect.fromLTWH(0, frame * h, w, h), full, bgPaint);
    canvas.drawImageRect(
      mask,
      Rect.fromLTWH(0, (frame % maskFrames) * h, w, h),
      full,
      Paint()
        ..filterQuality = FilterQuality.none
        ..blendMode = BlendMode.dstIn,
    );
    canvas.restore();
  }

  /// The light of the hour on things that are not part of the picture.
  Color get _hourLight => underground
      ? const Color(0xFFFFFFFF)
      : switch (part) {
          DayPart.day => const Color(0xFFFFFFFF),
          DayPart.evening => const Color(0xFFF0D2C4),
          DayPart.night => const Color(0xFF7C86B4),
        };

  /// The head mark on the train's face, in the train's light. The back of
  /// the train (leaving) has none.
  void _headMark(Canvas canvas) {
    final m = mark;
    if (m == null || closed || (depart?.value ?? 0) > 0) return;
    final at = SceneArt.trainRect.topLeft + markAt - Offset(m.width / 2, m.height / 2);
    final wet = sky == 'rain' || sky == 'umbrella' || sky == 'snow' || sky == 'snowsoon';
    canvas.drawImage(
      m,
      Offset(at.dx.roundToDouble(), at.dy.roundToDouble()),
      Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.mode(
          wet ? Color.lerp(_hourLight, const Color(0xFFADB5C6), 0.5)! : _hourLight,
          BlendMode.modulate,
        ),
    );
  }

  /// Things floating in the sky (hot-air balloons): they drift slowly to and
  /// fro and bob a little. Not in the rain or snow, and not underground.
  void _skyThings(Canvas canvas) {
    if (skies.isEmpty || underground || closed) return;
    final wet =
        sky == 'rain' ||
        sky == 'umbrella' ||
        sky == 'snow' ||
        sky == 'snowsoon' ||
        weather == WeatherKind.rain ||
        weather == WeatherKind.snow;
    if (wet) return;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = ColorFilter.mode(_hourLight, BlendMode.modulate);
    final t = life.value;
    // Left of the overhead-wire mast (it stands at column 112-120), above the
    // roofs: (start, how far it drifts, ticks there and back).
    const paths = [(Offset(62, 30), 26.0, 420), (Offset(20, 14), 14.0, 640)];
    for (var i = 0; i < skies.length && i < paths.length; i++) {
      final (from, reach, period) = paths[i];
      final p = (t % period) / period;
      final drift = (p < 0.5 ? p * 2 : 2 - p * 2) * reach;
      final bob = math.sin(t * 0.21 + i * 1.7) * 1.2;
      canvas.drawImage(
        skies[i],
        Offset((from.dx + drift - skies[i].width / 2).roundToDouble(), (from.dy + bob).roundToDouble()),
        paint,
      );
    }
  }

  /// Rough day / night look for a scene that only has an evening picture.
  static ColorFilter _grade(DayPart part) => switch (part) {
    DayPart.night => const ColorFilter.matrix([
      0.42,
      0,
      0,
      0,
      0,
      0,
      0.48,
      0,
      0,
      4,
      0.05,
      0.05,
      0.72,
      0,
      16,
      0,
      0,
      0,
      1,
      0,
    ]),
    DayPart.day => const ColorFilter.matrix([
      0.88,
      0.06,
      0,
      0,
      6,
      0.02,
      0.98,
      0.04,
      0,
      14,
      0,
      0.08,
      1.05,
      0,
      30,
      0,
      0,
      0,
      1,
      0,
    ]),
    DayPart.evening => const ColorFilter.matrix([1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]),
  };

  /// Colour matrix that moves each colour [amount] of the way to grey.
  static ColorFilter _desaturate(double amount) {
    final k = 1 - amount;
    const r = 0.299, g = 0.587, b = 0.114;
    return ColorFilter.matrix([
      r * amount + k,
      g * amount,
      b * amount,
      0,
      0,
      r * amount,
      g * amount + k,
      b * amount,
      0,
      0,
      r * amount,
      g * amount,
      b * amount + k,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.bg != bg ||
      old.graded != graded ||
      old.overlays != overlays ||
      old.mark != mark ||
      old.skies != skies ||
      old.front != front ||
      old.decorShift != decorShift ||
      old.effects != effects ||
      old.led.join() != led.join() ||
      old.sign != sign ||
      old.weathered != weathered ||
      old.sky != sky ||
      old.closed != closed ||
      old.trainWeather != trainWeather ||
      old.ledColors.join() != ledColors.join() ||
      old.trainBase != trainBase ||
      old.events != events ||
      old.lineColor != lineColor ||
      old.weather != weather ||
      old.underground != underground ||
      old.walkers != walkers ||
      old.view.scale != view.scale ||
      old.view.src != view.src;
}
