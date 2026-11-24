import 'package:material_ui/material_ui.dart';

/// UI colours. Calm and neutral: the pixel art and line colours are the only
/// strong colours on screen.
class PixelColors {
  /// Dark look on (設定 → 見た目). Set by [AppLook] before the app rebuilds;
  /// every colour below follows it, so nothing may keep one in a `const`.
  static bool dark = false;

  static Color get ink => dark ? const Color(0xFFECEDEF) : const Color(0xFF1C1E24);
  static Color get background => dark ? const Color(0xFF14161B) : const Color(0xFFF4F4F1);
  static Color get card => dark ? const Color(0xFF20232B) : const Color(0xFFFFFFFF);
  static Color get line => dark ? const Color(0xFF343842) : const Color(0xFFE3E3DE); // hairline borders
  static Color get muted => dark ? const Color(0xFF9097A3) : const Color(0xFF8A8F98);
  static Color get accent => ink; // primary buttons, selected states
  static Color get soft => dark ? const Color(0xFF2A2E38) : const Color(0xFFEBEBE6); // disabled fill, unvisited rail
  static Color get celebrate => dark ? const Color(0xFF4A4320) : const Color(0xFFFFF3C4);
  static Color get danger => dark ? const Color(0xFFFF6B6B) : const Color(0xFFD64545);
  static Color get title => dark ? const Color(0xFF58C873) : const Color(0xFF2E9447);
}

/// One "unit" of the pixel grid in logical pixels — the same size as one
/// pixel of the 2× sprites, so borders, art and corners share one grid.
const double pu = 2;

/// Text. Display sizes (16 and up) use the pixel font; smaller supporting
/// text uses the system font, because pixel fonts get noisy when small.
class PixelText extends StatelessWidget {
  const PixelText(
    this.text, {
    super.key,
    this.size = 16,
    this.color,
    this.align,
    this.maxLines,
    this.bold = false,
  });

  final String text;

  /// Chunky bold pixel digits (Galmuri11 Bold) for numbers that should pop.
  final bool bold;
  final double size;
  final Color? color;
  final TextAlign? align;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: pixelStyle(
      size: size,
      bold: bold,
      color: color ?? DefaultTextStyle.of(context).style.color ?? PixelColors.ink,
    ),
  );
}

TextStyle pixelStyle({double size = 16, Color? color, double height = 1.25, bool bold = false}) {
  if (bold) {
    // Galmuri11 Bold has Latin, digits, % and ℃; anything else falls back
    // to the regular pixel font.
    return TextStyle(
      fontFamily: 'Galmuri11',
      fontFamilyFallback: const ['DotGothic16'],
      fontSize: size,
      height: height,
      color: color ?? PixelColors.ink,
      fontWeight: FontWeight.w700,
    );
  }
  final pixel = size >= 16;
  return TextStyle(
    fontFamily: pixel ? 'DotGothic16' : null,
    fontFamilyFallback: pixel ? const ['Galmuri11'] : null,
    fontSize: size,
    height: height,
    color: color ?? PixelColors.ink,
    fontWeight: pixel ? FontWeight.w400 : FontWeight.w500,
    letterSpacing: pixel ? 0.2 : 0,
  );
}

/// Flat card: one-unit hairline border and pixel-stepped corners.
/// No bevels or drop shadows — spacing does the separating.
class PixelBox extends StatelessWidget {
  const PixelBox({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.all(14),
    this.pressed = false,
  });

  final Widget child;
  final Color? color;

  /// Defaults to a hairline on light fills and no visible border on dark ones.
  final Color? borderColor;
  final EdgeInsets padding;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? PixelColors.card;
    final shown = pressed ? Color.lerp(fill, PixelColors.ink, 0.08)! : fill;
    return CustomPaint(
      painter: _BoxPainter(fill: shown, border: borderColor ?? _defaultBorder(fill)),
      child: Padding(padding: padding.add(const EdgeInsets.all(pu)), child: child),
    );
  }

  static Color _defaultBorder(Color fill) => fill.computeLuminance() > 0.6 ? PixelColors.line : fill;
}

class _BoxPainter extends CustomPainter {
  _BoxPainter({required this.fill, required this.border});
  final Color fill;
  final Color border;

  /// Rectangle with corners cut by [cut] units (pixel-art rounded corner).
  static void stepped(Canvas canvas, Rect r, Color c, {int cut = 1}) {
    final p = Paint()
      ..color = c
      ..isAntiAlias = false;
    for (var i = 0; i <= cut; i++) {
      final inset = (cut - i) * pu;
      canvas.drawRect(Rect.fromLTRB(r.left + inset, r.top + i * pu, r.right - inset, r.bottom - i * pu), p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final body = Offset.zero & size;
    stepped(canvas, body, border, cut: 2);
    stepped(canvas, body.deflate(pu), fill, cut: 1);
  }

  @override
  bool shouldRepaint(_BoxPainter old) => old.fill != fill || old.border != border;
}

/// Flat button. Dark fills get white text automatically.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.expand = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final EdgeInsets padding;
  final bool expand;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final fill = enabled ? (widget.color ?? PixelColors.accent) : PixelColors.soft;
    final textColor = !enabled
        ? PixelColors.muted
        : (fill.computeLuminance() < 0.4 ? PixelColors.card : PixelColors.ink);
    final box = PixelBox(
      color: fill,
      borderColor: enabled ? null : PixelColors.soft,
      pressed: _down,
      padding: widget.padding,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: textColor),
        child: Center(
          widthFactor: widget.expand ? null : 1,
          heightFactor: 1,
          child: enabled ? widget.child : Opacity(opacity: 0.7, child: widget.child),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onPressed!();
              }
            : null,
        child: box,
      ),
    );
  }
}

/// Small flat square for line colours and stop markers.
class PixelSquare extends StatelessWidget {
  const PixelSquare({super.key, required this.color, this.size = 12, this.hollow = false});
  final Color color;
  final double size;
  final bool hollow;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SquarePainter(color, hollow));
}

class _SquarePainter extends CustomPainter {
  _SquarePainter(this.color, this.hollow);
  final Color color;
  final bool hollow;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    _BoxPainter.stepped(canvas, r, color);
    if (hollow) {
      _BoxPainter.stepped(canvas, r.deflate(pu * 1.5), PixelColors.card, cut: 0);
    }
  }

  @override
  bool shouldRepaint(_SquarePainter old) => old.color != color || old.hollow != hollow;
}

/// Plain screen background.
class PixelBackground extends StatelessWidget {
  const PixelBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: PixelColors.background, child: child);
}
