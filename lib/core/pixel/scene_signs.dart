part of 'pixel_scene.dart';

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
