import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/pixel/pixel_ui.dart';
import 'guide_tips.dart';

/// 「つぎはさん」: the station attendant giving one tip at a time in a speech
/// bubble. Tap for the next tip; ✕ hides the guide until the app restarts.
/// He points (指差確認) at warnings and stands at ease for the rest.
class GuideCard extends StatefulWidget {
  const GuideCard({super.key, required this.tips});
  final List<GuideTip> tips;

  @override
  State<GuideCard> createState() => _GuideCardState();
}

class _GuideCardState extends State<GuideCard> {
  static bool _hidden = false;
  static ui.Image? _staff;
  static Future<ui.Image?>? _loading;

  int _i = 0;
  Timer? _turn;

  /// Old tip out, then new tip in.
  static const switchTime = Duration(milliseconds: 420);

  /// Frames of the attendant sheet (8 side by side): 6 = standing, 7 = pointing.
  static Future<ui.Image?> _load() => _loading ??= () async {
    for (final a in const ['assets/art/events/staff.webp', 'assets/art/events/staff.png']) {
      try {
        final data = await rootBundle.load(a);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        return _staff = (await codec.getNextFrame()).image;
      } catch (_) {
        // Not this format.
      }
    }
    return null;
  }();

  @override
  void initState() {
    super.initState();
    if (_staff == null) _load().then((_) => mounted ? setState(() {}) : null);
    // The next tip every 9 seconds, until the user taps.
    _turn = Timer.periodic(const Duration(seconds: 9), (_) {
      if (mounted && TickerMode.valuesOf(context).enabled && widget.tips.length > 1) setState(() => _i++);
    });
  }

  @override
  void didUpdateWidget(GuideCard old) {
    super.didUpdateWidget(old);
    // The same list again (guideTips keeps it): nothing to do.
    if (identical(old.tips, widget.tips) || old.tips.isEmpty || widget.tips.isEmpty) return;
    // A new situation (a route, the weather): start from the most useful tip.
    if (old.tips.first.key != widget.tips.first.key) {
      _i = 0;
      return;
    }
    // The same situation a little later (a minute less to the last train, a
    // new hour): stay on the tip that is showing.
    final at = widget.tips.indexWhere((t) => t.key == old.tips[_i % old.tips.length].key);
    _i = at >= 0 ? at : _i % old.tips.length;
  }

  @override
  void dispose() {
    _turn?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden || widget.tips.isEmpty) return const SizedBox.shrink();
    final lang = langOf(context);
    final tip = widget.tips[_i % widget.tips.length];
    final warn = tip.kind == TipKind.warn;
    // Reduce motion: the next tip simply replaces the old one.
    final still = MediaQuery.disableAnimationsOf(context);
    final text = SizedBox(
      key: ValueKey('${tip.key}|$lang'),
      width: double.infinity,
      child: PixelText(
        tip.text.of(lang),
        size: 14,
        color: warn ? const Color(0xFFB33A2A) : PixelColors.ink,
        maxLines: 3,
      ),
    );
    return Semantics(
      liveRegion: true,
      label: tip.text.of(lang),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _i++),
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 46,
                height: 60,
                child: _staff == null ? null : CustomPaint(painter: _StaffPainter(_staff!, warn ? 7 : 6)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      key: const ValueKey('guideBubble'),
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 30, 10),
                      decoration: BoxDecoration(
                        color: warn ? const Color(0xFFFFF1EC) : PixelColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: warn ? const Color(0xFFF2B5A6) : PixelColors.line),
                      ),
                      // One text at a time: the old tip fades out completely
                      // in the first half, the new one fades in in the second,
                      // while the bubble grows or shrinks to the new text.
                      child: still
                          ? text
                          : ClipRect(
                              child: AnimatedSize(
                                duration: switchTime,
                                curve: Curves.easeInOut,
                                alignment: Alignment.topLeft,
                                child: AnimatedSwitcher(
                                  duration: switchTime,
                                  switchInCurve: const Interval(0.55, 1, curve: Curves.easeOut),
                                  switchOutCurve: const Interval(0.55, 1, curve: Curves.easeOut),
                                  // The bubble takes the new text's size; the old
                                  // one only fades over it, without holding space.
                                  layoutBuilder: (current, previous) => Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      for (final p in previous) Positioned(left: 0, right: 0, top: 0, child: p),
                                      ?current,
                                    ],
                                  ),
                                  child: text,
                                ),
                              ),
                            ),
                    ),
                    // Tail of the bubble towards the attendant.
                    Positioned(
                      left: -6,
                      bottom: 14,
                      child: Transform.rotate(
                        angle: 0.785,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: warn ? const Color(0xFFFFF1EC) : PixelColors.card,
                            border: Border(
                              left: BorderSide(color: warn ? const Color(0xFFF2B5A6) : PixelColors.line),
                              bottom: BorderSide(color: warn ? const Color(0xFFF2B5A6) : PixelColors.line),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Semantics(
                        button: true,
                        label: MaterialLocalizations.of(context).closeButtonLabel,
                        child: GestureDetector(
                          onTap: () => setState(() => _hidden = true),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close_rounded, size: 16, color: PixelColors.muted),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffPainter extends CustomPainter {
  _StaffPainter(this.image, this.frame);
  final ui.Image image;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final fw = image.width / 8, h = image.height.toDouble();
    final k = size.height / h;
    final w = fw * k;
    // The sheet faces left: mirror it so he faces (and points at) the bubble.
    canvas.save();
    canvas.translate(size.width, 0);
    canvas.scale(-1, 1);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(frame * fw, 0, fw, h),
      Rect.fromLTWH(0, 0, w, size.height),
      Paint()..filterQuality = FilterQuality.none,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StaffPainter old) => old.frame != frame || old.image != image;
}
