import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../data/models/city.dart';
import '../../data/models/rail_line.dart';
import '../../data/models/route_map.dart';
import '../../l10n/app_localizations.dart';
import '../platform/station_picker.dart';

/// Called when the user picks "出発にする" (from = true) or "到着にする".
typedef UseStation = void Function(String stationId, {required bool from});

/// 路線図 tab: a flat pixel-terrain map with clean straight / 45° lines and
/// 3D pixel landmarks. Pinch to zoom; one tap zooms in there; tapping a
/// station opens its card (transfers, tips, set as start / destination).
class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key, required this.city, this.onUseStation});
  final CityData city;
  final UseStation? onUseStation;

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> with TickerProviderStateMixin {
  /// Drives the twinkling sea glints (stops while the tab is hidden).
  late final AnimationController _twinkle = AnimationController(vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  /// Moving pictures (Ferris wheels, whales, steam): 8 frames, 140 ms each.
  late final AnimationController _scenery = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 8 * 140),
  )..repeat();

  final _controller = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  Animation<Matrix4>? _zoom;

  RouteMapData? _map;
  ui.Image? _terrain;
  ui.Image? _outer;
  final _landmarkImages = <String, ui.Image>{};
  Size? _viewport;
  bool _fitted = false;
  String? _selected;
  String? _focusLine;

  static const _maxScale = 4.0;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      final z = _zoom;
      if (z != null) _controller.value = z.value;
    });
    _controller.addListener(_keepOuterZoom);
    _controller.addListener(_loadTiles);
    _load();
  }

  Future<void> _load() async {
    final map = await RouteMapData.load(widget.city.id);
    final terrain = await _image(map.terrainImage);
    final outer = map.outer == null ? null : await _image(map.outer!.image);
    for (final lm in map.landmarks) {
      _landmarkImages[lm.image] = await _image(lm.image);
    }
    for (final d in map.decor) {
      _landmarkImages[d.image] ??= await _image(d.image);
    }
    if (!mounted) return;
    setState(() {
      _map = map;
      _terrain = terrain;
      _outer = outer;
    });
  }

  static Future<ui.Image> _image(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  @override
  void dispose() {
    _anim.dispose();
    _twinkle.dispose();
    _scenery.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---------------- zoom helpers ----------------

  /// Map zoom (x scale). Not getMaxScaleOnAxis(): the unused z axis stays 1
  /// and would hide any zoom below 1.
  double get _scale => _controller.value.storage[0];

  double _fitScale() {
    final map = _map!, vp = _viewport!;
    final b = map.contentBounds;
    // Station names are drawn at screen size beside the stops, so keep a
    // fixed on-screen margin for them on the left and right.
    final w = b.max.dx - b.min.dx + 50, h = b.max.dy - b.min.dy + 60;
    // A phone held upright: fill the height (all of Kanto top to bottom) and
    // let the sides be panned, instead of a thin band in the middle.
    if (vp.height > vp.width) return (vp.height - 190) / h;
    return math.min((vp.width - 130) / w, (vp.height - 190) / h);
  }

  /// Matrix that shows world point [center] at [screenAt] (default: middle) at [scale].
  Matrix4 _matrixFor(Offset center, double scale, {Offset? screenAt}) {
    final vp = _viewport!;
    final at = screenAt ?? Offset(vp.width / 2, vp.height / 2);
    return Matrix4.identity()
      ..translateByDouble(at.dx - center.dx * scale, at.dy - center.dy * scale, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _animateTo(Matrix4 target) {
    _zoom = Matrix4Tween(
      begin: _controller.value.clone(),
      end: target,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0);
  }

  void _fitAll({bool animate = true}) {
    final b = _map!.contentBounds;
    final center = Offset((b.min.dx + b.max.dx) / 2, (b.min.dy + b.max.dy) / 2);
    final vp = _viewport!;
    // A little below the middle, to leave room for the top bar.
    final m = _matrixFor(center, _fitScale(), screenAt: Offset(vp.width / 2, vp.height / 2 + 30));
    if (animate) {
      _animateTo(m);
    } else {
      _controller.value = m;
    }
  }

  /// First view: central Tokyo (round the Yamanote Line); the whole area,
  /// Yokohama to Narita, is one tap on "fit all" away.
  void _fitCentre() {
    final map = _map!, vp = _viewport!;
    final ring = map.lines.where((l) => l.lineId == 'tokyo.yamanote').firstOrNull;
    if (ring == null) return _fitAll(animate: false);
    final b = ring.bounds.inflate(120);
    final s = math.min((vp.width - 40) / b.width, (vp.height - 190) / b.height);
    _controller.value = _matrixFor(b.center, s, screenAt: Offset(vp.width / 2, vp.height / 2 + 30));
  }

  /// Outside the detailed Tokyo-area picture the ground has big pixels
  /// (the rest of Kanto): zooming in that far only shows blocks.
  /// Out in the countryside (outside the detailed Tokyo tiles) the ground is
  /// coarser: zoom up to 2 there.
  static const _outerMaxScale = 2.0;

  // ---------------- tiles (only the ones on screen are in memory) ----------------

  final _tiles = <String, ui.Image>{};
  final _tileLoading = <String>{};
  final _tileUsed = <String, int>{};
  int _tileClock = 0;
  static const _keepTiles = 24;

  void _loadTiles() {
    final map = _map, vp = _viewport;
    if (map == null || vp == null) return;
    final a = _toWorld(Offset.zero), b = _toWorld(Offset(vp.width, vp.height));
    final view = Rect.fromPoints(a, b);
    _tileClock++;
    final fine = map.tileSets.isEmpty ? null : map.tileSets.last;
    for (final set in map.tileSets) {
      if (_scale < set.from) continue;
      final span = set.span;
      for (var ty = ((view.top - set.origin.dy) / span).floor(); ty <= ((view.bottom - set.origin.dy) / span).floor(); ty++) {
        for (var tx = ((view.left - set.origin.dx) / span).floor();
            tx <= ((view.right - set.origin.dx) / span).floor();
            tx++) {
          final asset = set.asset(tx, ty);
          if (asset == null) continue;
          // Under the finer Tokyo tiles a coarse tile is not needed.
          final r = Rect.fromLTWH(set.origin.dx + tx * span, set.origin.dy + ty * span, span, span);
          if (fine != null && set != fine && _scale >= fine.from && fine.area.contains(r.topLeft) &&
              fine.area.contains(r.bottomRight)) {
            continue;
          }
          _tileUsed[asset] = _tileClock;
          if (_tiles.containsKey(asset) || !_tileLoading.add(asset)) continue;
          _image(asset).then((img) {
            _tileLoading.remove(asset);
            if (!mounted) return img.dispose();
            setState(() => _tiles[asset] = img);
            _forgetOldTiles();
          });
        }
      }
    }
  }

  /// Keep memory small: drop the tiles not seen for longest.
  void _forgetOldTiles() {
    if (_tiles.length <= _keepTiles) return;
    final old = (_tiles.keys.toList()..sort((x, y) => (_tileUsed[x] ?? 0) - (_tileUsed[y] ?? 0)))
        .take(_tiles.length - _keepTiles)
        .toList();
    for (final k in old) {
      _tiles.remove(k)?.dispose();
    }
  }

  /// The most zoom that still looks good with [world] in the middle.
  double _maxScaleAt(Offset world) {
    final map = _map;
    if (map == null) return _maxScale;
    return map.detailArea.contains(world) ? _maxScale : _outerMaxScale;
  }

  bool _clamping = false;

  /// Pinch zoom too: pull back to [_outerMaxScale] out in the countryside.
  void _keepOuterZoom() {
    if (_clamping || _map == null || _terrain == null || _viewport == null) return;
    final vp = _viewport!;
    final centre = _toWorld(Offset(vp.width / 2, vp.height / 2));
    final limit = _maxScaleAt(centre);
    if (_scale <= limit + 1e-6) return;
    _clamping = true;
    _controller.value = _matrixFor(centre, limit);
    _clamping = false;
  }

  Offset _toWorld(Offset screen) => MatrixUtils.transformPoint(Matrix4.inverted(_controller.value), screen);

  void _zoomBy(double factor) {
    final vp = _viewport!;
    final centre = _toWorld(Offset(vp.width / 2, vp.height / 2));
    final s = (_scale * factor).clamp(_fitScale() * 0.7, _maxScaleAt(centre));
    _animateTo(_matrixFor(centre, s));
  }

  // ---------------- taps ----------------

  void _onTap(TapUpDetails d) {
    final map = _map;
    if (map == null) return;
    final world = _toWorld(d.localPosition);
    MapStop? best;
    var bestDist = double.infinity;
    for (final stop in map.allStops) {
      final dist = (stop.position - world).distance * _scale;
      if (dist < bestDist) {
        bestDist = dist;
        best = stop;
      }
    }
    if (best != null && bestDist < 26) {
      _openStation(best.stationId);
      return;
    }
    // Empty spot: zoom in there.
    final s = math.min(_maxScaleAt(world), math.max(_scale * 2.2, _fitScale() * 2.5));
    _animateTo(_matrixFor(world, s));
  }

  Future<void> _search() async {
    final id = await pickStation(context, widget.city);
    if (id == null || !mounted) return;
    _openStation(id);
  }

  Future<void> _openStation(String id) async {
    final stops = _map!.stopsOf(id);
    if (stops.isEmpty) return;
    setState(() => _selected = id);
    // Bring the station into the upper part of the screen, above the card.
    final vp = _viewport!;
    final s = math.min(math.max(_scale, 1.6), _maxScaleAt(stops.first.position));
    _animateTo(_matrixFor(stops.first.position, s, screenAt: Offset(vp.width / 2, vp.height * 0.28)));
    final from = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PixelColors.card,
      barrierColor: const Color(0x22000000),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _StationSheet(city: widget.city, map: _map!, stationId: id),
    );
    if (!mounted) return;
    setState(() => _selected = null);
    if (from != null) widget.onUseStation?.call(id, from: from);
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final map = _map, terrain = _terrain;
    return LayoutBuilder(
      builder: (context, box) {
        _viewport = box.biggest;
        if (map != null && !_fitted) {
          _fitted = true;
          _fitCentre();
        }
        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xFFF3F2EC),
                  child: map == null || terrain == null
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTapUp: _onTap,
                          child: InteractiveViewer(
                            transformationController: _controller,
                            constrained: false,
                            minScale: 0.02, // the whole of Kanto with a little round it
                            maxScale: _maxScale,
                            boundaryMargin: const EdgeInsets.all(3000), // the surroundings reach 3000 units out
                            onInteractionStart: (_) => _anim.stop(),
                            child: SizedBox(
                              width: map.size.width,
                              height: map.size.height,
                              // The ground is its own layer, drawn again only when a tile
                              // comes in; the twinkling glints repaint on their own above it.
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        painter: _TerrainPainter(
                                          terrain,
                                          map.size,
                                          tiles: _tiles,
                                          tileCount: _tiles.length,
                                          sets: map.tileSets,
                                          outer: _outer,
                                          outerAt: map.outer,
                                          origin: map.terrainOrigin,
                                          scale: map.terrainScale,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: RepaintBoundary(child: CustomPaint(painter: _GlintPainter(map.glints, _twinkle))),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              // The moving pictures, on their own layer (only it repaints with the clock).
              if (map != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _MovingPainter(
                          map: map,
                          images: _landmarkImages,
                          matrix: _controller,
                          clock: _scenery,
                          still: MediaQuery.of(context).disableAnimations,
                        ),
                      ),
                    ),
                  ),
                ),
              // Lines, stations, names and landmarks are drawn at screen size so
              // they stay readable and crisp at every zoom level.
              if (map != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _MapOverlayPainter(
                        map: map,
                        city: widget.city,
                        lang: lang,
                        matrix: _controller,
                        landmarks: _landmarkImages,
                        selected: _selected,
                        focusLine: _focusLine,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                right: 16,
                top: 12,
                child: _TopBar(
                  city: widget.city,
                  focus: _focusLine,
                  onFocus: (id) => setState(() => _focusLine = id),
                  onSearch: _search,
                ),
              ),
              if (map != null)
                Positioned(
                  right: 16,
                  bottom: 20,
                  child: Column(
                    children: [
                      _MapButton(icon: Icons.add, label: t.mapZoomIn, onTap: () => _zoomBy(1.8)),
                      const SizedBox(height: 10),
                      _MapButton(icon: Icons.remove, label: t.mapZoomOut, onTap: () => _zoomBy(1 / 1.8)),
                      const SizedBox(height: 10),
                      _MapButton(icon: Icons.zoom_out_map_rounded, label: t.mapFitAll, onTap: _fitAll),
                    ],
                  ),
                ),
              // The coast, rivers, parks and expressways are traced from
              // OpenStreetMap (ODbL), which asks for this credit.
              if (map != null)
                const Positioned(
                  left: 8,
                  bottom: 4,
                  child: IgnorePointer(
                    child: Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 9, color: Color(0x99606670)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------- painters ----------------

/// Little light glints on the sea that twinkle one after another.
class _GlintPainter extends CustomPainter {
  _GlintPainter(this.glints, this.time) : super(repaint: time);
  final List<Offset> glints;
  final Animation<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (var i = 0; i < glints.length; i++) {
      final phase = (time.value + i * 0.618) % 1.0;
      // A short flash now and then.
      final a = phase < 0.12 ? math.sin(phase / 0.12 * math.pi) : 0.0;
      if (a <= 0) continue;
      final g = glints[i];
      p.color = Color.fromRGBO(255, 255, 255, a * 0.95);
      canvas.drawRect(Rect.fromLTWH(g.dx - 1, g.dy - 3, 2, 6), p);
      canvas.drawRect(Rect.fromLTWH(g.dx - 3, g.dy - 1, 6, 2), p);
    }
  }

  @override
  bool shouldRepaint(_GlintPainter old) => old.glints != glints;
}

class _TerrainPainter extends CustomPainter {
  _TerrainPainter(
    this.image,
    this.mapSize, {
    this.outer,
    this.outerAt,
    this.origin = Offset.zero,
    this.scale = 2,
    this.tiles = const {},
    this.tileCount = 0,
    this.sets = const [],
  });
  final ui.Image image;
  final Size mapSize;

  /// Tiles loaded so far (asset -> picture), of these [sets].
  final Map<String, ui.Image> tiles;
  final int tileCount;
  final List<MapTileSet> sets;

  /// Top-left of the overview picture (map units) and map units per pixel.
  final Offset origin;
  final double scale;
  final ui.Image? outer;
  final ({String image, Offset origin, double scale})? outerAt;

  @override
  void paint(Canvas canvas, Size size) {
    if (outer != null && outerAt != null) {
      final o = outer!, at = outerAt!;
      canvas.drawImageRect(
        o,
        Rect.fromLTWH(0, 0, o.width.toDouble(), o.height.toDouble()),
        at.origin & Size(o.width * at.scale, o.height * at.scale),
        Paint()..filterQuality = FilterQuality.none,
      );
    }
    // The small overview of all Kanto (far zooms), then the loaded tiles,
    // coarse to fine (Kanto, then Tokyo) - only those near the view are loaded.
    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      origin & Size(image.width * scale, image.height * scale),
      paint,
    );
    for (final set in sets) {
      final head = '${set.dir}/${set.prefix}';
      for (final MapEntry(key: asset, value: img) in tiles.entries) {
        if (!asset.startsWith(head)) continue;
        final xy = asset.substring(head.length, asset.length - 4).split('_');
        final x = int.parse(xy[0]), y = int.parse(xy[1]);
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromLTWH(set.origin.dx + x * set.span, set.origin.dy + y * set.span, img.width * set.scale,
              img.height * set.scale),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TerrainPainter old) =>
      old.image != image || old.outer != outer || old.tileCount != tileCount || !identical(old.tiles, tiles);
}

enum _Anchor { left, right, top, bottom }

/// Decorations and landmarks that move (frames side by side in one picture),
/// drawn like the still ones in _MapOverlayPainter but on their own layer,
/// so only this repaints with the clock - and only what is on screen.
class _MovingPainter extends CustomPainter {
  _MovingPainter({
    required this.map,
    required this.images,
    required this.matrix,
    required this.clock,
    required this.still,
  }) : super(repaint: Listenable.merge([matrix, clock]));

  final RouteMapData map;
  final Map<String, ui.Image> images;
  final TransformationController matrix;
  final Animation<double> clock;

  /// Reduce-motion setting: stay on the first frame.
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final m = matrix.value;
    final s = m.storage[0];
    Offset sp(Offset w) => MatrixUtils.transformPoint(m, w);
    final inv = Matrix4.inverted(m);
    final view = Rect.fromPoints(
      MatrixUtils.transformPoint(inv, Offset.zero),
      MatrixUtils.transformPoint(inv, Offset(size.width, size.height)),
    ).inflate(140 / s);
    int frameOf(int frames) => still ? 0 : (clock.value * frames).floor() % frames;
    Rect src(ui.Image img, int frames) {
      final fw = img.width / frames;
      return Rect.fromLTWH(frameOf(frames) * fw, 0, fw, img.height.toDouble());
    }

    final decorAlpha = ((s - 0.5) / 0.25).clamp(0.0, 1.0);
    if (decorAlpha > 0) {
      final paint = Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(0, 0, 0, decorAlpha * 0.92);
      for (final d in map.decor) {
        if (d.frames <= 1 || !view.contains(d.position)) continue;
        final img = images[d.image];
        if (img == null) continue;
        final p = sp(d.position);
        final fw = img.width / d.frames;
        final w = fw * 2 * s, h = img.height * 2 * s;
        canvas.drawImageRect(img, src(img, d.frames), Rect.fromLTWH(p.dx - w / 2, p.dy - h * 0.75, w, h), paint);
      }
    }
    final lmAlpha = ((s - 0.42) / 0.2).clamp(0.0, 1.0);
    if (lmAlpha <= 0) return;
    final px = (s * 1.1).clamp(0.5, 2.2);
    for (final lm in map.landmarks) {
      if (lm.frames <= 1 || !view.contains(lm.position)) continue;
      final img = images[lm.image];
      if (img == null) continue;
      final p = sp(lm.position);
      final fw = img.width / lm.frames;
      final w = fw * px, h = img.height * px;
      final from = src(img, lm.frames);
      final dst = Rect.fromLTWH(p.dx - w / 2, p.dy - h + 4 * px, w, h);
      // Shadow leaned to the lower right, as for the still landmarks.
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.transform(Float64List.fromList([1, 0, 0, 0, -0.9, -0.32, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]));
      canvas.drawImageRect(
        img,
        from,
        dst.shift(-p),
        Paint()
          ..filterQuality = FilterQuality.none
          ..colorFilter = ColorFilter.mode(Color.fromARGB((46 * lmAlpha).round(), 40, 36, 60), BlendMode.srcIn),
      );
      canvas.restore();
      canvas.drawImageRect(
        img,
        from,
        dst,
        Paint()
          ..filterQuality = FilterQuality.none
          ..colorFilter = _MapOverlayPainter._tone(lmAlpha),
      );
    }
  }

  @override
  bool shouldRepaint(_MovingPainter old) => old.map != map || old.still != still || old.images.length != images.length;
}

/// Names already drawn this frame, in 64-px buckets so a new one is checked
/// only against its neighbours.
class _Placed {
  final _cells = <int, List<Rect>>{};

  bool tryAdd(Rect r) {
    final x0 = (r.left / 64).floor(), x1 = (r.right / 64).floor();
    final y0 = (r.top / 64).floor(), y1 = (r.bottom / 64).floor();
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        for (final q in _cells[x * 100003 + y] ?? const <Rect>[]) {
          if (q.overlaps(r)) return false;
        }
      }
    }
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        (_cells[x * 100003 + y] ??= []).add(r);
      }
    }
    return true;
  }
}

class _MapOverlayPainter extends CustomPainter {
  _MapOverlayPainter({
    required this.map,
    required this.city,
    required this.lang,
    required this.matrix,
    required this.landmarks,
    required this.selected,
    required this.focusLine,
  }) : super(repaint: matrix);

  final RouteMapData map;
  final CityData city;
  final String lang;
  final TransformationController matrix;
  final Map<String, ui.Image> landmarks;
  final String? selected;

  /// Line picked in the top bar; null shows every line equally.
  final String? focusLine;

  /// The line is in the focus picked in the top bar (one line, or 'g:' and a company).
  bool _inFocus(String lineId) {
    final f = focusLine;
    if (f == null || f == lineId) return true;
    return f.startsWith('g:') && city.line(lineId).group == f.substring(2);
  }

  static final _paths = Expando<Path>();

  /// The line's path in map units, made once.
  static Path _pathOf(MapLine line) => _paths[line] ??= () {
    final p = Path()..moveTo(line.path.first.dx, line.path.first.dy);
    for (final q in line.path.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    if (line.closed) p.close();
    return p;
  }();

  /// Text layouts kept between frames (laying out 1,000+ names every frame is slow).
  static final _textCache = <String, TextPainter>{};

  /// Stations in the order their names get room: the big ones first, then
  /// transfer stations (most lines first), then the rest.
  static final _labelOrder = Expando<List<String>>();

  /// Landmarks a little softer than the raw art so they belong to the map.
  static ColorFilter _tone(double alpha) {
    const k = 0.12; // 12 % towards grey
    const r = 0.299, g = 0.587, b = 0.114;
    return ColorFilter.matrix([
      r * k + 1 - k,
      g * k,
      b * k,
      0,
      4,
      r * k,
      g * k + 1 - k,
      b * k,
      0,
      2,
      r * k,
      g * k,
      b * k + 1 - k,
      0,
      0,
      0,
      0,
      0,
      alpha,
      0,
    ]);
  }

  /// Names always shown, even fully zoomed out.
  static const _major = {
    'tokyo.tokyo',
    'tokyo.shinjuku',
    'tokyo.shibuya',
    'tokyo.ikebukuro',
    'tokyo.shinagawa',
    'tokyo.ueno',
    'tokyo.asakusa',
    'tokyo.akihabara',
    'tokyo.ginza',
    'tokyo.shimbashi',
    'tokyo.kanda',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final m = matrix.value;
    final s = m.storage[0];
    Offset sp(Offset w) => MatrixUtils.transformPoint(m, w);
    // The part of the map on screen (with a margin for pictures and names).
    final inv = Matrix4.inverted(m);
    final view = Rect.fromPoints(
      MatrixUtils.transformPoint(inv, Offset.zero),
      MatrixUtils.transformPoint(inv, Offset(size.width, size.height)),
    ).inflate(140 / s);

    // ---- scenery: little trees, houses and boats, only when zoomed in ----
    // They belong to the ground, so they grow with the map (1 picture pixel
    // = 2 map units), and fade in a little before the landmarks.
    final decorAlpha = ((s - 0.5) / 0.25).clamp(0.0, 1.0);
    if (decorAlpha > 0) {
      final paint = Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(0, 0, 0, decorAlpha * 0.92);
      for (final d in map.decor) {
        if (d.frames > 1 || !view.contains(d.position)) continue;
        final img = landmarks[d.image];
        if (img == null) continue;
        final p = sp(d.position);
        final w = img.width * 2 * s, h = img.height * 2 * s;
        final dst = Rect.fromLTWH(p.dx - w / 2, p.dy - h * 0.75, w, h);
        canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, paint);
      }
    }

    // ---- landmarks (3D pixel art) ----
    // Hidden in the overview (Tokyo will have many lines); they fade in as
    // you zoom, standing on the ground with a shadow cast to the lower
    // right, like the light in the pictures (from the top left).
    final lmAlpha = ((s - 0.42) / 0.2).clamp(0.0, 1.0);
    final lmNames = <(String, Offset)>[];
    if (lmAlpha > 0) {
      final px = (s * 1.1).clamp(0.5, 2.2);
      for (final lm in map.landmarks) {
        if (!view.contains(lm.position)) continue;
        if (lm.frames > 1) {
          // Drawn by _MovingPainter; only its name here.
          if (s > 0.75) lmNames.add((lm.name.of(lang), sp(lm.position).translate(0, 6)));
          continue;
        }
        final img = landmarks[lm.image];
        if (img == null) continue;
        final p = sp(lm.position);
        final w = img.width * px, h = img.height * px;
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final dst = Rect.fromLTWH(p.dx - w / 2, p.dy - h + 4 * px, w, h);
        // Shadow: the picture flattened onto the ground and leaned right.
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.transform(Float64List.fromList([1, 0, 0, 0, -0.9, -0.32, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]));
        canvas.drawImageRect(
          img,
          src,
          dst.shift(-p),
          Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = ColorFilter.mode(Color.fromARGB((46 * lmAlpha).round(), 40, 36, 60), BlendMode.srcIn),
        );
        canvas.restore();
        canvas.drawImageRect(
          img,
          src,
          dst,
          Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = _tone(lmAlpha),
        );
        // Its name is drawn last, over the lines (see the end of paint).
        if (s > 0.75) lmNames.add((lm.name.of(lang), p.translate(0, 6)));
      }
    }

    // ---- lines ----
    // Paths are built once in map units and drawn through the zoom matrix
    // (no rebuilding 160+ paths every frame while panning).
    final width = (5.5 * s).clamp(2.0, 7.0);
    canvas.save();
    canvas.transform(m.storage);
    for (final line in map.lines) {
      if (!line.bounds.overlaps(view)) continue;
      final dim = !_inFocus(line.lineId);
      canvas.drawPath(
        _pathOf(line),
        Paint()
          ..color = city.line(line.lineId).color.withValues(alpha: dim ? 0.22 : 1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width / s
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();

    // ---- stations ----
    final r = (6.5 * s).clamp(2.2, 8.5);
    final fill = Paint()..color = PixelColors.card;
    final outline = Paint()
      ..color = PixelColors.ink
      ..style = PaintingStyle.stroke;
    for (final MapEntry(key: id, value: stops) in map.stations.entries) {
      if (!view.contains(stops.first.position)) continue;
      final onFocus = focusLine == null || stops.any((x) => _inFocus(x.lineId));
      fill.color = PixelColors.card.withValues(alpha: onFocus ? 1 : 0.5);
      outline.color = PixelColors.ink.withValues(alpha: onFocus ? 1 : 0.25);
      final pts = stops.map((x) => sp(x.position)).toList();
      // Zoomed far out the whole network is on screen: only transfer
      // stations get a dot, so the lines stay readable.
      if (s < 0.3 && pts.length == 1 && id != selected) continue;
      // All of Kanto on screen: only the big stations, or the middle is one white blob.
      if (s < 0.12 && !_major.contains(id) && id != selected) continue;
      if (focusLine != null && !onFocus && s < 0.6) continue;
      if (pts.length > 1) {
        // Transfer station: one white pill round its stop on each line.
        var box = Rect.fromPoints(pts.first, pts.first);
        for (final p in pts) {
          box = box.expandToInclude(Rect.fromPoints(p, p));
        }
        final rr = RRect.fromRectAndRadius(box.inflate(r + 2), Radius.circular(r + 2));
        canvas.drawRRect(rr, fill);
        canvas.drawRRect(rr, outline..strokeWidth = r < 3 ? 1.2 : (r < 5 ? 2 : 3));
      } else {
        canvas.drawCircle(pts.first, r, fill);
        canvas.drawCircle(pts.first, r, outline..strokeWidth = r < 3 ? 1.0 : (r < 5 ? 1.6 : 2.4));
      }
      if (id == selected) {
        for (final (rad, a) in [(r + 18.0, 0x33), (r + 10.0, 0x77)]) {
          canvas.drawCircle(
            pts.first,
            rad,
            Paint()
              ..color = Color.fromARGB(a, 46, 148, 71)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4,
          );
        }
      }
    }

    // ---- names: minor ones only when zoomed in, never overlapping ----
    final placed = _Placed();
    final font = (11 + 7 * (s - 0.4)).clamp(11.0, 19.0);
    final order = _labelOrder[map] ??= (map.stations.keys.toList()
      ..sort((a, b) {
        final ma = _major.contains(a) ? 1 : 0, mb = _major.contains(b) ? 1 : 0;
        if (ma != mb) return mb - ma;
        return map.stopsOf(b).length - map.stopsOf(a).length;
      }));
    // A station on one line only gets its name from this zoom on.
    final minorFrom = 0.6, transferFrom = 0.32;
    for (final id in order) {
      final all = map.stopsOf(id);
      if (!view.contains(all.first.position)) continue;
      if (focusLine != null && !all.any((x) => _inFocus(x.lineId))) continue;
      final major = _major.contains(id);
      if (!major && s < (all.length > 1 ? transferFrom : minorFrom)) continue;
      final station = city.station(id);
      // Transfer stations take their name from the outer (loop) side.
      final at = all.length > 1 ? all.firstWhere((x) => x.label == LabelSide.right, orElse: () => all.first) : all.first;
      final p = sp(at.position);
      final gap = r + (all.length > 1 ? 10 : 6);
      final (anchor, origin) = switch (at.label) {
        LabelSide.right => (_Anchor.left, p.translate(gap, 0)),
        LabelSide.left => (_Anchor.right, p.translate(-gap, 0)),
        LabelSide.top => (_Anchor.bottom, p.translate(0, -gap)),
        LabelSide.bottom => (_Anchor.top, p.translate(0, gap)),
      };
      final sub = s > 1.3 ? (lang == 'ja' ? station.kana : station.name.of(lang)) : null;
      final fs = ((font * (major ? 1.15 : 1)) * 2).roundToDouble() / 2;
      final rect = _bounds(station.name.ja, sub, origin, anchor, fs);
      if (rect.right < 0 || rect.left > size.width || rect.bottom < 0 || rect.top > size.height) continue;
      if (!placed.tryAdd(rect)) continue;
      _label(canvas, station.name.ja, origin, size: fs, color: PixelColors.ink, anchor: anchor, sub: sub);
    }

    // ---- landmark names: on top of the lines, where no station name is ----
    for (final (name, at) in lmNames) {
      final rect = _bounds(name, null, at, _Anchor.top, 12);
      if (!placed.tryAdd(rect)) continue;
      _label(canvas, name, at, size: 12, color: const Color(0xFF60666F), anchor: _Anchor.top);
    }
  }

  TextPainter _tp(String text, double size, Color color, {Paint? stroke}) {
    final key = '$text|$size|${color.toARGB32()}|${stroke?.strokeWidth}';
    final hit = _textCache[key];
    if (hit != null) return hit;
    if (_textCache.length > 4000) _textCache.clear();
    final base = pixelStyle(size: 16, color: color);
    return _textCache[key] = TextPainter(
      text: TextSpan(
        text: text,
        style: base.copyWith(fontSize: size, color: stroke == null ? color : null, foreground: stroke),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  Offset _topLeft(TextPainter front, double totalH, Offset o, _Anchor a) => switch (a) {
    _Anchor.left => Offset(o.dx, o.dy - front.height / 2),
    _Anchor.right => Offset(o.dx - front.width, o.dy - front.height / 2),
    _Anchor.top => Offset(o.dx - front.width / 2, o.dy),
    _Anchor.bottom => Offset(o.dx - front.width / 2, o.dy - totalH),
  };

  Rect _bounds(String text, String? sub, Offset o, _Anchor a, double size) {
    final tp = _tp(text, size, PixelColors.ink);
    final subH = sub == null ? 0.0 : size * 0.8;
    final tl = _topLeft(tp, tp.height + subH, o, a);
    return Rect.fromLTWH(tl.dx, tl.dy, tp.width, tp.height + subH).inflate(2);
  }

  void _label(
    Canvas canvas,
    String text,
    Offset o, {
    required double size,
    required Color color,
    required _Anchor anchor,
    String? sub,
  }) {
    Paint halo(double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xF2FAFAF6);
    final front = _tp(text, size, color);
    final subFront = sub == null ? null : _tp(sub, size * 0.6, PixelColors.muted);
    final tl = _topLeft(front, front.height + (subFront?.height ?? 0), o, anchor);
    _tp(text, size, color, stroke: halo(4)).paint(canvas, tl);
    front.paint(canvas, tl);
    if (subFront != null) {
      final st = switch (anchor) {
        _Anchor.left => Offset(tl.dx, tl.dy + front.height),
        _Anchor.right => Offset(tl.dx + front.width - subFront.width, tl.dy + front.height),
        _ => Offset(o.dx - subFront.width / 2, tl.dy + front.height),
      };
      _tp(sub!, size * 0.6, PixelColors.muted, stroke: halo(3)).paint(canvas, st);
      subFront.paint(canvas, st);
    }
  }

  @override
  bool shouldRepaint(_MapOverlayPainter old) =>
      old.map != map ||
      old.lang != lang ||
      old.selected != selected ||
      old.focusLine != focusLine ||
      old.landmarks.length != landmarks.length;
}

// ---------------- chrome ----------------

/// Railway companies for the chips, in the order shown.
const _groups = <String, ({String ja, String ko, String en})>{
  'jr': (ja: 'JR', ko: 'JR', en: 'JR'),
  'metro': (ja: '東京メトロ', ko: '도쿄 메트로', en: 'Tokyo Metro'),
  'toei': (ja: '都営', ko: '도에이', en: 'Toei'),
  'tokyu': (ja: '東急', ko: '도큐', en: 'Tokyu'),
  'odakyu': (ja: '小田急', ko: '오다큐', en: 'Odakyu'),
  'keio': (ja: '京王', ko: '게이오', en: 'Keio'),
  'seibu': (ja: '西武', ko: '세이부', en: 'Seibu'),
  'tobu': (ja: '東武', ko: '도부', en: 'Tobu'),
  'keisei': (ja: '京成・北総', ko: '게이세이·호쿠소', en: 'Keisei / Hokuso'),
  'keikyu': (ja: '京急', ko: '게이큐', en: 'Keikyu'),
  'sotetsu': (ja: '相鉄', ko: '소테쓰', en: 'Sotetsu'),
  'yokohama': (ja: '横浜', ko: '요코하마', en: 'Yokohama'),
  'other': (ja: 'その他', ko: '기타', en: 'Others'),
};

/// Top bar: company chips; tapping one lights up its lines and opens a
/// second row with each of them.
class _TopBar extends StatefulWidget {
  const _TopBar({required this.city, required this.focus, required this.onFocus, required this.onSearch});
  final String? focus;
  final ValueChanged<String?> onFocus;
  final CityData city;
  final VoidCallback onSearch;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  String? _group;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final city = widget.city, focus = widget.focus;
    String name(({String ja, String ko, String en}) g) => switch (lang) {
      'ja' => g.ja,
      'ko' => g.ko,
      _ => g.en,
    };
    final groups = [
      for (final g in _groups.keys)
        if (city.lines.any((l) => l.group == g)) g,
      for (final g in {for (final l in city.lines) l.group})
        if (!_groups.containsKey(g)) g,
    ];
    final open = _group == null ? const <RailLine>[] : [for (final l in city.lines) if (l.group == _group) l];

    Widget chip({required String label, required Color color, required bool on, required VoidCallback onTap}) =>
        Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: on ? color.withValues(alpha: 0.18) : PixelColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: on ? color : Colors.transparent, width: 1.5),
              ),
              child: Opacity(
                opacity: focus == null || on ? 1 : 0.55,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    PixelText(label, size: 13),
                  ],
                ),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xF0FFFFFF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              PixelText(t.tabMap, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final g in groups)
                        chip(
                          label: name(_groups[g] ?? (ja: g, ko: g, en: g)),
                          color: city.lines.firstWhere((l) => l.group == g).color,
                          on: _group == g,
                          onTap: () {
                            final close = _group == g;
                            setState(() => _group = close ? null : g);
                            widget.onFocus(close ? null : 'g:$g');
                          },
                        ),
                    ],
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: t.mapSearch,
                child: GestureDetector(
                  onTap: widget.onSearch,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: PixelColors.background, shape: BoxShape.circle),
                    child: const Icon(Icons.search_rounded, size: 22, color: PixelColors.ink),
                  ),
                ),
              ),
            ],
          ),
          if (open.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SizedBox(
                height: 28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final line in open)
                      chip(
                        label: line.name.of(lang),
                        color: line.color,
                        on: focus == line.id,
                        onTap: () => widget.onFocus(focus == line.id ? 'g:$_group' : line.id),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: PixelColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PixelColors.line),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Icon(icon, size: 24, color: PixelColors.ink),
      ),
    ),
  );
}

/// Station card: name, transfer lines, tips, set as start / destination.
/// Pops true for "start", false for "destination".
class _StationSheet extends StatelessWidget {
  const _StationSheet({required this.city, required this.map, required this.stationId});
  final CityData city;
  final RouteMapData map;
  final String stationId;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final station = city.station(stationId);
    final tips = map.tips[stationId] ?? const [];
    final sub = [station.kana, station.name.of(lang == 'ja' ? 'en' : lang)].join(' · ');
    final area = map.areaOf(stationId, lang);
    final walk = station.lines.length > 1 ? station.transferWalkMin(station.lines.first, station.lines.last) : null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PixelText(station.name.ja, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: PixelText(sub, size: 14, color: PixelColors.muted, maxLines: 1),
                  ),
                ),
              ],
            ),
            if (area != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 14, color: PixelColors.muted),
                  const SizedBox(width: 4),
                  Expanded(child: PixelText(area, size: 13, color: PixelColors.muted, maxLines: 1)),
                ],
              ),
            ],
            const SizedBox(height: 14),
            PixelText(t.mapTransfers, size: 13, color: PixelColors.muted),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final id in station.lines)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: PixelColors.background, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(color: city.line(id).color, borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(width: 6),
                        PixelText(city.line(id).name.of(lang), size: 16),
                      ],
                    ),
                  ),
                if (walk != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_walk_rounded, size: 16, color: PixelColors.muted),
                      PixelText(t.transferWalk(walk), size: 13, color: PixelColors.muted),
                    ],
                  ),
              ],
            ),
            // Nearby stations with another name, reached on foot.
            if (city.walksFrom(stationId).isNotEmpty) ...[
              const SizedBox(height: 12),
              PixelText(t.mapWalkTransfers, size: 13, color: PixelColors.muted),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final w in city.walksFrom(stationId))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: PixelColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PixelColors.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_walk_rounded, size: 16, color: PixelColors.muted),
                          const SizedBox(width: 4),
                          PixelText(city.station(w.stationId).name.ja, size: 16),
                          const SizedBox(width: 6),
                          for (final id in city.station(w.stationId).lines)
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 3),
                              decoration: BoxDecoration(
                                color: city.line(id).color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          const SizedBox(width: 3),
                          PixelText(t.walkMinutes(w.minutes), size: 13, color: PixelColors.muted),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            PixelText(t.mapTips, size: 13, color: PixelColors.muted),
            const SizedBox(height: 6),
            if (tips.isEmpty)
              PixelText(t.mapNoTips, size: 14, color: PixelColors.muted)
            else ...[
              for (final tip in tips)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: PixelColors.background, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5, right: 10),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Color(0xFF2E9447), shape: BoxShape.circle),
                      ),
                      Expanded(child: PixelText(tip.of(lang), size: 14)),
                    ],
                  ),
                ),
              PixelText(t.mapTipsNote, size: 11, color: PixelColors.muted),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    label: t.mapSetFrom,
                    color: const Color(0xFF2E9447),
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetButton(
                    label: t.mapSetTo,
                    color: const Color(0xFFE0513F),
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: PixelText(label, size: 19, color: PixelColors.card),
      ),
    ),
  );
}
