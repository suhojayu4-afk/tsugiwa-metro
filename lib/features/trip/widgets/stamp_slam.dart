import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/pixel/pixel_ui.dart';
import '../../my_room/stamp_book_screen.dart';

/// The stamps earned on a trip, pressed onto the arrival card one after
/// another: each comes down big and a little tilted, then lands with a small
/// buzz. With "reduce motion" on they are simply shown.
class StampSlam extends StatefulWidget {
  const StampSlam({super.key, required this.stamps});

  /// Station name (Japanese) and line colour of each new stamp.
  final List<({String name, Color color})> stamps;

  static const shown = 6, size = 64.0, step = 0.22, land = 0.36; // seconds

  @override
  State<StampSlam> createState() => _StampSlamState();
}

class _StampSlamState extends State<StampSlam> with SingleTickerProviderStateMixin {
  late final _items = widget.stamps.take(StampSlam.shown).toList();
  late final double _total = StampSlam.land + StampSlam.step * (_items.length - 1);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_total * 1000).round()),
  );
  int _buzzed = 0;

  @override
  void initState() {
    super.initState();
    _c.addListener(_buzz);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  /// One light buzz as each stamp lands.
  void _buzz() {
    final landed = (((_c.value * _total) - StampSlam.land) / StampSlam.step).floor() + 2;
    final n = landed.clamp(0, _items.length);
    if (n > _buzzed) {
      _buzzed = n;
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jp = DateTime.now().toUtc().add(const Duration(hours: 9));
    final day = DateFormat('yyyy-MM-dd').format(jp);
    final more = widget.stamps.length - _items.length;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, s) in _items.indexed)
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final start = StampSlam.step * i / _total;
              final end = ((StampSlam.step * i + StampSlam.land) / _total).clamp(0.0, 1.0);
              final p = Interval(start, end, curve: Curves.easeOutBack).transform(_c.value);
              final appear = Interval(start, end).transform(_c.value);
              return Opacity(
                opacity: (appear * 2.5).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: (1 - p) * (i.isEven ? 0.35 : -0.35),
                  child: Transform.scale(scale: 1.9 - 0.9 * p, child: child),
                ),
              );
            },
            child: SizedBox.square(
              dimension: StampSlam.size,
              child: StationStamp(name: s.name, day: day, color: s.color, seed: s.name.hashCode),
            ),
          ),
        if (more > 0) PixelText('+$more', size: 17, color: const Color(0xFFB7791F)),
      ],
    );
  }
}
