import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/weather/weather_source.dart';
import 'pixel_scene.dart';

/// Little surprises on the platform (easter eggs): now and then, never two
/// at once and with a few minutes' rest between them, something happens in
/// the picture. The sprites were drawn by GPT in the station pictures' style
/// (tools/gen_scene_events_gpt.py → assets/art/events/).
enum SceneEventKind {
  /// A tabby cat strolls in along the platform, sits, swishes its tail, leaves (day, dusk).
  cat,

  /// Pigeons pecking on the platform; they flutter off when a train comes (day).
  pigeons,

  /// A station attendant walks to the edge and points at the arriving train
  /// (指差確認), then walks off. Starts with a train.
  staff,

  /// A shooting star or two (clear nights).
  shootingStar,

  /// A faint rainbow behind the buildings (day; likelier when cloudy).
  rainbow,

  /// A small airship drifting across the sky (day, dusk).
  blimp,

  /// Red dragonflies (赤とんぼ) darting over the track (Sep–Nov, day, dusk).
  dragonflies,
}

/// How long each event lasts on screen, in seconds.
const sceneEventSeconds = {
  SceneEventKind.cat: 17.0,
  SceneEventKind.pigeons: 26.0,
  SceneEventKind.staff: 10.0,
  SceneEventKind.shootingStar: 5.0,
  SceneEventKind.rainbow: 24.0,
  SceneEventKind.blimp: 40.0,
  SceneEventKind.dragonflies: 20.0,
};

/// About one train in this many is the yellow track-inspection train.
const yellowTrainOdds = 40;

/// The yellow inspection train's pictures (front_base_{part}, front_stripe…),
/// used like an equipped train's folder ([SceneLook.trainArt]).
const yellowTrainArt = 'assets/art/yellow_train';

/// Counts how often the yellow inspection train has stopped at the platform
/// on screen. Listen to it to award a badge (e.g. when it becomes 1).
final yellowTrainSightings = ValueNotifier<int>(0);

/// What the platform looks like now: which events can happen.
@immutable
class SceneEventConditions {
  const SceneEventConditions({required this.part, this.weather = WeatherKind.sunny, this.sky, this.month = 6});

  final DayPart part;
  final WeatherKind weather;

  /// The weather / crowd picture asked for ('rain', 'crowded', 'snow_many'…), as [PixelSceneBanner.sky].
  final String? sky;
  final int month;

  String? get _base => sky?.split('_').first;

  /// Raining or snowing: nobody (and no animal) comes out to play.
  bool get wet => weather == WeatherKind.rain || weather == WeatherKind.snow || _base == 'rain' || _base == 'snow';

  /// Grey skies in the picture or outside.
  bool get grey => wet || weather == WeatherKind.cloudy || _base == 'umbrella' || _base == 'snowsoon';

  /// The platform floor has room (not a crowd picture, not closed).
  bool get groundFree =>
      _base != 'closed' && _base != 'crowded' && _base != 'packed' && !(sky?.endsWith('_many') ?? false);

  bool get autumn => month >= 9 && month <= 11;

  /// How likely each event is now (0 = cannot happen).
  Map<SceneEventKind, int> get weights => {
    if (part != DayPart.night && !wet && groundFree) SceneEventKind.cat: 3,
    if (part == DayPart.day && !wet && groundFree) SceneEventKind.pigeons: 3,
    if (groundFree) SceneEventKind.staff: 2,
    if (part == DayPart.night && !grey) SceneEventKind.shootingStar: 4,
    if (part == DayPart.day && !wet && _base != 'umbrella' && _base != 'snowsoon')
      SceneEventKind.rainbow: weather == WeatherKind.cloudy ? 3 : 1,
    if (part != DayPart.night && !wet) SceneEventKind.blimp: 2,
    if (part != DayPart.night && !wet && autumn) SceneEventKind.dragonflies: 3,
  };
}

/// Picks the events: plain logic on a clock in seconds (only running while
/// the scene is on screen), so it can be tested without a widget.
class SceneEventScheduler {
  SceneEventScheduler({math.Random? random, this.firstGap = (60, 150), this.gap = (150, 300)})
    : random = random ?? math.Random() {
    _next = _between(firstGap);
  }

  final math.Random random;

  /// Seconds before the first event, and between events (min, max).
  final (int, int) firstGap, gap;

  late double _next;
  SceneEventKind? _active;
  double _start = 0;

  /// An attendant waiting for the next train to come in.
  double? _armedSince;

  SceneEventKind? get active => _active;
  bool get staffWaiting => _armedSince != null;

  /// When the event now showing started (scheduler clock).
  double get startedAt => _start;

  /// The earliest time the next event may start.
  double get nextAt => _next;

  double _between((int, int) r) => r.$1 + random.nextDouble() * (r.$2 - r.$1);

  /// Called a few times a second. Returns the event that starts now, if any.
  SceneEventKind? update(double now, SceneEventConditions c) {
    final a = _active;
    if (a != null) {
      if (now - _start < sceneEventSeconds[a]!) return null;
      finish(now);
    }
    if (_armedSince != null) {
      // No train came for a while: try again a bit later.
      if (now - _armedSince! > 90) {
        _armedSince = null;
        _next = now + _between((30, 60));
      }
      return null;
    }
    if (now < _next) return null;
    final weights = c.weights;
    final total = weights.values.fold(0, (s, w) => s + w);
    if (total == 0) {
      _next = now + 30;
      return null;
    }
    var pick = random.nextInt(total);
    for (final e in weights.entries) {
      pick -= e.value;
      if (pick >= 0) continue;
      if (e.key == SceneEventKind.staff) {
        _armedSince = now;
        return null;
      }
      return start(e.key, now);
    }
    return null;
  }

  /// Starts [kind] now (also for previews and tests).
  SceneEventKind start(SceneEventKind kind, double now) {
    _active = kind;
    _start = now;
    _armedSince = null;
    return kind;
  }

  /// The event is over: rest a while before the next one.
  void finish(double now) {
    _active = null;
    _next = now + _between(gap);
  }

  /// A train starts pulling in. Returns the attendant's event when one was
  /// waiting for it.
  SceneEventKind? trainComing(double now, SceneEventConditions c) {
    if (_armedSince == null || _active != null) return null;
    if (!c.groundFree) {
      _armedSince = null;
      _next = now + _between((30, 60));
      return null;
    }
    return start(SceneEventKind.staff, now);
  }

  /// Whether the train now coming is the rare yellow inspection train.
  bool pickYellowTrain() => random.nextInt(yellowTrainOdds) == 0;
}

/// Runs the events in the platform banner and draws them: a [Listenable]
/// that ticks smoothly only while an event is showing.
class SceneEventDirector extends ChangeNotifier {
  SceneEventDirector({TickerProvider? vsync, math.Random? random})
    : scheduler = SceneEventScheduler(random: random),
      _random = random ?? math.Random() {
    _ticker = vsync?.createTicker(_onTick);
  }

  /// A still preview of [kind] at [time] seconds into it (render tools).
  /// [scareAt]: when the pigeons' train comes (seconds into the event).
  SceneEventDirector.preview(SceneEventKind kind, double time, {double? scareAt, int seed = 7})
    : scheduler = SceneEventScheduler(random: math.Random(seed)),
      _random = math.Random(seed) {
    scheduler.start(kind, 0);
    _kind = kind;
    _time = time;
    _scareAt = scareAt;
    _seed = seed;
  }

  final SceneEventScheduler scheduler;
  final math.Random _random;
  Ticker? _ticker;

  /// Seconds the scene has been on screen (advanced by [onLife]).
  double _clock = 0;
  SceneEventKind? _kind;
  double _time = 0;
  double? _scareAt;
  int _seed = 0;

  /// The event showing now and how far into it (seconds).
  SceneEventKind? get kind => _kind;
  double get time => _time;

  /// For debugging and previews: the next train is the yellow one.
  static bool forceYellow = false;

  final _art = <String, ui.Image>{};
  Future<void>? _loading;

  static const _sprites = ['cat', 'pigeon', 'staff', 'staff_toward', 'staff_away', 'blimp'];

  Future<void> _ensureArt() => _loading ??= () async {
    Future<void> get(String key, String asset) async {
      try {
        _art[key] = await SceneArt.load(asset);
      } catch (_) {
        SceneArt.forget(asset);
      }
    }

    await Future.wait([
      for (final s in _sprites) get(s, 'assets/art/events/$s.png'),
      for (final p in DayPart.values) get('yellow_${p.name}', SceneArt.trainBase(p, yellowTrainArt)),
      get('yellow_stripe', SceneArt.trainStripeOf(yellowTrainArt)),
    ]);
  }();

  /// Loads the sprites and works out the sky of [bg] (needed before a
  /// one-off render; the banner does it on the fly).
  Future<void> prepare(ui.Image bg) async {
    await _ensureArt();
    await _SkyMask.of(bg);
  }

  /// The ambient clock ticked (every 320 ms while the scene is on screen).
  void onLife(SceneEventConditions c) {
    _ensureArt();
    _clock += 0.32;
    final was = _kind;
    scheduler.update(_clock, c);
    _sync(was);
  }

  /// A train starts pulling in. Returns true when it is the yellow
  /// inspection train (then draw it with [yellowTrain]).
  bool trainComing(SceneEventConditions c) {
    final was = _kind;
    scheduler.trainComing(_clock, c);
    _sync(was);
    // The pigeons take off as the train gets close.
    if (_kind == SceneEventKind.pigeons && _scareAt == null) _scareAt = _time + 2.2;
    final yellow = forceYellow || scheduler.pickYellowTrain();
    return yellow && yellowTrain(DayPart.day) != null;
  }

  /// The yellow train has stopped at the platform: one more sighting.
  void yellowTrainArrived() => yellowTrainSightings.value++;

  /// The yellow train's pictures for [part], once loaded.
  ({ui.Image base, ui.Image stripe})? yellowTrain(DayPart part) {
    final base = _art['yellow_${part.name}'], stripe = _art['yellow_stripe'];
    return base == null || stripe == null ? null : (base: base, stripe: stripe);
  }

  void _sync(SceneEventKind? was) {
    final now = scheduler.active;
    if (now == was) return;
    _kind = now;
    _time = 0;
    _scareAt = null;
    _seed = _random.nextInt(1 << 20);
    if (now != null) {
      _ticker?.stop();
      _ticker?.start();
    } else {
      _ticker?.stop();
    }
    notifyListeners();
  }

  void _onTick(Duration elapsed) {
    final k = _kind;
    if (k == null) return;
    _time = math.min(elapsed.inMicroseconds / 1e6, sceneEventSeconds[k]!);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- drawing

  /// Things in the sky: drawn over the picture, under the train.
  void paintSky(Canvas canvas, {required ui.Image bg, required DayPart part}) {
    switch (_kind) {
      case SceneEventKind.shootingStar:
        _shootingStars(canvas);
      case SceneEventKind.rainbow:
        _rainbow(canvas, bg);
      case SceneEventKind.blimp:
        _blimp(canvas, part);
      default:
        break;
    }
  }

  /// Things on the platform: drawn over the waiting passengers. [vanishing]
  /// is where the picture's rails meet (the floor's horizon is just below).
  void paintGround(
    Canvas canvas, {
    required DayPart part,
    required Offset vanishing,
    WeatherKind weather = WeatherKind.sunny,
    String? sky,
  }) {
    final k = _kind;
    if (k == null || k == SceneEventKind.shootingStar || k == SceneEventKind.rainbow || k == SceneEventKind.blimp) {
      return;
    }
    final horizon = vanishing.dy + 2.6;
    final ground = _Ground(horizon, _tint(part, weather == WeatherKind.rain || sky == 'rain'));
    switch (k) {
      case SceneEventKind.cat:
        _cat(canvas, ground);
      case SceneEventKind.pigeons:
        _pigeons(canvas, ground);
      case SceneEventKind.staff:
        _staff(canvas, ground);
      case SceneEventKind.dragonflies:
        _dragonflies(canvas, ground);
      default:
        break;
    }
  }

  /// Light of the hour on the sprites (as the waiting passengers).
  static Color? _tint(DayPart part, bool wet) {
    final light = switch (part) {
      DayPart.day => null,
      DayPart.evening => const Color(0xFFF0DCD8),
      DayPart.night => const Color(0xFF8E96B8),
    };
    return wet ? Color.lerp(light ?? const Color(0xFFFFFFFF), const Color(0xFFADB5C6), 0.6) : light;
  }

  /// Draws frame [frame] of the strip [img] ([frames] side by side) with its
  /// bottom middle at [foot], [h] tall; [flip] = facing the other way.
  void _sprite(
    Canvas canvas,
    ui.Image img,
    int frames,
    int frame,
    Offset foot,
    double h, {
    bool flip = false,
    Color? tint,
    double alpha = 1,
    bool shadow = true,
    double shadowWidth = 0.9,
  }) {
    final fw = img.width / frames;
    final k = h / img.height;
    final w = fw * k;
    if (shadow) {
      canvas.drawOval(
        Rect.fromCenter(center: foot, width: math.min(w * 0.6, h * shadowWidth), height: math.max(1.2, h * 0.07)),
        Paint()..color = Color.fromRGBO(20, 16, 24, 0.26 * alpha),
      );
    }
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..color = Color.fromRGBO(0, 0, 0, alpha);
    if (tint != null) paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    // Whole art pixels: no shimmer as it moves.
    final x = foot.dx.roundToDouble(), y = foot.dy.roundToDouble();
    canvas.save();
    if (flip) {
      canvas.translate(x, 0);
      canvas.scale(-1, 1);
      canvas.translate(-x, 0);
    }
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(frame * fw, 0, fw, img.height.toDouble()),
      Rect.fromLTWH(x - (w / 2).roundToDouble(), y - h.roundToDouble(), w.roundToDouble(), h.roundToDouble()),
      paint,
    );
    canvas.restore();
  }

  static double _smooth(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// The cat: in from the right along the free floor between the yellow
  /// line and the waiting people, stops, sits down and swishes its tail,
  /// then strolls back out.
  void _cat(Canvas canvas, _Ground g) {
    final img = _art['cat'];
    if (img == null) return;
    final t = _time;
    final foot = g.at(const Offset(0, 160));
    const out = 398.0, stop = 326.0;
    double x;
    int frame;
    var flip = false;
    if (t < 5) {
      // Walking in, slowing for the last steps.
      final u = t / 5;
      x = out + (stop - out) * (u < 0.8 ? u / 0.8 * 0.9 : 0.9 + 0.1 * _smooth((u - 0.8) / 0.2));
      frame = (t * 6).floor() % 4;
      if (u > 0.96) frame = 4;
    } else if (t < 11.6) {
      x = stop;
      final s = t - 5;
      if (s < 0.7) {
        frame = 4; // stops and looks at us
      } else {
        // Sitting: the tail swishes now and then; a happy blink.
        final beat = ((s - 0.7) / 0.42).floor();
        frame = switch (beat % 9) {
          1 || 3 => 6,
          6 || 7 => 7,
          _ => 5,
        };
      }
    } else if (t < 12.2) {
      x = stop;
      frame = 4;
    } else {
      final u = (t - 12.2) / 4.8;
      x = stop + (out - stop) * u;
      frame = ((t - 12.2) * 6).floor() % 4;
      flip = true;
    }
    final f = Offset(x, foot.dy);
    // It comes out from behind the near pillar at the right edge.
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 0, 371, SceneArt.height * 1.0));
    _sprite(canvas, img, 8, frame, f, g.person(f.dy) * 0.27, flip: flip, tint: g.tint);
    canvas.restore();
  }

  /// Three pigeons pecking about; when a train comes (or at the end) they
  /// take off one after another, up and away from the track.
  void _pigeons(Canvas canvas, _Ground g) {
    final img = _art['pigeon'];
    if (img == null) return;
    final t = _time;
    final total = sceneEventSeconds[SceneEventKind.pigeons]!;
    final scare = _scareAt ?? total - 2.4;
    const homes = [Offset(298, 145), Offset(334, 149), Offset(314, 158)];
    // They walk in from the edge of the roof (a short hop down) first.
    final arrive = _smooth(t / 1.4);
    // Paint the farther ones first.
    for (final i in const [0, 1, 2]) {
      final r = math.Random(_seed + i * 101);
      final home = homes[i] + Offset(r.nextDouble() * 6 - 3, r.nextDouble() * 2 - 1);
      final flyT = t - scare - i * 0.22;
      // On the ground: stand, peck, step. They only move while stepping,
      // a few steps one way, then back.
      final clock = t * 2.4 + i * 1.3;
      final beat = clock.floor();
      final frame = switch ((beat + i) % 5) {
        0 => 0,
        1 || 3 => 1,
        _ => 2,
      };
      // Steps taken so far (each stepping beat moves smoothly).
      var steps = 0.0;
      for (var b = 0; b <= beat; b++) {
        if ((b + i) % 5 == 2 || (b + i) % 5 == 4) steps += b == beat ? clock - beat : 1;
      }
      final leg = (steps / 4).floor();
      final along = steps - leg * 4;
      final facingRight = leg.isEven;
      final wander = (leg.isEven ? along : 4 - along) * 1.6 - 3;
      var foot = g.at(home + Offset(wander, 0));
      final h = g.person(foot.dy) * 0.3;
      if (flyT > 0) {
        // Flying off: up and to the right, faster and faster, wings beating.
        final dx = flyT * 46 + flyT * flyT * 30;
        final dy = flyT * 38 + flyT * flyT * 46;
        final frame = 3 + (flyT * 14).floor() % 3;
        if (dy > 150) continue;
        _sprite(canvas, img, 6, frame, foot + Offset(dx, -dy), h, flip: true, tint: g.tint, shadow: false);
        continue;
      }
      if (arrive < 1) {
        // Gliding down in from above.
        final u = arrive;
        foot = foot + Offset((1 - u) * 40, -(1 - u) * 60);
        _sprite(canvas, img, 6, 3 + (t * 12).floor() % 3, foot, h, flip: false, tint: g.tint, shadow: u > 0.8);
        continue;
      }
      _sprite(canvas, img, 6, frame, foot, h, flip: facingRight, tint: g.tint);
    }
  }

  /// The station attendant: walks out along the platform edge (the strip
  /// between the edge and the yellow line, which is empty in every station
  /// picture: people queue behind the line), stops on the yellow line,
  /// points at the arriving train (指差確認) and walks back down the platform.
  void _staff(Canvas canvas, _Ground g) {
    // Side view (standing, 指差確認 towards the train), and the walk seen
    // three-quarter from the front (coming up the platform towards us) and
    // from behind (going back down it).
    final img = _art['staff'];
    if (img == null) return;
    final toward = _art['staff_toward'], away = _art['staff_away'];
    final t = _time;
    // Far down the platform edge → on the yellow line nearer the camera.
    const from = Offset(249, 103), spot = Offset(277, 140);
    Offset foot;
    var sheet = img;
    var frames = 8;
    int frame;
    var flip = false;
    if (t < 2.2) {
      final u = t / 2.2;
      foot = Offset.lerp(from, spot, u < 0.85 ? u / 0.85 * 0.94 : 0.94 + 0.06 * _smooth((u - 0.85) / 0.15))!;
      if (toward != null) {
        (sheet, frames) = (toward, 6);
        frame = (t * 7.5).floor() % 6;
      } else {
        frame = (t * 7.5).floor() % 6;
        flip = true;
      }
    } else if (t < 2.5) {
      foot = spot;
      frame = 6;
    } else if (t < 4.7) {
      foot = spot;
      frame = 7; // 指差確認, as the train pulls in
    } else if (t < 5.8) {
      foot = spot;
      frame = 6;
    } else {
      final u = ((t - 5.8) / 3.6).clamp(0.0, 1.0);
      foot = Offset.lerp(spot, from, u)!;
      final walk = ((t - 5.8) * 7.5).floor() % 6;
      if (away != null) {
        (sheet, frames) = (away, 6);
      }
      frame = walk;
    }
    final f = g.at(foot);
    _sprite(canvas, sheet, frames, frame, f, g.person(f.dy), flip: flip, tint: g.tint, shadowWidth: 0.3);
  }

  /// Red dragonflies: hover, dart to a new spot, hover again.
  void _dragonflies(Canvas canvas, _Ground g) {
    final t = _time;
    final total = sceneEventSeconds[SceneEventKind.dragonflies]!;
    final fade = math.min(1.0, math.min(t / 1.5, (total - t) / 1.5));
    if (fade <= 0) return;
    final red = Color.lerp(const Color(0xFFE8432A), g.tint ?? const Color(0xFFE8432A), 0.2)!;
    final body = Paint()..color = red.withValues(alpha: fade);
    final dark = Paint()..color = const Color(0xFF7A2418).withValues(alpha: fade);
    final wing = Paint()..color = Color.fromRGBO(236, 244, 255, 0.6 * fade);
    for (var i = 0; i < 4; i++) {
      final r = math.Random(_seed + i * 37);
      // Spots to hover at, over the track and the platform edge.
      final spots = [for (var k = 0; k < 8; k++) Offset(120 + r.nextDouble() * 200, 50 + r.nextDouble() * 75)];
      final hold = 1.6 + r.nextDouble() * 1.2;
      final step = (t + i * 0.7) / hold;
      final k = step.floor();
      final u = step - k;
      final a = spots[k % spots.length], b = spots[(k + 1) % spots.length];
      // Hover (tiny jitter), then a quick dart over the last fifth.
      final dart = u > 0.8 ? _smooth((u - 0.8) / 0.2) : 0.0;
      var p = Offset.lerp(a, b, dart)! + Offset(math.sin(t * 9 + i) * 0.6, math.cos(t * 7 + i * 2) * 0.6);
      // Coming in from the left at the start and leaving upwards at the end.
      if (t < 1.5) p += Offset(-(1.5 - t) * 60, 0);
      if (total - t < 1.5) p += Offset(0, -(1.5 - (total - t)) * 50);
      final x = p.dx.roundToDouble(), y = p.dy.roundToDouble();
      // Facing where it darts next; drawn facing right, mirrored otherwise.
      final right = (b.dx - a.dx) > 0;
      canvas.save();
      if (!right) {
        canvas.translate(x * 2 + 1, 0);
        canvas.scale(-1, 1);
      }
      // Seen from above: a red body with two pairs of glassy wings beating
      // (spread wide, then folded short); [x, y] is the head.
      final spread = ((t * 16).floor() + i) % 2 == 0;
      final rows = spread ? _dragonflyOpen : _dragonflyShut;
      for (var ry = 0; ry < rows.length; ry++) {
        for (var rx = 0; rx < rows[ry].length; rx++) {
          final paint = switch (rows[ry][rx]) {
            'R' => body,
            'H' => dark,
            'w' => wing,
            _ => null,
          };
          if (paint == null) continue;
          canvas.drawRect(Rect.fromLTWH(x - 10 + rx, y - 3 + ry, 1, 1), paint);
        }
      }
      canvas.restore();
    }
  }

  /// One shooting star, then (sometimes) a smaller one: a bright head and a
  /// fading tail streaking down across the sky.
  void _shootingStars(Canvas canvas) {
    final r = math.Random(_seed);
    final stars = [
      (at: 0.4, x: 150 + r.nextDouble() * 70, y: 6 + r.nextDouble() * 12, len: 1.0),
      if (r.nextBool()) (at: 2.6, x: 90 + r.nextDouble() * 70, y: 10 + r.nextDouble() * 14, len: 0.6),
    ];
    final p = Paint();
    for (final s in stars) {
      final u = (_time - s.at) / (0.9 * s.len + 0.3);
      if (u < 0 || u > 1.25) continue;
      const dir = Offset(-0.91, 0.42);
      final travel = 90 * s.len;
      final head = Offset(s.x, s.y) + dir * (travel * math.min(u, 1));
      // Bright as it streaks, then it fades away where it ends.
      final glow = u < 1 ? math.min(1.0, u * 5) : 1 - (u - 1) / 0.25;
      final tail = 26 * s.len * (u < 1 ? math.min(1.0, u * 3) : 1 - (u - 1) / 0.25);
      for (var k = 0; k < tail; k++) {
        final q = head - dir * k.toDouble();
        p.color = Color.fromRGBO(255, 244, 214, glow * (1 - k / tail) * 0.85);
        canvas.drawRect(Rect.fromLTWH(q.dx.roundToDouble(), q.dy.roundToDouble(), 1, 1), p);
      }
      p.color = Color.fromRGBO(255, 255, 240, glow);
      canvas.drawRect(Rect.fromLTWH(head.dx.roundToDouble(), head.dy.roundToDouble(), 2, 1), p);
      p.color = Color.fromRGBO(255, 255, 240, glow * 0.35);
      canvas.drawRect(Rect.fromLTWH(head.dx.roundToDouble() - 1, head.dy.roundToDouble() - 1, 4, 3), p);
    }
  }

  /// A rainbow behind the buildings: fades in, stays a while, fades out.
  void _rainbow(Canvas canvas, ui.Image bg) {
    final mask = _SkyMask.cached(bg);
    if (mask == null) {
      _SkyMask.of(bg);
      return;
    }
    final total = sceneEventSeconds[SceneEventKind.rainbow]!;
    final a = math.min(1.0, math.min(_time / 5, (total - _time) / 5));
    if (a <= 0) return;
    canvas.drawImage(
      mask.rainbow,
      Offset.zero,
      Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(0, 0, 0, a),
    );
  }

  /// A little airship drifting right to left high in the sky, its propeller turning.
  void _blimp(Canvas canvas, DayPart part) {
    final img = _art['blimp'];
    if (img == null) return;
    final total = sceneEventSeconds[SceneEventKind.blimp]!;
    final u = _time / total;
    final x = 270 - u * 350;
    final y = 22 + math.sin(_time * 0.6) * 0.7;
    // It comes out from behind the platform roof (its edge is at about x 244).
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 0, 244, SceneArt.height * 1.0));
    _sprite(
      canvas,
      img,
      2,
      (_time * 7).floor() % 2,
      Offset(x, y),
      img.height.toDouble(),
      tint: switch (part) {
        DayPart.evening => const Color(0xFFF4D2C8),
        _ => null,
      },
      shadow: false,
    );
    canvas.restore();
  }
}

/// A red dragonfly from above, facing right (11×7): wings spread / folded.
const _dragonflyOpen = [
  '...ww.ww...',
  '..www.www..',
  '.wwww.www..',
  'RRRRRRRRRHH',
  '.wwww.www..',
  '..www.www..',
  '...ww.ww...',
];
const _dragonflyShut = [
  '...........',
  '...........',
  '...ww.ww...',
  'RRRRRRRRRHH',
  '...ww.ww...',
  '...........',
  '...........',
];

/// The platform floor of one picture: perspective sizes and positions.
/// Places are given for the pictures whose floor horizon is at row 92 and
/// shift with this picture's horizon (as the waiting passengers).
class _Ground {
  _Ground(this.horizon, this.tint);
  final double horizon;
  final Color? tint;

  Offset at(Offset p) => Offset(p.dx, p.dy + horizon - 92);

  /// A person's height standing at [footY].
  double person(double footY) => 1.33 * (footY - horizon);
}

/// The open sky of a picture (alpha = sky), found from its colours: the sky
/// reached from the top edge without crossing a hard edge gives each row's
/// sky colour, then every pixel close to its row's colour is sky (so it also
/// shows between buildings and wires). With a rainbow drawn behind it.
class _SkyMask {
  _SkyMask(this.rainbow);
  final ui.Image rainbow;

  static final _done = Expando<_SkyMask>();
  static final _pending = Expando<Future<_SkyMask?>>();

  static _SkyMask? cached(ui.Image bg) => _done[bg];

  static Future<_SkyMask?> of(ui.Image bg) => _pending[bg] ??= () async {
    const w = SceneArt.width, h = 110, cols = 250;
    final data = await bg.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null || bg.width != w) return null;
    int at(int x, int y, int c) => data.getUint8((y * w + x) * 4 + c);
    int diff(int x0, int y0, int x1, int y1) =>
        (at(x0, y0, 0) - at(x1, y1, 0)).abs() +
        (at(x0, y0, 1) - at(x1, y1, 1)).abs() +
        (at(x0, y0, 2) - at(x1, y1, 2)).abs();
    // Flood from the top row.
    final seen = Uint8List(cols * h);
    final queue = <int>[for (var x = 0; x < cols; x++) x];
    for (var x = 0; x < cols; x++) {
      seen[x] = 1;
    }
    final rows = List.generate(h, (_) => <int>[]);
    for (var i = 0; i < queue.length; i++) {
      final x = queue[i] % cols, y = queue[i] ~/ cols;
      rows[y].add(x);
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final xx = x + dx, yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= cols || yy >= h || seen[yy * cols + xx] == 1) continue;
        if (diff(x, y, xx, yy) < 30) {
          seen[yy * cols + xx] = 1;
          queue.add(yy * cols + xx);
        }
      }
    }
    // Each row's sky colour: the median of the flooded sky near that row.
    final pixels = Uint8List(w * SceneArt.height * 4);
    List<int>? ref;
    for (var y = 0; y < h; y++) {
      final rs = <int>[], gs = <int>[], bs = <int>[];
      for (var yy = math.max(0, y - 4); yy <= math.min(h - 1, y + 4); yy++) {
        for (final x in rows[yy]) {
          rs.add(at(x, yy, 0));
          gs.add(at(x, yy, 1));
          bs.add(at(x, yy, 2));
        }
      }
      if (rs.length >= 6) {
        int mid(List<int> v) => (v..sort())[v.length ~/ 2];
        ref = [mid(rs), mid(gs), mid(bs)];
      }
      if (ref == null) continue;
      for (var x = 0; x < cols; x++) {
        final d = (at(x, y, 0) - ref[0]).abs() + (at(x, y, 1) - ref[1]).abs() + (at(x, y, 2) - ref[2]).abs();
        if (d < 40) pixels[(y * w + x) * 4 + 3] = 255;
      }
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, w, SceneArt.height, ui.PixelFormat.rgba8888, done.complete);
    final mask = await done.future;
    // The rainbow, pixel by pixel, kept to the sky.
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    const full = Rect.fromLTWH(0, 0, w * 1.0, SceneArt.height * 1.0);
    c.saveLayer(full, Paint());
    const bands = [
      Color(0x8CFF6A5A),
      Color(0x8CFFA552),
      Color(0x8CFFE070),
      Color(0x8C82D47A),
      Color(0x8C6CB4F0),
      Color(0x8C8A86E0),
      Color(0x73B48AE0),
    ];
    const centre = Offset(128, 156), outer = 140.0;
    final p = Paint();
    for (var x = 0; x < cols; x++) {
      for (var b = 0; b < bands.length; b++) {
        final r = outer - b * 1.5;
        final dx = x - centre.dx;
        if (dx.abs() >= r) continue;
        final y = centre.dy - math.sqrt(r * r - dx * dx);
        // Softer towards the ends, where the arc meets the haze.
        final end = ((centre.dy - y) / 60).clamp(0.0, 1.0);
        p.color = bands[b].withValues(alpha: bands[b].a * end);
        c.drawRect(Rect.fromLTWH(x.toDouble(), y.floorToDouble(), 1, 2), p);
      }
    }
    c.drawImage(mask, Offset.zero, Paint()..blendMode = BlendMode.dstIn);
    c.restore();
    final rainbow = recorder.endRecording().toImageSync(w, SceneArt.height);
    mask.dispose();
    return _done[bg] = _SkyMask(rainbow);
  }();
}
