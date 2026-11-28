import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/pixel/pixel_ui.dart';
import '../trip_plan.dart';

/// The whole trip as one rounded rail: stations as dots (a ring where the
/// user changes), the part already travelled in the colour of each line
/// ridden, and a small train (the same paper style as the view at the top)
/// riding on it with its shadow. The nose points at where the trip is now,
/// so it starts at the left end and stops at the last station on the right.
class ProgressTrack extends StatefulWidget {
  const ProgressTrack({
    super.key,
    required this.plan,
    required this.progress,
    required this.moving,
    required this.lineColorOf,
  });

  final TripPlan plan;
  final double progress;
  final bool moving;
  final Color Function(String lineId) lineColorOf;

  @override
  State<ProgressTrack> createState() => _ProgressTrackState();
}

class _ProgressTrackState extends State<ProgressTrack> with SingleTickerProviderStateMixin {
  static const _trainW = 58.0;
  static const _trainH = 22.0;
  static const _railY = _trainH + 8;
  static const _railH = 6.0;

  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _time.value = e.inMicroseconds / 1e6);
    if (widget.moving) _ticker.start();
  }

  @override
  void didUpdateWidget(ProgressTrack old) {
    super.didUpdateWidget(old);
    if (widget.moving && !_ticker.isActive) _ticker.start();
    if (!widget.moving && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final color = widget.lineColorOf(plan.lineAt(_currentIndex()));
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        const left = _trainW - 6; // the nose at the first station
        double xOf(double fraction) => left + (w - left - 8) * fraction;
        double fractionOf(int i) => plan.totalSec == 0 ? 0 : plan.stops[i].arriveSec / plan.totalSec;
        return SizedBox(
          height: _railY + _railH + 10,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RailPainter(
                    segments: [
                      for (var i = 0; i + 1 < plan.stops.length; i++)
                        (xOf(fractionOf(i)), xOf(fractionOf(i + 1)), widget.lineColorOf(plan.stops[i + 1].lineId)),
                    ],
                    stops: [
                      for (var i = 0; i < plan.stops.length; i++)
                        (
                          xOf(fractionOf(i)),
                          widget.lineColorOf(plan.stops[i].lineId),
                          plan.stops[i].transferToLineId != null || i == plan.lastIndex,
                        ),
                    ],
                    start: left,
                    end: w - 8,
                    filledTo: xOf(widget.progress),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                left: xOf(widget.progress) - left,
                top: 0,
                width: _trainW,
                height: _railY,
                child: ValueListenableBuilder<double>(
                  valueListenable: _time,
                  builder: (context, t, _) => CustomPaint(
                    painter: _MiniTrainPainter(color: color, bob: widget.moving ? math.sin(t * 9) : 0),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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

class _RailPainter extends CustomPainter {
  _RailPainter({
    required this.segments,
    required this.stops,
    required this.start,
    required this.end,
    required this.filledTo,
  });

  final List<(double, double, Color)> segments;

  /// x, colour, and whether it is a change (or the last stop): a ring.
  final List<(double, Color, bool)> stops;
  final double start;
  final double end;
  final double filledTo;

  static const y = _ProgressTrackState._railY;
  static const h = _ProgressTrackState._railH;

  @override
  void paint(Canvas canvas, Size size) {
    final rail = RRect.fromRectAndRadius(Rect.fromLTRB(start - h / 2, y, end + h / 2, y + h), const Radius.circular(h));
    canvas.drawRRect(rail.shift(const Offset(0, 2)), Paint()..color = const Color(0x14000000));
    canvas.drawRRect(rail, Paint()..color = PixelColors.soft);
    canvas.save();
    canvas.clipRRect(rail);
    for (final (a, b, c) in segments) {
      final to = math.min(b, filledTo);
      if (to <= a) continue;
      canvas.drawRect(Rect.fromLTRB(a, y, to, y + h), Paint()..color = c);
    }
    canvas.restore();
    var lastX = -1e9;
    for (final (x, c, ring) in stops) {
      // Stations close together: the small dots would run into each other.
      if (!ring && x - lastX < 10) continue;
      lastX = x;
      final passed = x <= filledTo + 0.5;
      final center = Offset(x, y + h / 2);
      if (ring) {
        canvas.drawCircle(center, 7, Paint()..color = PixelColors.card);
        canvas.drawCircle(
          center,
          6,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      } else {
        canvas.drawCircle(center, 3.5, Paint()..color = passed ? PixelColors.card : c.withValues(alpha: 0.55));
      }
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) => old.filledTo != filledTo || old.segments != segments || old.stops != stops;
}

/// Two short cars in the paper style of the top view, nose on the right.
class _MiniTrainPainter extends CustomPainter {
  _MiniTrainPainter({required this.color, required this.bob});
  final Color color;

  /// -1 … 1 while running: a gentle rock.
  final double bob;

  @override
  void paint(Canvas canvas, Size size) {
    const bodyH = 17.0;
    final baseY = size.height - 3;
    // Shadow on the rail.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2, baseY - 2, size.width - 4, 5), const Radius.circular(3)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    const cars = 2;
    const gap = 2.0;
    final carW = (size.width - gap) / cars;
    for (var i = 0; i < cars; i++) {
      final x = i * (carW + gap);
      final lead = i == cars - 1;
      final y = baseY - 4 - bodyH + (bob > 0.6 && i == 0 ? -0.6 : 0) + (bob < -0.6 && lead ? -0.6 : 0);
      final body = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, carW, bodyH),
        topLeft: const Radius.circular(4),
        bottomLeft: const Radius.circular(2),
        topRight: Radius.circular(lead ? 9 : 4),
        bottomRight: const Radius.circular(2),
      );
      final wheel = Paint()..color = const Color(0xFF2B2C33);
      canvas.drawCircle(Offset(x + 6, baseY - 3), 2.4, wheel);
      canvas.drawCircle(Offset(x + carW - 6, baseY - 3), 2.4, wheel);
      canvas.drawRRect(body.shift(const Offset(0, 1.5)), Paint()..color = const Color(0x22000000));
      canvas.drawRRect(body, Paint()..color = const Color(0xFFF4F5F7));
      canvas.save();
      canvas.clipRRect(body);
      canvas.drawRect(Rect.fromLTWH(x, y + bodyH - 6, carW, 3), Paint()..color = color);
      canvas.drawRect(Rect.fromLTWH(x, y, carW, 2), Paint()..color = const Color(0xFFD9DCE2));
      canvas.restore();
      final glass = Paint()..color = const Color(0xFF3D4D66);
      for (var wx = x + 3.0; wx + 5 < x + carW - (lead ? 9 : 2); wx += 7) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(wx, y + 4, 5, 5), const Radius.circular(1)), glass);
      }
      if (lead) {
        canvas.drawPath(
          Path()
            ..moveTo(x + carW - 9, y + 4)
            ..lineTo(x + carW - 4, y + 4)
            ..quadraticBezierTo(x + carW - 1, y + 6, x + carW - 1, y + 9)
            ..lineTo(x + carW - 9, y + 9)
            ..close(),
          glass,
        );
        canvas.drawCircle(Offset(x + carW - 2, y + bodyH - 4), 1.2, Paint()..color = const Color(0xFFFFF2B0));
      }
    }
  }

  @override
  bool shouldRepaint(_MiniTrainPainter old) => old.color != color || old.bob != bob;
}
