import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/pixel/pixel_scene.dart';
import 'side_train_view.dart';

/// Which scenery set the trip view shows around stop [index] of a trip in
/// [cityId] on [lineId]: a few stops each, from the sets that suit the city.
String sceneryFor(String cityId, String lineId, int index) {
  final sets = _citySets[cityId] ?? const ['city', 'river', 'suburb', 'country'];
  final h = lineId.codeUnits.fold(7, (a, b) => (a * 31 + b) & 0x7fffffff);
  return sets[(h + index ~/ 3) % sets.length];
}

const _citySets = {
  'tokyo': ['city', 'river', 'suburb', 'oldtown'],
  'tottori': ['seaside', 'country', 'mountain', 'oldtown', 'river', 'flower'],
  'osaka': ['city', 'river', 'harbor', 'oldtown', 'suburb'],
  'fukuoka': ['city', 'harbor', 'seaside', 'river', 'suburb'],
  'sendai': ['city', 'country', 'seaside', 'mountain', 'snow'],
  'sapporo': ['city', 'snow', 'country', 'flower', 'mountain'],
};

/// Whether [lineId] runs under overhead wires; the rest have diesel
/// railcars (most of Tottori's lines: only the 伯備線 and its expresses are electric).
bool lineElectric(String lineId) => !_diesel.contains(lineId);

const _diesel = {
  'tottori.sanin',
  'tottori.sakai',
  'tottori.inbi',
  'tottori.wakasa',
  'tottori.chizukyu',
  'tottori.matsukaze',
  'tottori.hakuto',
};

/// The Blender props (tools/blender/props3d.py): one atlas of the things
/// beside the line, one of their lamps, and where each sits.
class Props3dArt {
  Props3dArt._(this.base, this.lamp, this.meta);

  final ui.Image base;
  final ui.Image lamp;
  final Map<String, dynamic> meta;

  static Future<Props3dArt>? _cache;

  static Future<Props3dArt> load(Future<ui.Image> Function(String) image) => _cache ??= () async {
    const dir = 'assets/art/train3d';
    final r = await Future.wait([image('$dir/props_base.webp'), image('$dir/props_lamp.webp')]);
    final meta = jsonDecode(await rootBundle.loadString('$dir/props.json')) as Map<String, dynamic>;
    return Props3dArt._(r[0], r[1], meta);
  }();

  Map<String, dynamic> prop(String name) => (meta['props'] as Map<String, dynamic>)[name] as Map<String, dynamic>;
}

/// Which props stand beside the line in each scenery, and how often.
const _kinds = {
  'city': ['signal', 'pole', 'pole', 'crossing'],
  'seaside': ['pole', 'hut', 'crossing', 'signal'],
  'country': ['crossing', 'pole', 'hut', 'signal', 'pole'],
  'mountain': ['signal', 'hut', 'pole'],
  'oldtown': ['crossing', 'pole', 'signal'],
  'river': ['signal', 'pole', 'hut'],
  'suburb': ['crossing', 'pole', 'signal', 'pole'],
  'snow': ['pole', 'hut', 'signal'],
  'harbor': ['signal', 'pole', 'hut'],
  'flower': ['crossing', 'pole', 'hut'],
};

/// Long runs: a sound wall in the city and the suburbs, a truss bridge over
/// the river and in the mountains.
String? _run(String theme, int slot) {
  final h = _hash(slot ~/ 4, 91);
  if ((theme == 'suburb' || theme == 'city') && h % 3 == 0) return 'wall';
  if ((theme == 'river' || theme == 'mountain') && h % 3 == 0) return 'truss';
  return null;
}

int _hash(int i, int salt) {
  var x = (i * 374761393 + salt * 668265263) & 0xFFFFFFFF;
  x = ((x ^ (x >> 13)) * 1274126177) & 0xFFFFFFFF;
  return (x ^ (x >> 16)) & 0x7FFFFFFF;
}

/// Where the props go on the trip view's planes.
enum PropLayer {
  /// Beside the line, behind the track: crossings, signals, huts, poles, sound walls.
  side,

  /// The far side of a truss bridge, just behind the train.
  trussBack,

  /// The near side of a truss bridge, just in front of the train.
  trussFront,
}

/// Paints the props of [theme] for one [layer], scrolled with the track.
class TripPropsPainter extends CustomPainter {
  TripPropsPainter({
    required this.art,
    required this.sim,
    required this.theme,
    required this.layer,
    required this.tint,
    required this.lit,
    this.opacity = 1,
  });

  final Props3dArt art;
  final SideTrainSim sim;
  final String theme;
  final PropLayer layer;

  /// The light of the time of day, multiplied in.
  final Color tint;

  /// After dark (or underground): lamps lit.
  final bool lit;
  final double opacity;

  static const slot = 148.0;
  static const groundY = SideTrainPainter.railY - 3;

  /// Track plane scroll (1.0) and a touch slower for the things set back from it.
  double get _scroll => sim.offset * (layer == PropLayer.side ? 0.94 : 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    canvas.save();
    canvas.scale(size.width / SideTrainPainter.gridW, size.height / SideTrainPainter.gridH);
    if (opacity < 1) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    }
    final scroll = _scroll;
    final first = ((scroll - 120) / slot).floor();
    final last = ((scroll + SideTrainPainter.gridW + 120) / slot).ceil();
    for (var i = first; i <= last; i++) {
      final x = i * slot - scroll;
      // No bridge or sound wall where a platform is (the train stands at a station).
      final run = sim.platformX == null ? _run(theme, i) : null;
      if (layer != PropLayer.side) {
        if (run == 'truss') {
          final name = layer == PropLayer.trussBack ? 'truss_back' : 'truss_front';
          final p = art.prop(name);
          final w = (p['w'] as int).toDouble();
          // Modules on their own world grid, so they join up across slots.
          final m0 = (i * slot / w).floor();
          for (var m = m0; m * w < (i + 1) * slot; m++) {
            _draw(canvas, name, m * w - scroll, SideTrainPainter.railY + 2);
          }
        }
        continue;
      }
      if (run == 'wall') {
        final p = art.prop('wall');
        final w = (p['w'] as int).toDouble() - 24; // the module without its margins
        for (var m = (i * slot / w).floor(); m * w < (i + 1) * slot; m++) {
          _draw(canvas, 'wall', m * w - scroll, groundY);
        }
        continue;
      }
      if (run == 'truss') continue;
      final h = _hash(i, 17);
      if (h % 5 < 2) continue; // some stretches stand empty
      final kinds = _kinds[theme] ?? _kinds['city']!;
      _draw(canvas, kinds[h % kinds.length], x + (h >> 8) % 60, groundY);
    }
    if (opacity < 1) canvas.restore();
    canvas.restore();
  }

  void _draw(Canvas c, String name, double x, double groundY) {
    final p = art.prop(name);
    final w = (p['w'] as int).toDouble(), h = (p['h'] as int).toDouble();
    final a = (p['anchor'] as List).cast<num>();
    final src = Rect.fromLTWH((p['x'] as num).toDouble(), (p['y'] as num).toDouble(), w, h);
    final dst = Rect.fromLTWH((x - a[0]).floorToDouble(), (groundY - a[1]).floorToDouble(), w, h);
    if (dst.right < -20 || dst.left > SideTrainPainter.gridW + 20) return;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    c.drawImageRect(art.base, src, dst, paint);
    // Lamps: lit after dark; a crossing's red lamps blink while a train passes.
    final blink = name == 'crossing' && (sim.time * 2).floor().isEven;
    if (lit || blink) {
      final glow = name == 'crossing' ? const Color(0xFFFF4A3A) : const Color(0xFFFFE2A0);
      c.drawImageRect(
        art.lamp,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.none
          ..colorFilter = ColorFilter.mode(glow, BlendMode.modulate),
      );
      if (lit) {
        c.saveLayer(dst.inflate(8), Paint()..blendMode = BlendMode.plus);
        c.drawImageRect(
          art.lamp,
          src,
          dst,
          Paint()
            ..colorFilter = ColorFilter.mode(glow.withValues(alpha: 0.5), BlendMode.modulate)
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
        );
        c.restore();
      }
    }
  }

  @override
  bool shouldRepaint(TripPropsPainter old) => true;
}

/// The light of [part] (or underground) for the props and the train.
Color tripTint(DayPart part, bool underground) => underground
    ? const Color(0xFFB4B9CC)
    : switch (part) {
        DayPart.day => const Color(0xFFFFFFFF),
        DayPart.evening => const Color(0xFFF6D3C0),
        DayPart.night => const Color(0xFF8E96B8),
      };
