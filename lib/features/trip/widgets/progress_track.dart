import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_ui.dart';
import '../trip_plan.dart';

/// Pixel rail with station blocks and the user's pixel train running on top.
/// The train's nose points at the current position, so it starts at the left
/// edge and stops exactly at the last station on the right edge.
class ProgressTrack extends StatefulWidget {
  const ProgressTrack({
    super.key,
    required this.plan,
    required this.progress,
    required this.moving,
    required this.lineColorOf,
    this.sprite,
  });

  final TripPlan plan;
  final double progress;
  final bool moving;
  final Color Function(String lineId) lineColorOf;
  final PixelSprite? sprite;

  @override
  State<ProgressTrack> createState() => _ProgressTrackState();
}

class _ProgressTrackState extends State<ProgressTrack> {
  static const _px = 1.0; // 128×56 train at 1 logical px: fine 64-bit-era detail
  static const _railH = pu * 3;
  int _frame = 0;
  Timer? _wheels;

  @override
  void initState() {
    super.initState();
    _wheels = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (widget.moving && mounted) setState(() => _frame++);
    });
  }

  @override
  void dispose() {
    _wheels?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sprite = widget.sprite ?? Sprites.starterTrain;
    final plan = widget.plan;
    final trainW = sprite.width * _px;
    final trainH = sprite.height * _px;
    final railTop = trainH - _px;
    final nose = trainW - 4 * _px; // where the nose sits inside the sprite
    final color = widget.lineColorOf(plan.lineAt(_currentIndex()));

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        double xOf(double fraction) => nose + (w - nose - 8) * fraction;
        double fractionOf(int i) => plan.totalSec == 0 ? 0 : plan.stops[i].arriveSec / plan.totalSec;

        return SizedBox(
          height: railTop + _railH + pu * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: railTop,
                child: CustomPaint(
                  size: Size(w, _railH),
                  painter: _RailPainter(
                    segments: [
                      for (var i = 0; i + 1 < plan.stops.length; i++)
                        (
                          xOf(fractionOf(i)),
                          xOf(fractionOf(i + 1)),
                          widget.lineColorOf(plan.stops[i + 1].lineId),
                        ),
                    ],
                    start: nose,
                    filledTo: xOf(widget.progress),
                  ),
                ),
              ),
              for (var i = 0; i < plan.stops.length; i++)
                _block(
                  xOf(fractionOf(i)),
                  railTop,
                  PixelSquare(
                    color: widget.lineColorOf(plan.stops[i].lineId),
                    size: plan.stops[i].transferToLineId != null ? 18 : 12,
                    hollow: true,
                  ),
                  plan.stops[i].transferToLineId != null ? 18 : 12,
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 900),
                left: xOf(widget.progress) - nose,
                top: 0,
                child: PixelSpriteView(sprite: sprite, pixelSize: _px, frame: _frame, lineColor: color),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _block(double x, double railTop, Widget child, double size) =>
      Positioned(left: x - size / 2, top: railTop + _railH / 2 - size / 2, child: child);

  int _currentIndex() {
    final plan = widget.plan;
    final elapsed = widget.progress * plan.totalSec;
    var current = 0;
    for (var i = 0; i < plan.stops.length; i++) {
      if (plan.stops[i].arriveSec <= elapsed) current = i;
    }
    return current;
  }
}

/// Rail: grey where the train has not been yet; each travelled segment in the
/// colour of the line ridden on it.
class _RailPainter extends CustomPainter {
  _RailPainter({required this.segments, required this.start, required this.filledTo});

  final List<(double, double, Color)> segments;
  final double start;
  final double filledTo;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    p.color = PixelColors.soft;
    canvas.drawRect(Rect.fromLTWH(start, 0, size.width - start - 8, size.height), p);
    for (final (a, b, c) in segments) {
      final end = b < filledTo ? b : filledTo;
      if (end <= a) continue;
      p.color = c;
      canvas.drawRect(Rect.fromLTRB(a, 0, end, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) => old.filledTo != filledTo || old.segments != segments;
}
