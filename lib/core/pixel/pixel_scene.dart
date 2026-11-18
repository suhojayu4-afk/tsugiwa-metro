import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/weather/weather_source.dart';
import 'pixel_ui.dart';

enum DayPart { day, evening, night }

DayPart dayPartOf(DateTime t) => switch (t.hour) {
  >= 5 && < 16 => DayPart.day,
  >= 16 && < 19 => DayPart.evening,
  _ => DayPart.night,
};

/// Illustrated platform scenes (pixel-art PNGs, see docs/art/STYLE.md).
class SceneArt {
  static const width = 384;
  static const height = 192;

  static String background(DayPart part) => 'assets/art/scene_${part.name}.png';

  /// Optional ambient animation: the scene's frames stacked vertically
  /// (frame i at y = height * i). Falls back to the still picture.
  static String animation(DayPart part) => 'assets/art/scene_${part.name}_anim.png';

  /// Time each ambient frame stays on screen.
  static const frameTime = Duration(milliseconds: 320);

  /// The same train re-lit for each time of day.
  static String trainBase(DayPart part) => 'assets/art/train_front_base_${part.name}.png';
  static const trainStripe = 'assets/art/train_front_stripe.png';

  /// Crowd levels with their own pictures (tools/gen_crowd_scenes.py).
  static const crowdLevels = {'relaxed', 'normal', 'crowded', 'packed'};

  /// Weather pictures that already show grey skies (no extra greying).
  static const wetSkies = {'umbrella', 'rain', 'snow', 'snowsoon'};

  /// Another version of a station scene, drawn by GPT: [sky] is a weather
  /// ('umbrella' = rain expected, 'rain', 'snow', 'winter';
  /// tools/gen_weather_scenes.py) or a crowd level ([crowdLevels]).
  static String weatherScene(String sceneId, DayPart part, String sky) => crowdLevels.contains(sky)
      ? 'assets/art/crowd/${sceneId}_${part.name}_$sky.png'
      : 'assets/art/weather/${sceneId}_${part.name}_$sky.png';

  /// 'standard' for the built-in scene, else the station ('tokyo', 'shibuya', …)
  /// from the scene's picture names.
  static String sceneId(SceneLook look) {
    if (look.images.isEmpty) return 'standard';
    final file = look.images.values.first.split('/').last;
    return file.substring(0, file.lastIndexOf('_'));
  }

  /// Where the train is when it first appears, far down the line.
  static const trainFar = Rect.fromLTWH(trainLeft + 33, 60, 9, 11.5);

  /// Where the train stands in scene pixels. Tuned so the wheels sit on the
  /// rails of the empty track.
  static const trainRect = Rect.fromLTWH(trainLeft, trainTop, trainWidth, trainHeight);
  static const double trainLeft = 178, trainTop = 27, trainWidth = 75, trainHeight = 96;

  /// The hanging station sign under the platform roof, in scene pixels.
  static const signRect = Rect.fromLTWH(318, 40, 46, 19);

  /// The destination LED strip at the top of the windshield, in scene pixels.
  static const ledRect = Rect.fromLTWH(trainLeft + 15, trainTop + 15, 43, 7);

  /// The view is cropped around this column when the screen is narrower
  /// than the picture.
  static const focusX = 210.0;

  static final _images = <String, Future<ui.Image>>{};

  /// The animation sheet if there is one, else the still picture.
  static Future<ui.Image> loadScene(DayPart part) async {
    try {
      return await load(animation(part));
    } catch (_) {
      _images.remove(animation(part));
      return load(background(part));
    }
  }

  /// Drops a failed load so a later call can try again.
  static void forget(String asset) => _images.remove(asset);

  static Future<ui.Image> load(String asset) => _images[asset] ??= () async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }();
}

const ledOrange = Color(0xFFFFAA3C);

/// Draws a destination LED: dark panel, [text] in [color] made of dots.
/// [r] is in whatever units the canvas uses (scene pixels in the banner).
void paintLed(Canvas canvas, Rect r, String text, Color color) {
  canvas.save();
  canvas.clipRect(r);
  canvas.drawRect(r, Paint()..color = const Color(0xFF0E0C14));
  // Faint glow of the whole panel.
  canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.14));
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: 'DotGothic16', fontSize: r.height * 0.92, color: color, height: 1),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final room = r.width - r.height * 0.6;
  final squeeze = tp.width > room ? room / tp.width : 1.0;
  canvas.save();
  canvas.translate(r.center.dx - tp.width * squeeze / 2, r.center.dy - tp.height / 2);
  canvas.scale(squeeze, 1);
  tp.paint(canvas, Offset.zero);
  canvas.restore();
  tp.dispose();
  // Dot matrix: thin dark lines between the LED dots.
  final step = r.height / 7;
  final grid = Paint()
    ..color = const Color(0x660E0C14)
    ..strokeWidth = step * 0.3;
  for (var x = r.left + step; x < r.right; x += step) {
    canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), grid);
  }
  for (var y = r.top + step; y < r.bottom; y += step) {
    canvas.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
  }
  canvas.restore();
}

/// A station sign (駅名標): big name, small second line, line colour band.
@immutable
class StationSign {
  const StationSign({required this.name, this.sub = '', required this.band});
  final String name;
  final String sub;
  final Color band;

  @override
  bool operator ==(Object other) =>
      other is StationSign && other.name == name && other.sub == sub && other.band == band;

  @override
  int get hashCode => Object.hash(name, sub, band);
}

/// Draws the hanging sign [s] in [r] (scene pixels): wires up to the roof,
/// a white board with a dark frame, the name, a colour band and a small line.
void paintStationSign(Canvas canvas, Rect r, StationSign s) {
  final wire = Paint()
    ..color = const Color(0xFF464850)
    ..strokeWidth = 1;
  canvas.drawLine(Offset(r.left + 8, r.top - 7), Offset(r.left + 8, r.top), wire);
  canvas.drawLine(Offset(r.right - 8, r.top - 7), Offset(r.right - 8, r.top), wire);
  canvas.drawRect(r, Paint()..color = const Color(0xFF3C3E48));
  final board = r.deflate(1);
  canvas.drawRect(board, Paint()..color = const Color(0xFFF6F6F2));
  canvas.drawRect(Rect.fromLTWH(board.left, r.top + 13, board.width, 2), Paint()..color = s.band);
  void text(String t, double size, Color color, double cy, double maxW) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(fontFamily: 'DotGothic16', fontSize: size, color: color, height: 1),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final k = tp.width > maxW ? maxW / tp.width : 1.0;
    canvas.save();
    canvas.translate(r.center.dx - tp.width * k / 2, cy - tp.height / 2);
    canvas.scale(k, 1);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
    tp.dispose();
  }

  text(s.name, 10, const Color(0xFF1E2030), r.top + 7, r.width - 6);
  if (s.sub.isNotEmpty) text(s.sub, 4.2, const Color(0xFF32343C), r.top + 16.6, r.width - 6);
}

/// What the user made of their station in MY: which station scene, the
/// decorations on it and the colour of their train.
@immutable
class SceneLook {
  const SceneLook({
    this.images = const {},
    this.overlays = const [],
    this.effects = const {},
    this.trainColor,
    this.led = const [],
    this.ledColors = const [ledOrange],
    this.sign,
  });

  /// Scene picture per time of day. Empty = the built-in animated scene.
  /// A missing time of day falls back to another picture, colour-graded.
  final Map<DayPart, String> images;

  /// Decoration layers, same size as the scene (transparent elsewhere).
  final List<String> overlays;

  /// Drawn effects: 'petals', 'fireflies', 'garland'.
  final Set<String> effects;

  /// Equipped train colour; null = the colour of the line being used.
  final Color? trainColor;

  /// Pages shown in turn on the train's destination LED (name, reading…).
  /// Empty = the LED stays dark.
  final List<String> led;

  /// LED colour; more than one = the colour changes with each page.
  final List<Color> ledColors;

  /// The station sign hanging from the platform roof (駅名標): the name,
  /// a small second line (English or reading) and the line colour band.
  final StationSign? sign;

  SceneLook withLed(List<String> pages, List<Color> colors) => SceneLook(
    images: images,
    overlays: overlays,
    effects: effects,
    trainColor: trainColor,
    led: pages,
    ledColors: colors,
    sign: sign,
  );

  SceneLook withSign(StationSign? s) => SceneLook(
    images: images,
    overlays: overlays,
    effects: effects,
    trainColor: trainColor,
    led: led,
    ledColors: ledColors,
    sign: s,
  );

  String get key => [
    for (final e in images.entries) '${e.key.name}=${e.value}',
    ...overlays,
    ...effects,
    trainColor?.toARGB32() ?? '',
    'led=${led.join('/')}',
    'sign=${sign?.name}/${sign?.sub}/${sign?.band.toARGB32()}',
    for (final c in ledColors) c.toARGB32(),
  ].join('|');

  @override
  bool operator ==(Object other) => other is SceneLook && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// The header picture: the platform at the current time of day, the user's
/// train waiting on the track (stripe in the line colour) and the weather.
class PixelSceneBanner extends StatefulWidget {
  const PixelSceneBanner({
    super.key,
    required this.lineColor,
    this.weather,
    this.now,
    this.aspect = 2.0,
    this.look = const SceneLook(),
    this.arrivalKey,
    this.sky,
    this.onArrive,
  });
  final Color lineColor;

  /// Called when the train starts pulling in (for the departure melody).
  final VoidCallback? onArrive;

  /// When this changes (a new route is picked) the train pulls in from the
  /// distance and stops at the platform.
  final Object? arrivalKey;

  /// Weather picture to use when there is one: 'umbrella' (rain expected:
  /// people carry umbrellas), 'rain' or 'snow'. Null = the normal scene.
  final String? sky;

  /// Station scene and decorations chosen in MY.
  final SceneLook look;

  /// Width / height of the visible picture; smaller shows a taller crop.
  final double aspect;
  final WeatherKind? weather;

  /// Only for tests and previews; defaults to the clock.
  final DateTime? now;

  @override
  State<PixelSceneBanner> createState() => _PixelSceneBannerState();
}

class _PixelSceneBannerState extends State<PixelSceneBanner> with SingleTickerProviderStateMixin {
  SceneArtSet? _art;

  /// 0 = the train far away down the line, 1 = stopped at the platform.
  late final AnimationController _arrive = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
    value: 1,
  );

  DayPart? _part;
  Timer? _tick;
  int _ticks = 0;

  /// Rain/snow animation step. Drives only the particle layer's repaint.
  final _frame = ValueNotifier<int>(0);

  /// Ambient animation step (people, lights, leaves). Drives only the
  /// picture's repaint; nothing is rebuilt.
  final _life = ValueNotifier<int>(0);

  bool get _falling => widget.weather == WeatherKind.rain || widget.weather == WeatherKind.snow;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(milliseconds: 160), (_) {
      if (!mounted) return;
      _ticks++;
      // Nothing moves while the tab is hidden or another screen is on top.
      if (!TickerMode.valuesOf(context).enabled) return;
      if (_falling) _frame.value++;
      if (_ticks % 2 == 0) _life.value++;
      // About once a minute: has the time of day changed?
      if (_ticks % 375 == 0 && _currentPart() != _part) _load();
    });
  }

  // Cities are all in Japan: use Japan time, not the phone's time zone.
  DayPart _currentPart() => dayPartOf(widget.now ?? DateTime.now().toUtc().add(const Duration(hours: 9)));

  @override
  void didUpdateWidget(PixelSceneBanner old) {
    super.didUpdateWidget(old);
    if (old.look != widget.look || old.sky != widget.sky) _load();
    if (widget.arrivalKey != null && old.arrivalKey != widget.arrivalKey) {
      _arrive.forward(from: 0);
      widget.onArrive?.call();
    }
  }

  Future<void> _load() async {
    final part = _currentPart();
    _part = part;
    final art = await loadSceneArt(widget.look, part, sky: widget.sky);
    if (!mounted) return;
    setState(() => _art = art);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _arrive.dispose();
    _frame.dispose();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final weather = widget.weather ?? WeatherKind.sunny;
    return LayoutBuilder(
      builder: (context, box) {
        final view = SceneView.fit(box.maxWidth, dpr, aspect: widget.aspect);
        final art = _art;
        return ClipPath(
          clipper: const _SteppedClip(),
          child: SizedBox(
            width: box.maxWidth,
            height: view.logicalHeight,
            child: art == null
                ? const ColoredBox(color: PixelColors.soft)
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: _ScenePainter(
                            view: view,
                            bg: art.bg,
                            trainBase: art.base,
                            trainStripe: art.stripe,
                            // At night the stripe is in shadow like the rest of the train.
                            lineColor: stripeColor(widget.look.trainColor ?? widget.lineColor, art.part),
                            weather: weather,
                            life: _life,
                            arrive: _arrive,
                            weathered: art.weathered,
                            sky: art.sky,
                            closed: art.closed,
                            trainWeather: art.trainWeather,
                            trainWeatherTint: art.trainWeatherTint,
                            graded: art.graded,
                            overlays: art.overlays,
                            effects: widget.look.effects,
                            led: widget.look.led,
                            ledColors: widget.look.ledColors,
                            sign: widget.look.sign,
                          ),
                        ),
                      ),
                      if (_falling)
                        RepaintBoundary(
                          child: CustomPaint(
                            painter: _FallPainter(view: view, weather: weather, frame: _frame),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// The pictures needed to draw one scene at one time of day.
typedef SceneArtSet = ({
  ui.Image bg,
  ui.Image base,
  ui.Image stripe,
  DayPart part,
  DayPart? graded,
  List<ui.Image> overlays,
  bool weathered,
  // The weather picture in use ('rain', 'snow', 'umbrella', 'winter') and
  // what goes on the train for it (snow on the roof, raindrops).
  String? sky,
  bool closed,
  ui.Image? trainWeather,
  Color trainWeatherTint,
});

/// Loads the scene for [look] at [part]. A station scene without a picture
/// for this time of day uses another one, colour-graded.
Future<SceneArtSet> loadSceneArt(SceneLook look, DayPart part, {String? sky}) async {
  DayPart? graded;
  Future<ui.Image> bg;
  // A weather version of this scene, when one has been drawn.
  ui.Image? weathered;
  // 'rain_many' / 'rain_few': the weather with more or fewer people; when
  // there is no such picture the plain one (the station's usual crowd) is used.
  final baseSky = sky?.split('_').first;
  for (final s in {?sky, ?baseSky}) {
    // The closed station is only drawn at night (it is always late then).
    final asset = SceneArt.weatherScene(SceneArt.sceneId(look), s == 'closed' ? DayPart.night : part, s);
    try {
      weathered = await SceneArt.load(asset);
      break;
    } catch (_) {
      SceneArt.forget(asset);
    }
  }
  if (weathered != null) {
    bg = Future.value(weathered);
  } else if (look.images.isEmpty) {
    bg = SceneArt.loadScene(part);
  } else if (look.images[part] != null) {
    bg = SceneArt.load(look.images[part]!);
  } else {
    graded = part;
    bg = SceneArt.load(look.images[DayPart.evening] ?? look.images.values.first);
  }
  final wx = weathered != null && (baseSky == 'snow' || baseSky == 'rain')
      ? 'assets/art/train_front_$baseSky.png'
      : null;
  final images = await Future.wait([
    bg,
    SceneArt.load(SceneArt.trainBase(part)),
    SceneArt.load(SceneArt.trainStripe),
    if (wx != null) SceneArt.load(wx),
    for (final o in look.overlays) SceneArt.load(o),
  ]);
  final first = wx == null ? 3 : 4;
  return (
    bg: images[0],
    base: images[1],
    stripe: images[2],
    part: part,
    graded: graded,
    overlays: images.sublist(first),
    weathered: weathered != null,
    sky: weathered != null ? baseSky : null,
    closed: baseSky == 'closed',
    trainWeather: wx == null ? null : images[3],
    // Snow and drops take the light of the hour: bluish at night.
    trainWeatherTint: switch (part) {
      DayPart.day => const Color(0xFFFFFFFF),
      DayPart.evening => const Color(0xFFF2DCE2),
      DayPart.night => const Color(0xFF98A2C8),
    },
  );
}

/// At night the stripe is in shadow like the rest of the train.
Color stripeColor(Color color, DayPart part) =>
    part == DayPart.night ? Color.lerp(color, const Color(0xFF1A2050), 0.3)! : color;

/// The whole scene (384×192 art pixels, each [scale]×[scale]) as one still
/// image, for the home screen widget and share cards.
Future<ui.Image> renderSceneImage({
  required SceneLook look,
  required DayPart part,
  required Color lineColor,
  WeatherKind weather = WeatherKind.sunny,
  int scale = 2,
  String? sky,
}) async {
  final art = await loadSceneArt(look, part, sky: sky);
  final view = SceneView(scale.toDouble(), Rect.fromLTWH(0, 0, SceneArt.width.toDouble(), SceneArt.height.toDouble()));
  final life = ValueNotifier<int>(0);
  final recorder = ui.PictureRecorder();
  final size = Size(SceneArt.width * scale.toDouble(), SceneArt.height * scale.toDouble());
  _ScenePainter(
    view: view,
    bg: art.bg,
    trainBase: art.base,
    trainStripe: art.stripe,
    lineColor: stripeColor(look.trainColor ?? lineColor, part),
    weather: weather,
    life: life,
    graded: art.graded,
    overlays: art.overlays,
    weathered: art.weathered,
    sky: art.sky,
    closed: art.closed,
    trainWeather: art.trainWeather,
    trainWeatherTint: art.trainWeatherTint,
    effects: look.effects,
    led: look.led,
    ledColors: look.ledColors,
    sign: look.sign,
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
    required this.lineColor,
    required this.weather,
    required this.life,
    this.arrive,
    this.weathered = false,
    this.sky,
    this.closed = false,
    this.trainWeather,
    this.trainWeatherTint = const Color(0xFFFFFFFF),
    this.graded,
    this.overlays = const [],
    this.effects = const {},
    this.led = const [],
    this.ledColors = const [ledOrange],
    this.sign,
  }) : super(repaint: arrive == null ? life : Listenable.merge([life, arrive]));

  final StationSign? sign;

  /// Train arrival, 0 far away … 1 at the platform (null = always arrived).
  final Animation<double>? arrive;

  /// The picture is already a rainy / snowy version: do not grey it again.
  final bool weathered;

  /// Which weather picture is shown; the train is matched to it.
  final String? sky;
  final ui.Image? trainWeather;

  /// After the last train: the train's display says 「運行終了」.
  final bool closed;
  final Color trainWeatherTint;

  /// The train under the same sky as the picture: darker and cooler under
  /// rain clouds, a little cooler in the snow.
  Paint _trainPaint(Paint art) => switch (sky) {
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

  /// Where the train is drawn now: it comes up the line, growing as it nears.
  Rect get _trainNow {
    final a = arrive?.value ?? 1;
    if (a >= 1) return SceneArt.trainRect;
    // Fast at first, braking gently into the platform.
    final t = Curves.easeOutQuad.transform(a);
    return Rect.lerp(SceneArt.trainFar, SceneArt.trainRect, t)!;
  }

  /// Draws [draw] (made for the train at its stop) where the train is now.
  void _atTrain(Canvas canvas, void Function() draw) {
    final r = _trainNow;
    if (r == SceneArt.trainRect) return draw();
    canvas.save();
    canvas.translate(r.left, r.top);
    canvas.scale(r.width / SceneArt.trainRect.width, r.height / SceneArt.trainRect.height);
    canvas.translate(-SceneArt.trainRect.left, -SceneArt.trainRect.top);
    draw();
    canvas.restore();
  }

  final List<String> led;
  final List<Color> ledColors;

  /// Set when the picture is another time of day's, to be colour-graded.
  final DayPart? graded;
  final List<ui.Image> overlays;
  final Set<String> effects;

  final SceneView view;
  final ValueNotifier<int> life;

  /// Animation sheet (or one still frame).
  final ui.Image bg;
  final ui.Image trainBase;
  final ui.Image trainStripe;
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
    final trainSrc = Rect.fromLTWH(0, 0, trainBase.width.toDouble(), trainBase.height.toDouble());
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

    // Decorations sit on the platform, in front of the train's back.
    for (final o in overlays) {
      canvas.drawImage(o, Offset.zero, art);
    }
    _effects(canvas, life.value);

    _weather(canvas);
    // The station sign is lit too, so it reads in the rain and at night.
    if (sign != null) paintStationSign(canvas, SceneArt.signRect, sign!);
    // The LED is lit: drawn after the grey weather veil so it keeps glowing.
    // After the last train the display just says so.
    if (closed) {
      _atTrain(canvas, () => paintLed(canvas, SceneArt.ledRect, '運行終了', ledColors.first));
    } else if (led.isNotEmpty) {
      // A page lasts about 3 seconds (life ticks every 320 ms).
      final page = (life.value ~/ 10) % led.length;
      _atTrain(canvas, () => paintLed(canvas, SceneArt.ledRect, led[page], ledColors[page % ledColors.length]));
    }
    canvas.restore();
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
    if (effects.contains('garland')) {
      // Along the front edge of the platform roof.
      const colors = [Color(0xFFFF6B6B), Color(0xFFFFD25E), Color(0xFF7BE07B), Color(0xFF6BB8FF)];
      for (var i = 0; i < 18; i++) {
        final t = i / 17;
        final x = 262 - 26 * t;
        final y = 6 + 90 * t + 3 * (1 - (2 * ((i % 3) / 2) - 1).abs());
        final on = (i + f) % 4 != 0;
        p.color = colors[i % 4].withValues(alpha: on ? 1 : 0.35);
        canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), p);
      }
    }
  }

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

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.bg != bg ||
      old.graded != graded ||
      old.overlays != overlays ||
      old.effects != effects ||
      old.led.join() != led.join() ||
      old.sign != sign ||
      old.weathered != weathered ||
      old.sky != sky ||
      old.closed != closed ||
      old.trainWeather != trainWeather ||
      old.ledColors.join() != ledColors.join() ||
      old.trainBase != trainBase ||
      old.lineColor != lineColor ||
      old.weather != weather ||
      old.view.scale != view.scale ||
      old.view.src != view.src;
}

/// Falling rain or snow. The particles are drawn once into a tile image;
/// each frame only moves that tile (4 image draws), which keeps the
/// animation cheap on any phone.
class _FallPainter extends CustomPainter {
  _FallPainter({required this.view, required this.weather, required this.frame}) : super(repaint: frame);

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
    final dx = rain ? (-f) % w : (((f ~/ 4) % 3) - 1) % w;
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

/// Small pixel-stepped corners, matching the cards.
class _SteppedClip extends CustomClipper<Path> {
  const _SteppedClip();

  @override
  Path getClip(Size s) {
    const c = pu;
    return Path()
      ..moveTo(2 * c, 0)
      ..lineTo(s.width - 2 * c, 0)
      ..lineTo(s.width - 2 * c, c)
      ..lineTo(s.width - c, c)
      ..lineTo(s.width - c, 2 * c)
      ..lineTo(s.width, 2 * c)
      ..lineTo(s.width, s.height - 2 * c)
      ..lineTo(s.width - c, s.height - 2 * c)
      ..lineTo(s.width - c, s.height - c)
      ..lineTo(s.width - 2 * c, s.height - c)
      ..lineTo(s.width - 2 * c, s.height)
      ..lineTo(2 * c, s.height)
      ..lineTo(2 * c, s.height - c)
      ..lineTo(c, s.height - c)
      ..lineTo(c, s.height - 2 * c)
      ..lineTo(0, s.height - 2 * c)
      ..lineTo(0, 2 * c)
      ..lineTo(c, 2 * c)
      ..lineTo(c, c)
      ..lineTo(2 * c, c)
      ..close();
  }

  @override
  bool shouldReclip(_SteppedClip old) => false;
}
