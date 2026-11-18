import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// The one shared 64-colour palette for every pixel-art element in the app.
/// Each colour is one character (see [chars]); the first 32 are the original
/// set, the second 32 are extra shading ramps (sky, buildings, metal, glass…).
/// Special characters: '.' transparent, '*' riding line colour,
/// '+' line colour dark, '-' line colour light.
class PixelPalette {
  static const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#\$';

  static const colors = <Color>[
    // ---- 0–V: base set ----
    Color(0xFF14152B), // 0 ink (outlines, text)
    Color(0xFF2B2D4F), // 1 deep navy
    Color(0xFF484B73), // 2 slate
    Color(0xFF6E7397), // 3 grey blue
    Color(0xFF9CA3BF), // 4 light slate
    Color(0xFFC9CEDD), // 5 pale
    Color(0xFFEEF0F5), // 6 off white
    Color(0xFFFFFFFF), // 7 white
    Color(0xFF5B2A3E), // 8 plum
    Color(0xFF9C3D54), // 9 crimson
    Color(0xFFD9576B), // A red
    Color(0xFFF28B82), // B pink
    Color(0xFFF7B7A3), // C peach
    Color(0xFF8A4B2A), // D brown
    Color(0xFFC27438), // E rust
    Color(0xFFF2A541), // F orange
    Color(0xFFFFD45E), // G yellow
    Color(0xFFFFF2B0), // H cream yellow
    Color(0xFF2E5E3A), // I forest
    Color(0xFF3F8F4A), // J green
    Color(0xFF7BC75B), // K lime
    Color(0xFFB9E07A), // L light lime
    Color(0xFF1F4E6B), // M deep sea
    Color(0xFF2F7FA8), // N blue
    Color(0xFF52B4E0), // O sky
    Color(0xFFA6E3F2), // P ice
    Color(0xFF3B3F8F), // Q indigo
    Color(0xFF6C6FD1), // R periwinkle
    Color(0xFFF4EAD5), // S cream (app background)
    Color(0xFFE2D3B5), // T tan
    Color(0xFFB59C7A), // U sand
    Color(0xFF0B0C18), // V night
    // ---- W–$: shading ramps ----
    Color(0xFF12162B), // W deep outline (sel-out)
    Color(0xFFFAF7EF), // X warm white (train body light)
    Color(0xFFDCD6C8), // Y body shade
    Color(0xFFB8AF9E), // Z body dark
    Color(0xFF151C3C), // a night sky / dark glass
    Color(0xFF26346A), // b deep blue
    Color(0xFF4166A8), // c blue
    Color(0xFF6E9AD6), // d light blue
    Color(0xFFA9CFEF), // e pale sky
    Color(0xFFE1F0F8), // f haze
    Color(0xFFFF9E6B), // g sunset orange
    Color(0xFFFFC98F), // h sunset gold
    Color(0xFFD9667A), // i sunset rose
    Color(0xFF332E4D), // j building dark
    Color(0xFF4C4569), // k building
    Color(0xFF686188), // l building mid
    Color(0xFF8D86AA), // m building light (far)
    Color(0xFFB4AFCB), // n haze building
    Color(0xFFFFE7A0), // o lit window / sun core
    Color(0xFFF3BE5E), // p lamp / sun rim
    Color(0xFF242936), // q metal darkest
    Color(0xFF3E4556), // r metal dark
    Color(0xFF5E6679), // s metal
    Color(0xFF858DA2), // t metal light
    Color(0xFFB0B7C7), // u metal pale
    Color(0xFFD9DDE7), // v metal shine
    Color(0xFF254A33), // w leaf dark
    Color(0xFF3F7A48), // x leaf
    Color(0xFF6FAE5C), // y leaf light
    Color(0xFF5E4330), // z wood dark
    Color(0xFF8D6A4A), // # wood
    Color(0xFFBF9971), // $ wood light
  ];

  static final _index = {for (var i = 0; i < chars.length; i++) chars[i]: i};

  static Color c(String ch) => colors[_index[ch]!];

  static Color? resolve(String ch, Color lineColor) {
    switch (ch) {
      case '.':
        return null;
      case '*':
        return lineColor;
      case '+':
        return Color.lerp(lineColor, colors[0], 0.35);
      case '-':
        return Color.lerp(lineColor, colors[7], 0.45);
      default:
        return colors[_index[ch]!];
    }
  }
}

class PixelSprite {
  PixelSprite(this.frames) : height = frames.first.length, width = frames.first.first.length {
    for (final f in frames) {
      assert(f.length == height, 'all frames need the same height');
      for (final row in f) {
        assert(row.length == width, 'row "$row" is not $width pixels wide');
      }
    }
  }

  final List<List<String>> frames;
  final int width;
  final int height;
}

/// Small drawing helper used to build sprites and scenes in code.
class PixelCanvas {
  PixelCanvas(this.width, this.height) : _g = List.generate(height, (_) => List.filled(width, '.'));

  final int width;
  final int height;
  final List<List<String>> _g;

  void set(int x, int y, String c) {
    if (x >= 0 && y >= 0 && x < width && y < height) _g[y][x] = c;
  }

  void rect(int x, int y, int w, int h, String c) {
    for (var j = y; j < y + h; j++) {
      for (var i = x; i < x + w; i++) {
        set(i, j, c);
      }
    }
  }

  /// Checkerboard of two colours: the classic pixel-art gradient step.
  void dither(int x, int y, int w, int h, String a, String b) {
    for (var j = y; j < y + h; j++) {
      for (var i = x; i < x + w; i++) {
        set(i, j, (i + j).isEven ? a : b);
      }
    }
  }

  void hline(int x1, int x2, int y, String c) => rect(x1, y, x2 - x1 + 1, 1, c);
  void vline(int x, int y1, int y2, String c) => rect(x, y1, 1, y2 - y1 + 1, c);

  void disc(int cx, int cy, int r, String c) {
    for (var dy = -r; dy <= r; dy++) {
      for (var dx = -r; dx <= r; dx++) {
        if (dx * dx + dy * dy <= r * r + r * 0.8) set(cx + dx, cy + dy, c);
      }
    }
  }

  String at(int x, int y) => _g[y][x];

  List<String> rows() => [for (final r in _g) r.join()];
}

/// Built-in sprites. MY room items will load extra sprites from assets later;
/// these stay as the free starter set.
class Sprites {
  /// "Tsugi" — the free starter train, 128×56. Two frames turn the wheels.
  static final starterTrain = PixelSprite([_train(0), _train(1)]);

  static List<String> _train(int frame) {
    final p = PixelCanvas(128, 56);
    const top = 8, bottom = 44, left = 2, right = 125;

    // Right edge on row y: sloped nose on the upper half.
    int edge(int y) => y <= 26 ? 108 + ((y - top) * 17) ~/ 18 : right;
    int leftEdge(int y) => switch (y) {
      top || bottom => left + 3,
      9 || 43 => left + 1,
      _ => left,
    };

    // --- roof equipment (behind the roof line) ---
    for (final x0 in [18, 62]) {
      p.rect(x0, 2, 22, 7, 'W');
      p.rect(x0 + 1, 3, 20, 5, 't');
      p.hline(x0 + 1, x0 + 20, 3, 'v');
      p.vline(x0 + 20, 4, 7, 's');
      for (var x = x0 + 3; x < x0 + 19; x += 3) {
        p.vline(x, 5, 6, 'r');
      }
    }
    p.vline(100, 4, 7, 'r');
    p.set(100, 3, 'u');

    // --- body with a soft vertical gradient ---
    for (var y = top; y <= bottom; y++) {
      final l = leftEdge(y);
      final r = edge(y);
      p.hline(l, r, y, 'W');
      if (y == top || y == bottom) continue;
      final fill = switch (y) {
        9 => 'v',
        <= 12 => 'u',
        <= 29 => 'X',
        <= 41 => 'Y',
        _ => 's',
      };
      p.hline(l + 1, r - 1, y, fill);
    }
    p.hline(left + 2, edge(42) - 1, 43, 'r');

    // --- side windows: frame, glass gradient, reflection streak ---
    void glass(int x, int y0, int w, int h) {
      for (var y = y0; y < y0 + h; y++) {
        p.hline(x, x + w - 1, y, y - y0 < h * 0.4 ? 'd' : 'c');
      }
      // One clean diagonal highlight.
      for (var i = 0; i < h - 3 && i < w; i++) {
        p.set(x + 2 + i ~/ 2, y0 + 1 + i, 'e');
      }
    }

    for (final x in [10, 26, 58, 74]) {
      p.rect(x - 1, 15, 14, 13, 'r');
      glass(x, 16, 12, 11);
      p.hline(x, x + 11, 27, 's');
    }

    // --- doors ---
    for (final x in [42, 88]) {
      p.rect(x, 14, 12, 28, 'Y');
      p.vline(x, 14, 41, 'Z');
      p.vline(x + 11, 14, 41, 'Z');
      p.rect(x + 2, 17, 8, 11, 'r');
      glass(x + 3, 18, 2, 9);
      glass(x + 7, 18, 2, 9);
      p.vline(x + 5, 14, 41, 's');
      p.vline(x + 6, 14, 41, 'r');
    }

    // --- front: windshield, destination LED, lights ---
    for (var y = 15; y <= 27; y++) {
      final r = edge(y) - 3;
      p.hline(103, r, y, y < 20 ? 'c' : 'b');
    }
    for (var y = 16; y <= 22; y++) {
      p.set(106 + (y - 16), y, 'e');
    }
    p.vline(102, 14, 28, 'W');
    p.hline(102, edge(14) - 2, 14, 'W');
    p.hline(102, edge(28) - 2, 28, 'W');
    p.rect(104, 10, 12, 3, 'a');
    for (var x = 105; x < 115; x += 2) {
      p.set(x, 11, 'p');
    }
    p.rect(117, 37, 5, 2, 'o');
    p.set(118, 37, 'X');
    p.rect(3, 37, 2, 2, 'A');

    // --- line colour stripe ---
    p.hline(left + 1, right - 1, 31, '-');
    for (var y = 32; y <= 34; y++) {
      p.hline(left + 1, right - 1, y, '*');
    }
    p.hline(left + 1, right - 1, 35, '+');

    // --- under-floor equipment ---
    for (final (x0, w) in [(34, 18), (66, 30)]) {
      p.rect(x0, 45, w, 4, 'r');
      p.hline(x0, x0 + w - 1, 45, 's');
      p.hline(x0, x0 + w - 1, 48, 'q');
    }

    // --- bogies and wheels ---
    for (final bx in [24, 104]) {
      p.rect(bx - 14, 45, 29, 4, 'q');
      p.hline(bx - 14, bx + 14, 45, 's');
      p.rect(bx - 2, 46, 5, 2, 't');
      p.set(bx, 46, 'u');
      for (final cx in [bx - 8, bx + 8]) {
        const cy = 51;
        p.disc(cx, cy, 4, 'q');
        p.disc(cx, cy, 3, 's');
        p.disc(cx, cy, 1, 't');
        p.set(cx, cy, 'u');
        p.set(cx - 2, cy - 3, 't');
        if (frame == 0) {
          p.set(cx, cy - 2, 'v');
          p.set(cx, cy + 2, 'r');
        } else {
          p.set(cx - 2, cy, 'v');
          p.set(cx + 2, cy, 'r');
        }
      }
    }
    return p.rows();
  }

  static const _cloud = [
    '......4444......',
    '.....477774.....',
    '..4444777774....',
    '.4777777777744..',
    '4777777777777774',
    '4777777777777774',
    '4555555555555554',
    '.44444444444444.',
  ];

  static final weatherSunny = PixelSprite([
    [
      '................',
      '.......GG.......',
      '..G....GG....G..',
      '...G........G...',
      '......GGGG......',
      '.....GHHGGG.....',
      '....GHHGGGGG....',
      'GG..GGGGGGGG..GG',
      'GG..GGGGGGGG..GG',
      '....GGGGGGFG....',
      '.....GGGGFF.....',
      '......GFFF......',
      '...G........G...',
      '..G....GG....G..',
      '.......GG.......',
      '................',
    ],
  ]);

  static final weatherCloudy = PixelSprite([
    [
      '................',
      '................',
      '................',
      ..._cloud,
      '................',
      '................',
      '................',
      '................',
      '................',
    ],
  ]);

  static final weatherRain = PixelSprite([
    [
      '................',
      ..._cloud,
      '................',
      '..N....N....N...',
      '.N....N....N....',
      '................',
      '....N....N....N.',
      '...N....N....N..',
      '................',
    ],
  ]);

  static final weatherSnow = PixelSprite([
    [
      '................',
      ..._cloud,
      '................',
      '..P....P....P...',
      '.PPP..PPP..PPP..',
      '..P....P....P...',
      '....P....P....P.',
      '...PPP..PPP..PPP',
      '....P....P....P.',
    ],
  ]);

  // Line icons: '*' takes the colour passed as lineColor, so they stay
  // one flat colour (ink when selected, grey otherwise).
  /// Location pin.
  static final pin = PixelSprite([
    [
      '................',
      '.....******.....',
      '....********....',
      '...***....***...',
      '...**......**...',
      '...**......**...',
      '...***....***...',
      '....********....',
      '.....******.....',
      '......****......',
      '.......**.......',
      '................',
      '................',
      '................',
      '................',
      '................',
    ],
  ]);

  /// のりば: station sign.
  static final navPlatform = PixelSprite([
    [
      '................',
      '.**************.',
      '.*............*.',
      '.*.**********.*.',
      '.*............*.',
      '.**************.',
      '.......**.......',
      '.......**.......',
      '.......**.......',
      '.......**.......',
      '.......**.......',
      '.....******.....',
      '................',
      '................',
      '................',
      '................',
    ],
  ]);

  /// 路線図: a loop line crossed by a straight line.
  static final navMap = PixelSprite([
    [
      '................',
      '.....******.....',
      '...**......**...',
      '..*..........*..',
      '.*............*.',
      '.*............*.',
      '****************',
      '****************',
      '.*............*.',
      '.*............*.',
      '..*..........*..',
      '...**......**...',
      '.....******.....',
      '................',
      '................',
      '................',
    ],
  ]);

  /// MY: house.
  static final navMy = PixelSprite([
    [
      '................',
      '.......**.......',
      '......*..*......',
      '.....*....*.....',
      '....*......*....',
      '...*........*...',
      '..************..',
      '...*........*...',
      '...*........*...',
      '...*...**...*...',
      '...*...**...*...',
      '...*...**...*...',
      '...**********...',
      '................',
      '................',
      '................',
    ],
  ]);
}

/// Turns sprite frames into GPU images once and reuses them, so even big
/// sprites and full scenes cost one draw call per frame.
class SpriteImages {
  static final _cache = <(PixelSprite, int, int), ui.Image>{};

  static ui.Image of(PixelSprite sprite, int frame, Color lineColor) {
    final key = (sprite, frame, lineColor.toARGB32());
    final hit = _cache[key];
    if (hit != null) return hit;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = false;
    final rows = sprite.frames[frame];
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final c = PixelPalette.resolve(row[x], lineColor);
        if (c == null) continue;
        paint.color = c;
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }
    final image = recorder.endRecording().toImageSync(sprite.width, sprite.height);
    if (_cache.length > 64) _cache.clear();
    return _cache[key] = image;
  }
}

/// Draws a sprite with crisp square pixels (nearest-neighbour, no smoothing).
class PixelSpriteView extends StatelessWidget {
  const PixelSpriteView({
    super.key,
    required this.sprite,
    required this.pixelSize,
    this.frame = 0,
    this.lineColor = const Color(0xFF80C241),
  });

  final PixelSprite sprite;
  final double pixelSize;
  final int frame;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(sprite.width * pixelSize, sprite.height * pixelSize),
      painter: _SpritePainter(sprite, frame % sprite.frames.length, lineColor),
    );
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.sprite, this.frame, this.lineColor);

  final PixelSprite sprite;
  final int frame;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final image = SpriteImages.of(sprite, frame, lineColor);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.frame != frame || old.lineColor != lineColor || old.sprite != sprite;
}
