part of 'pixel_scene.dart';

/// Illustrated platform scenes (pixel-art pictures, lossless WebP; see docs/art/STYLE.md).
class SceneArt {
  static const width = 384;
  static const height = 192;

  static String background(DayPart part) => 'assets/art/scene_${part.name}.webp';

  /// Optional ambient animation: the scene's frames stacked vertically
  /// (frame i at y = height * i). Falls back to the still picture.
  static String animation(DayPart part) => 'assets/art/scene_${part.name}_anim.webp';

  /// Time each ambient frame stays on screen.
  static const frameTime = Duration(milliseconds: 320);

  /// The same train re-lit for each time of day. [art]: another train's
  /// folder (MY train with its own shape, e.g. 'assets/art/shinkansen'),
  /// holding front_base_{part}, front_stripe, front_rain and front_snow.
  static String trainBase(DayPart part, [String? art]) =>
      art == null ? 'assets/art/train_front_base_${part.name}.webp' : '$art/front_base_${part.name}.webp';
  static String trainStripeOf([String? art]) => art == null ? trainStripe : '$art/front_stripe.webp';
  static const trainStripe = 'assets/art/train_front_stripe.webp';

  /// Snow / raindrops over the train. These stay PNG: their soft
  /// (half-transparent) edges decode a shade differently from WebP.
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
      ? 'assets/art/crowd/${sceneId}_${part.name}_$sky.webp'
      : 'assets/art/weather/${sceneId}_${part.name}_$sky.webp';

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

  /// Loaded pictures, least recently used first (a Dart map keeps the order
  /// keys were added in; [load] moves a hit to the end). At most
  /// [cacheLimit] are kept: the oldest is dropped, not disposed, so a scene
  /// still showing it keeps drawing it and it is freed once nothing uses it.
  static final _images = <String, Future<ui.Image>>{};

  /// How many pictures [load] keeps (one scene with its train, people,
  /// decorations and events uses about 20).
  static int cacheLimit = 40;

  /// Number of pictures kept now (tests).
  @visibleForTesting
  static int get cachedCount => _images.length;

  /// Whether [asset] is kept now (tests).
  @visibleForTesting
  static bool isCached(String asset) => _images.containsKey(asset);

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
  /// next to it (`tokyo_day.webp` → `tokyo_day_anim.webp`, frames stacked).
  static Future<ui.Image> loadMoving(String still) async {
    final anim = still.replaceFirst(RegExp(r'\.webp$'), '_anim.webp');
    try {
      return await load(anim);
    } catch (_) {
      _images.remove(anim);
      return load(still);
    }
  }

  /// Drops a failed load so a later call can try again.
  static void forget(String asset) => _images.remove(asset);

  static Future<ui.Image> load(String asset) {
    final hit = _images.remove(asset);
    if (hit != null) return _images[asset] = hit;
    final image = () async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    }();
    _images[asset] = image;
    while (_images.length > cacheLimit) {
      _images.remove(_images.keys.first);
    }
    return image;
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
  // The people standing where platform decorations go in this picture
  // (alpha = person; one mask per animation frame, stacked), drawn again
  // over the decorations; null when nobody stands there.
  ui.Image? front,
  // Rows this picture's platform is below the built-in scene's: the
  // decorations move down with it.
  int decorShift,
  // Per overlay: its lights (lit windows, lamps) for dusk and night, or null.
  List<ui.Image?> overlayLights,
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
      // {id}_wait.webp: standing + 6 walking frames; {id}_away.webp (older):
      // the walk only.
      try {
        out.add((away: await SceneArt.load('assets/art/people/${id}_wait.webp'), frames: 7));
      } catch (_) {
        SceneArt.forget('assets/art/people/${id}_wait.webp');
        out.add((away: await SceneArt.load('assets/art/people/${id}_away.webp'), frames: 6));
      }
    } catch (_) {
      // Not drawn yet: the platform just stays as it is.
    }
  }
  return out;
}

/// What tools/make_decor_masks.py and tools/place_decor.py know about the
/// MY decorations (assets/art/decor/index.json).
class DecorIndex {
  const DecorIndex({this.masks = const {}, this.shifts = const {}, this.lights = const {}});

  /// Platform pictures (file names) with a mask of the people standing
  /// where decorations go, in [maskFolder]. A picture not listed here has
  /// nobody there: the decoration is drawn as it is.
  final Set<String> masks;

  /// Rows each platform picture is below the built-in scene's (the weather
  /// and crowd pictures were drawn with the camera tilted a little: 10).
  final Map<String, int> shifts;

  /// Overlays (assets) with a second picture of their lights,
  /// `{name}_lit.webp`, drawn at full brightness at dusk and at night.
  final Set<String> lights;

  static const maskFolder = 'assets/art/decor/vending_front';

  /// The file name the index knows the picture [bgAsset] by (an animated
  /// picture is listed as its still one).
  static String pictureName(String bgAsset) => bgAsset.split('/').last.replaceFirst('_anim.webp', '.webp');

  /// The mask of the people in [bgAsset], or null when it has none.
  String? maskFor(String bgAsset) {
    final name = pictureName(bgAsset);
    return masks.contains(name) ? '$maskFolder/$name' : null;
  }

  /// Rows to move decorations down in [bgAsset]. A picture the tool has not
  /// seen: from where its rails meet ([vanishing]; the built-in scene's
  /// floor horizon is at row 92).
  int shiftFor(String bgAsset, Offset vanishing) =>
      shifts[pictureName(bgAsset)] ?? (vanishing.dy + 2.6 - 92).round().clamp(-4, 14);

  String? lightsFor(String overlay) =>
      lights.contains(overlay) ? overlay.replaceFirst(RegExp(r'\.webp$'), '_lit.webp') : null;

  factory DecorIndex.fromJson(Map<String, dynamic> j) => DecorIndex(
    masks: {...(j['masks'] as List? ?? const []).cast<String>()},
    shifts: {for (final e in (j['shifts'] as Map<String, dynamic>? ?? const {}).entries) e.key: e.value as int},
    lights: {...(j['lights'] as List? ?? const []).cast<String>()},
  );

  static Future<DecorIndex>? _cache;

  /// Tests: forget the loaded index (each test has its own asset bundle).
  @visibleForTesting
  static void resetCache() => _cache = null;

  static Future<DecorIndex> load() => _cache ??= () async {
    try {
      return DecorIndex.fromJson(
        jsonDecode(await rootBundle.loadString('assets/art/decor/index.json')) as Map<String, dynamic>,
      );
    } catch (_) {
      return const DecorIndex();
    }
  }();
}

Future<ui.Image?> _loadOrNull(String? asset) async {
  if (asset == null) return null;
  try {
    return await SceneArt.load(asset);
  } catch (_) {
    SceneArt.forget(asset);
    return null;
  }
}

/// Loads the scene for [look] at [part]. A station scene without a picture
/// for this time of day uses another one, colour-graded.
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
  final decor = look.overlays.isEmpty && !look.effects.contains('garland')
      ? const DecorIndex()
      : await DecorIndex.load();
  final vanishing = await SceneArt.vanishingFor(bgAsset);
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
    vanishing: vanishing,
    // Decorations stand behind the people who are there in this picture.
    front: look.overlays.isEmpty ? null : await _loadOrNull(decor.maskFor(bgAsset)),
    decorShift: decor.shiftFor(bgAsset, vanishing),
    overlayLights: [for (final o in look.overlays) part == DayPart.day ? null : await _loadOrNull(decor.lightsFor(o))],
    ambience: await SceneAmbience.of(await bg, bgAsset),
    // Snow and drops take the light of the hour: bluish at night.
    trainWeatherTint: switch (part) {
      DayPart.day => const Color(0xFFFFFFFF),
      DayPart.evening => const Color(0xFFF2DCE2),
      DayPart.night => const Color(0xFF98A2C8),
    },
  );
}
