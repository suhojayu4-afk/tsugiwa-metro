part of 'pixel_scene.dart';

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

  /// The next passengers walk in to the door's queue while the track is
  /// empty (1 = standing there, as when the screen opens).
  late final AnimationController _gather = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _gatherMs),
    value: 1,
  );

  /// A train is coming: whoever is still on the way to the queue (or has to
  /// come at all, [fromStart]) hurries, to be there before it stops.
  void _hurry({bool fromStart = false}) {
    if (fromStart) _gather.value = 0;
    if (_gather.value >= 1) return;
    _gather.animateTo(1, duration: Duration(milliseconds: (4200 * (1 - _gather.value)).round()));
  }

  /// The picture shown before the current one, fading out under it
  /// ([_swap]) so a change of picture (weather, crowd, time of day) or the
  /// first picture does not pop in.
  SceneArtSet? _oldArt;
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
    value: 1,
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
      // The track is empty: the next passengers walk in to the queue.
      _gather.value = 0;
      _platform.reset();
      _gather.forward();
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
    _hurry();
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
    underground: _art?.underground ?? widget.look.showsUnderground,
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

  bool get _falling =>
      !(_art?.underground ?? false) && (widget.weather == WeatherKind.rain || widget.weather == WeatherKind.snow);

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
      // Those who got on the last train are gone: new ones hurry in.
      _hurry(fromStart: _platform.value > 0);
      _platform.reset();
      _arrive.forward(from: 0);
      widget.onArrive?.call();
    }
  }

  int _loads = 0;

  Future<void> _load() async {
    final part = _currentPart();
    _part = part;
    // A slower, older request must not replace the picture asked for later.
    final mine = ++_loads;
    final art = await loadSceneArt(widget.look, part, sky: widget.sky);
    if (!mounted || mine != _loads) return;
    final old = _art;
    if (old != null && identical(old.bg, art.bg)) {
      setState(() => _art = art);
      return;
    }
    // Another picture (or the first): it fades in over the one before.
    setState(() {
      _oldArt = old;
      _art = art;
    });
    _swap.forward(from: 0).whenComplete(() {
      if (mounted && _swap.value >= 1) setState(() => _oldArt = null);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _cycle?.cancel();
    _depart.dispose();
    _arrive.dispose();
    _platform.dispose();
    _gather.dispose();
    _swap.dispose();
    _frame.dispose();
    _life.dispose();
    _events.dispose();
    super.dispose();
  }

  _ScenePainter _painter(SceneArtSet art, SceneView view, ({ui.Image base, ui.Image stripe})? yellow) => _ScenePainter(
    view: view,
    bg: art.bg,
    trainBase: yellow?.base ?? art.base,
    trainStripe: yellow?.stripe ?? art.stripe,
    lamps: SceneArt.lampsOf(yellow != null ? _events.rareArt : widget.look.trainArt),
    hasLed: SceneArt.hasLed(yellow != null ? _events.rareArt : widget.look.trainArt),
    // At night the stripe is in shadow like the rest of the train.
    lineColor: stripeColor(widget.look.trainColor ?? widget.lineColor, art.part),
    weather: widget.weather ?? WeatherKind.sunny,
    life: _life,
    arrive: _arrive,
    platform: _platform,
    depart: _depart,
    gather: _gather,
    underground: art.underground,
    walkIn: art.walkIn,
    walkers: art.walkers,
    weathered: art.weathered,
    sky: art.sky,
    closed: art.closed,
    trainWeather: yellow != null ? null : art.trainWeather,
    trainWeatherTint: art.trainWeatherTint,
    graded: art.graded,
    overlays: art.overlays,
    // The rare yellow train carries no head mark.
    mark: yellow != null ? null : art.mark,
    markAt: SceneArt.markOf(widget.look.trainArt),
    skies: art.skies,
    effects: widget.look.effects,
    // The yellow train shows its own dark display.
    led: yellow != null ? const [] : widget.look.led,
    ledColors: widget.look.ledColors,
    sign: widget.look.sign,
    part: art.part,
    vanishing: art.vanishing,
    front: art.front,
    decorShift: art.decorShift,
    overlayLights: art.overlayLights,
    ambience: art.ambience,
    events: _events,
  );

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
                ? ColoredBox(color: PixelColors.soft)
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_oldArt == null && _swap.value < 1) ColoredBox(color: PixelColors.soft),
                      if (_oldArt != null) RepaintBoundary(child: CustomPaint(painter: _painter(_oldArt!, view, null))),
                      FadeTransition(
                        opacity: _swap,
                        child: RepaintBoundary(child: CustomPaint(painter: _painter(art, view, yellow))),
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
