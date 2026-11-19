import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/weather/weather_source.dart';
import 'pixel_ui.dart';
import 'scene_events.dart';

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

  /// The same train re-lit for each time of day. [art]: another train's
  /// folder (MY train with its own shape, e.g. 'assets/art/shinkansen'),
  /// holding front_base_{part}, front_stripe, front_rain and front_snow.
  static String trainBase(DayPart part, [String? art]) =>
      art == null ? 'assets/art/train_front_base_${part.name}.png' : '$art/front_base_${part.name}.png';
  static String trainStripeOf([String? art]) => art == null ? trainStripe : '$art/front_stripe.png';
  static const trainStripe = 'assets/art/train_front_stripe.png';

  /// The vending machine decoration (stands behind the people, see _frontMask).
  static const vending = 'assets/art/decor/vending.png';
  static String trainWeatherOf(String sky, [String? art]) =>
      art == null ? 'assets/art/train_front_$sky.png' : '$art/front_$sky.png';

  /// Headlight centres in each train picture (75×96).
  static const lampsDefault = [Offset(14, 64.5), Offset(58.5, 64.5)];
  static const _lamps = {
    'assets/art/shinkansen': [Offset(14.5, 63), Offset(59.5, 63)],
    yellowTrainArt: [Offset(16.5, 67.5), Offset(56.5, 67.5)],
  };
  static List<Offset> lampsOf(String? art) => _lamps[art] ?? lampsDefault;

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

  /// Where the rails meet far down the line in the built-in scene. Each
  /// station, weather and crowd picture has its own point, measured by
  /// tools/find_vanishing.py (assets/art/vanishing.json): some were redrawn
  /// with a slightly lower camera.
  static const vanishing = Offset(227.5, 93.5);

  static Map<String, Offset>? _vanishing;

  /// The rails' meeting point in the picture [asset].
  static Future<Offset> vanishingFor(String asset) async {
    _vanishing ??= await () async {
      try {
        final raw = jsonDecode(await rootBundle.loadString('assets/art/vanishing.json')) as Map<String, dynamic>;
        return {
          for (final e in raw.entries) e.key: Offset((e.value[0] as num).toDouble(), (e.value[1] as num).toDouble()),
        };
      } catch (_) {
        return <String, Offset>{};
      }
    }();
    final known = _vanishing![asset.split('/').last];
    if (known != null) return known;
    // Not measured (rails hidden under snow or water): the usual point of
    // that kind of picture.
    if (asset.contains('/weather/') || asset.contains('/crowd/')) return const Offset(226, 99);
    if (asset.contains('/scenes/')) return const Offset(226, 89.5);
    return vanishing;
  }

  /// How big the train is when it first appears (1 = at the platform).
  static const trainFarScale = 0.07;

  /// The train at [scale] (1 = at the platform) on its track: its bottom
  /// middle slides from the picture's rails' meeting point [from] to the
  /// platform position and it grows
  /// with the same perspective as the rails.
  static Rect trainAt(double scale, [Offset from = vanishing]) {
    const foot = Offset(trainLeft + trainWidth / 2, trainTop + trainHeight);
    final f = from + (foot - from) * scale;
    return Rect.fromLTWH(
      f.dx - trainWidth * scale / 2,
      f.dy - trainHeight * scale,
      trainWidth * scale,
      trainHeight * scale,
    );
  }

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

  /// A bought scene's picture, moving when it has an ambient animation
  /// next to it (`tokyo_day.png` → `tokyo_day_anim.png`, frames stacked).
  static Future<ui.Image> loadMoving(String still) async {
    final anim = still.replaceFirst(RegExp(r'\.png$'), '_anim.png');
    try {
      return await load(anim);
    } catch (_) {
      _images.remove(anim);
      return load(still);
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
    this.trainArt,
    this.led = const [],
    this.ledColors = const [ledOrange],
    this.sign,
  });

  /// Equipped train with its own pictures (folder), null = the usual train.
  final String? trainArt;

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
    trainArt: trainArt,
    led: pages,
    ledColors: colors,
    sign: sign,
  );

  SceneLook withSign(StationSign? s) => SceneLook(
    images: images,
    overlays: overlays,
    effects: effects,
    trainColor: trainColor,
    trainArt: trainArt,
    led: led,
    ledColors: ledColors,
    sign: s,
  );

  String get key => [
    for (final e in images.entries) '${e.key.name}=${e.value}',
    ...overlays,
    ...effects,
    trainColor?.toARGB32() ?? '',
    'train=${trainArt ?? ''}',
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

class _PixelSceneBannerState extends State<PixelSceneBanner> with TickerProviderStateMixin {
  SceneArtSet? _art;

  /// 0 = the train far away down the line, 1 = stopped at the platform.
  late final AnimationController _arrive = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4600),
    value: 1,
  );

  /// After the train stops: passengers get off, then others get on.
  late final AnimationController _platform = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _platformMs),
  );

  /// Leaving: 0 = at the platform, then it pulls out towards us and past;
  /// 1 = gone (the track is empty until the next train).
  late final AnimationController _depart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );

  /// The next step of the station's own rhythm: trains keep coming, stop,
  /// people get off and on, the train leaves, the next one comes.
  Timer? _cycle;
  final _rnd = math.Random();

  bool get _canLoop => mounted && !(_art?.closed ?? false) && !MediaQuery.of(context).disableAnimations;

  void _later(Duration d, VoidCallback step) {
    _cycle?.cancel();
    _cycle = Timer(d, () {
      if (_canLoop) step();
    });
  }

  /// The train has been standing a while: it leaves, then the track is empty.
  void _leave() {
    _depart.forward(from: 0).whenComplete(() {
      if (!mounted || _depart.value < 1) return;
      _later(Duration(seconds: 10 + _rnd.nextInt(9)), _nextTrain);
    });
  }

  /// The next train: far down the line, pulling in (quietly; the melody is
  /// only for a route the user picked).
  void _nextTrain() {
    // Easter eggs (scene_events.dart): now and then the yellow inspection
    // train comes instead; an attendant may come out to meet the train.
    setState(() => _yellow = _events.trainComing(_eventConditions()));
    _platform.reset();
    _arrive.value = 0;
    _depart.value = 0;
    _arrive.forward(from: 0);
  }

  /// Easter-egg events on the platform (cat, pigeons, shooting star…).
  late final _events = SceneEventDirector(vsync: this);

  /// The train now in is the yellow inspection train (see [_events]).
  bool _yellow = false;

  SceneEventConditions _eventConditions() => SceneEventConditions(
    part: _part ?? _currentPart(),
    weather: widget.weather ?? WeatherKind.sunny,
    sky: widget.sky,
    month: (widget.now ?? DateTime.now().toUtc().add(const Duration(hours: 9))).month,
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
    _arrive.addStatusListener((s) {
      if (s == AnimationStatus.completed && !(_art?.closed ?? false)) _platform.forward(from: 0);
      if (s == AnimationStatus.completed && _yellow) _events.yellowTrainArrived();
    });
    // Once everyone is on board, the doors close and it leaves a bit later.
    _platform.addStatusListener((s) {
      if (s == AnimationStatus.completed) _later(Duration(seconds: 6 + _rnd.nextInt(5)), _leave);
    });
    // The first train is already in when the screen opens: people board soon.
    _later(const Duration(seconds: 4), () {
      if (_arrive.value >= 1 && _depart.value == 0 && !_platform.isAnimating) _platform.forward(from: 0);
    });
    _load();
    _tick = Timer.periodic(const Duration(milliseconds: 160), (_) {
      if (!mounted) return;
      _ticks++;
      // Nothing moves while the tab is hidden or another screen is on top.
      if (!TickerMode.valuesOf(context).enabled) return;
      if (_falling) _frame.value++;
      if (_ticks % 2 == 0) _life.value++;
      if (_ticks % 2 == 0 && !MediaQuery.of(context).disableAnimations) _events.onLife(_eventConditions());
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
      _cycle?.cancel();
      _yellow = false;
      _depart.value = 0;
      _platform.reset();
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
    _cycle?.cancel();
    _depart.dispose();
    _arrive.dispose();
    _platform.dispose();
    _frame.dispose();
    _life.dispose();
    _events.dispose();
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
        final yellow = _yellow && art != null ? _events.yellowTrain(art.part) : null;
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
                            trainBase: yellow?.base ?? art.base,
                            trainStripe: yellow?.stripe ?? art.stripe,
                            lamps: SceneArt.lampsOf(yellow != null ? yellowTrainArt : widget.look.trainArt),
                            // At night the stripe is in shadow like the rest of the train.
                            lineColor: stripeColor(widget.look.trainColor ?? widget.lineColor, art.part),
                            weather: weather,
                            life: _life,
                            arrive: _arrive,
                            platform: _platform,
                            depart: _depart,
                            walkers: art.walkers,
                            weathered: art.weathered,
                            sky: art.sky,
                            closed: art.closed,
                            trainWeather: yellow != null ? null : art.trainWeather,
                            trainWeatherTint: art.trainWeatherTint,
                            graded: art.graded,
                            overlays: art.overlays,
                            effects: widget.look.effects,
                            // The yellow train shows its own dark display.
                            led: yellow != null ? const [] : widget.look.led,
                            ledColors: widget.look.ledColors,
                            sign: widget.look.sign,
                            part: art.part,
                            vanishing: art.vanishing,
                            front: art.front,
                            ambience: art.ambience,
                            events: _events,
                          ),
                        ),
                      ),
                      if (_falling)
                        RepaintBoundary(
                          child: CustomPaint(
                            painter: _FallPainter(view: view, weather: weather, frame: _frame, arrive: _arrive),
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
  // Passengers who get off and on once the train has stopped.
  List<Walker> walkers,
  // Where this picture's rails meet: the train comes from there.
  Offset vanishing,
  // The people standing in front of the vending machine in this picture
  // (alpha = person), drawn again over it; null without one.
  ui.Image? front,
  // Sky and lit windows found in the picture, for the drawn ambience.
  SceneAmbience? ambience,
});

/// A passenger waiting at the train door, seen from behind: frame 0
/// standing still in the queue, then [frames] − 1 frames of walking to the
/// door, side by side with the feet on the bottom row (drawn by GPT,
/// tools/gen_passengers_gpt.py and tools/cut_gpt_walk.py).
typedef Walker = ({ui.Image away, int frames});

/// Who waits at the door under [sky]: coats in winter, umbrellas in the
/// rain, else office clothes. Busy platforms (their own queues stand at the
/// doors) have none, so nobody stands in anybody.
List<String> walkersFor(String? sky) {
  final base = sky?.split('_').first;
  if (base == 'closed' || base == 'crowded' || base == 'packed' || (sky?.endsWith('_many') ?? false)) {
    return const [];
  }
  return switch (base) {
    'winter' || 'snow' || 'snowsoon' => const ['coat_man', 'coat_woman'],
    'rain' || 'umbrella' => const ['umbrella_man', 'umbrella_woman'],
    _ => const ['suit_man', 'office_woman'],
  };
}

Future<List<Walker>> _loadWalkers(String? sky) async {
  final out = <Walker>[];
  for (final id in walkersFor(sky)) {
    try {
      // {id}_wait.png: standing + 6 walking frames; {id}_away.png (older):
      // the walk only.
      try {
        out.add((away: await SceneArt.load('assets/art/people/${id}_wait.png'), frames: 7));
      } catch (_) {
        SceneArt.forget('assets/art/people/${id}_wait.png');
        out.add((away: await SceneArt.load('assets/art/people/${id}_away.png'), frames: 6));
      }
    } catch (_) {
      // Not drawn yet: the platform just stays as it is.
    }
  }
  return out;
}

/// Loads the scene for [look] at [part]. A station scene without a picture
/// for this time of day uses another one, colour-graded.
/// Mask of the people in front of the vending machine in picture [bgAsset]
/// (tools/make_vending_masks.py), when the machine is set up.
Future<ui.Image?> _frontMask(SceneLook look, String bgAsset) async {
  if (!look.overlays.contains(SceneArt.vending)) return null;
  final name = bgAsset.split('/').last.replaceFirst('_anim.png', '.png');
  final asset = 'assets/art/decor/vending_front/$name';
  try {
    return await SceneArt.load(asset);
  } catch (_) {
    SceneArt.forget(asset);
    return null;
  }
}

Future<SceneArtSet> loadSceneArt(SceneLook look, DayPart part, {String? sky}) async {
  DayPart? graded;
  Future<ui.Image> bg;
  // A weather version of this scene, when one has been drawn.
  ui.Image? weathered;
  // The picture file in use, for its rails' meeting point.
  var bgAsset = SceneArt.animation(part);
  // 'rain_many' / 'rain_few': the weather with more or fewer people; when
  // there is no such picture the plain one (the station's usual crowd) is used.
  final baseSky = sky?.split('_').first;
  for (final s in {?sky, ?baseSky}) {
    // The closed station is only drawn at night (it is always late then).
    final asset = SceneArt.weatherScene(SceneArt.sceneId(look), s == 'closed' ? DayPart.night : part, s);
    try {
      weathered = await SceneArt.load(asset);
      bgAsset = asset;
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
    bgAsset = look.images[part]!;
    bg = SceneArt.loadMoving(bgAsset);
  } else {
    graded = part;
    bgAsset = look.images[DayPart.evening] ?? look.images.values.first;
    bg = SceneArt.loadMoving(bgAsset);
  }
  final wx = weathered != null && (baseSky == 'snow' || baseSky == 'rain')
      ? SceneArt.trainWeatherOf(baseSky!, look.trainArt)
      : null;
  final images = await Future.wait([
    bg,
    SceneArt.load(SceneArt.trainBase(part, look.trainArt)),
    SceneArt.load(SceneArt.trainStripeOf(look.trainArt)),
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
    walkers: await _loadWalkers(sky),
    vanishing: await SceneArt.vanishingFor(bgAsset),
    front: await _frontMask(look, bgAsset),
    ambience: await SceneAmbience.of(await bg, bgAsset),
    // Snow and drops take the light of the hour: bluish at night.
    trainWeatherTint: switch (part) {
      DayPart.day => const Color(0xFFFFFFFF),
      DayPart.evening => const Color(0xFFF2DCE2),
      DayPart.night => const Color(0xFF98A2C8),
    },
  );
}

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
    part: part,
    vanishing: art.vanishing,
    front: art.front,
    ambience: art.ambience,
    // Review renders: the train part way through its arrival.
    arrive: arrive == null ? null : AlwaysStoppedAnimation(arrive),
    platform: platform == null ? null : AlwaysStoppedAnimation(platform),
    depart: depart == null ? null : AlwaysStoppedAnimation(depart),
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
    this.walkers = const [],
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
    this.part = DayPart.day,
    this.vanishing = SceneArt.vanishing,
    this.front,
    this.ambience,
    this.events,
  }) : super(repaint: Listenable.merge([life, ?arrive, ?platform, ?depart, ?events]));

  /// Easter-egg events (scene_events.dart), or null.
  final SceneEventDirector? events;

  final StationSign? sign;

  /// Time of day of the picture: how bright the headlights look.
  final DayPart part;

  /// Where the picture's rails meet: the arriving train comes from there.
  final Offset vanishing;

  /// People in front of the vending machine (alpha mask), or null.
  final ui.Image? front;

  /// Sky and window lights of the picture (clouds, birds, stars, windows).
  final SceneAmbience? ambience;

  /// Train arrival, 0 far away … 1 at the platform (null = always arrived).
  final Animation<double>? arrive;

  /// Leaving after the stop (0 … 1 = gone); null = it stays.
  final Animation<double>? depart;

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
    events?.paintSky(canvas, bg: bg, part: part);
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

    // Decorations sit on the platform, in front of the train's back.
    for (final o in overlays) {
      canvas.drawImage(o, Offset.zero, art);
    }
    // People standing closer than the vending machine are drawn again over it.
    if (front != null) {
      const full = Rect.fromLTWH(0, 0, SceneArt.width * 1.0, SceneArt.height * 1.0);
      canvas.saveLayer(full, Paint());
      canvas.drawImageRect(
        bg,
        Rect.fromLTWH(0, f * SceneArt.height.toDouble(), SceneArt.width.toDouble(), SceneArt.height.toDouble()),
        full,
        bgPaint,
      );
      canvas.drawImage(front!, Offset.zero, Paint()..blendMode = BlendMode.dstIn);
      canvas.restore();
    }
    _passengers(canvas);
    // Easter eggs on the platform (cat, pigeons, attendant, dragonflies).
    events?.paintGround(canvas, part: part, vanishing: vanishing, weather: weather, sky: sky);
    _effects(canvas, life.value);

    _weather(canvas);
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
    } else if (led.isNotEmpty) {
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

  /// The two headlights: seen first as two bright points far down the line,
  /// growing as the train nears; brighter at dusk, at night and in the
  /// rain, when they also light up the rails in front of the train.
  void _headlights(Canvas canvas) {
    final wet =
        sky == 'rain' ||
        sky == 'umbrella' ||
        sky == 'snow' ||
        sky == 'snowsoon' ||
        weather == WeatherKind.rain ||
        weather == WeatherKind.snow;
    final strength = switch (part) {
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
    if (effects.contains('garland')) _garland(canvas, f);
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
      old.events != events ||
      old.lineColor != lineColor ||
      old.weather != weather ||
      old.view.scale != view.scale ||
      old.view.src != view.src;
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
    final rnd = math.Random(asset.hashCode);
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
    return _cache[asset] = SceneAmbience._(stars.take(30).toList(), windows.take(70).toList(), asset.hashCode);
  }

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
