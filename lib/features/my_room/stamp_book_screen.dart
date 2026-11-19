import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../data/models/rail_line.dart';
import '../../l10n/app_localizations.dart';

/// 駅スタンプ帳: a stamp for every station reached, line by line. Finishing
/// a line gives that line's reward item in MY駅.
class StampBookScreen extends StatelessWidget {
  const StampBookScreen({super.key, required this.city});
  final CityData city;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final store = Services.my;
    final all = city.stations.keys.toSet();
    final done = all.where(store.stamped).length;
    return Scaffold(
      backgroundColor: PixelColors.background,
      appBar: AppBar(
        backgroundColor: PixelColors.background,
        surfaceTintColor: Colors.transparent,
        title: PixelText(t.stampTitle, size: 22),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            PixelText(t.stampTotal(done, all.length), size: 16, color: PixelColors.muted),
            const SizedBox(height: 4),
            PixelText(t.stampHint, size: 12, color: PixelColors.muted),
            for (final line in city.lines) _LineSection(city: city, line: line),
            if (kDebugMode)
              for (final line in city.lines)
                TextButton(
                  onPressed: () => store.rewardTrip(line.stations),
                  child: Text('${t.myTestCoins}: ${line.name.of('ja')}'),
                ),
          ],
        ),
      ),
    );
  }
}

class _LineSection extends StatelessWidget {
  const _LineSection({required this.city, required this.line});
  final CityData city;
  final RailLine line;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final store = Services.my;
    final progress = store.lineProgress(line.id);
    final reward = store.rewardFor(line.id);
    final complete = store.lineComplete(line.id);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 6, height: 22, color: line.color),
              const SizedBox(width: 8),
              Expanded(child: PixelText(line.name.of(lang), size: 19)),
              PixelText('${progress.done}/${progress.total}', size: 17, bold: true),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.total == 0 ? 0 : progress.done / progress.total,
              minHeight: 6,
              color: line.color,
              backgroundColor: PixelColors.line,
            ),
          ),
          if (reward != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: complete ? const Color(0xFFFFF4D6) : PixelColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: complete ? const Color(0xFFE2A61E) : PixelColors.line),
              ),
              child: Row(
                children: [
                  Icon(
                    complete ? Icons.emoji_events_rounded : Icons.card_giftcard_rounded,
                    size: 20,
                    color: complete ? const Color(0xFFE2A61E) : PixelColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PixelText(
                      complete ? t.stampRewardGot(reward.name.of(lang)) : t.stampReward(reward.name.of(lang)),
                      size: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final id in line.stations)
                StationStamp(
                  name: city.station(id).name.of('ja'),
                  day: store.stamps[id],
                  color: line.color,
                  seed: id.hashCode,
                  gold: store.stayed(id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One stamp: inked in the line colour once visited (with the day), a
/// faint dotted circle before.
class StationStamp extends StatelessWidget {
  const StationStamp({
    super.key,
    required this.name,
    required this.day,
    required this.color,
    this.seed = 0,
    this.gold = false,
  });

  /// Stayed there 5 minutes: gold ink and a star.
  final bool gold;

  final String name;

  /// First visit day (yyyy-mm-dd); null = not yet visited.
  final String? day;
  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _StampPainter(name: name, day: day, color: gold ? _gold : color, seed: seed, gold: gold),
  );
}

const _gold = Color(0xFFC9951E);

class _StampPainter extends CustomPainter {
  _StampPainter({required this.name, required this.day, required this.color, required this.seed, this.gold = false});
  final String name;
  final String? day;
  final Color color;
  final int seed;
  final bool gold;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 3;
    final got = day != null;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    // Real stamps are never quite straight.
    if (got) canvas.rotate(((seed % 15) - 7) * math.pi / 180);
    final ink = got ? color.withValues(alpha: 0.9) : PixelColors.line;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = ink;
    if (got) {
      canvas.drawCircle(Offset.zero, r, ring..strokeWidth = 2.6);
      canvas.drawCircle(Offset.zero, r - 5, ring..strokeWidth = 1);
      // A little train at the top.
      final p = Paint()..color = ink;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-7, -r + 7, 14, 6), const Radius.circular(1.5)),
        p,
      );
      canvas.drawRect(Rect.fromLTWH(-5, -r + 8.5, 3, 2), Paint()..color = PixelColors.card);
      canvas.drawRect(Rect.fromLTWH(2, -r + 8.5, 3, 2), Paint()..color = PixelColors.card);
      if (gold) {
        // Gold: a soft fill and a small star on the right of the ring.
        canvas.drawCircle(Offset.zero, r - 5, Paint()..color = const Color(0x22E8B33A));
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * math.pi / 5;
          final rr = i.isEven ? 5.5 : 2.4;
          final q = Offset(r * 0.72 + rr * math.cos(a), -r * 0.62 + rr * math.sin(a));
          i == 0 ? star.moveTo(q.dx, q.dy) : star.lineTo(q.dx, q.dy);
        }
        canvas.drawPath(star..close(), Paint()..color = const Color(0xFFE8B33A));
      }
    } else {
      // Dotted outline.
      const n = 28;
      for (var i = 0; i < n; i += 2) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r),
          i * 2 * math.pi / n,
          2 * math.pi / n,
          false,
          ring..strokeWidth = 1.5,
        );
      }
    }
    _text(
      canvas,
      name,
      r * (name.length > 3 ? 0.42 : 0.5),
      got ? ink : PixelColors.muted,
      Offset(0, got ? 1 : 0),
      r * 1.5,
    );
    if (got && day!.length >= 10) {
      _text(
        canvas,
        '${int.parse(day!.substring(5, 7))}.${int.parse(day!.substring(8, 10))}',
        r * 0.28,
        ink,
        Offset(0, r * 0.55),
        r,
      );
    }
    canvas.restore();
  }

  void _text(Canvas canvas, String s, double size, Color color, Offset at, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: 'DotGothic16', fontSize: size, color: color, height: 1),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final k = tp.width > maxWidth ? maxWidth / tp.width : 1.0;
    canvas.save();
    canvas.translate(at.dx - tp.width * k / 2, at.dy - tp.height / 2);
    canvas.scale(k, 1);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
    tp.dispose();
  }

  @override
  bool shouldRepaint(_StampPainter old) =>
      old.day != day || old.name != name || old.color != color || old.gold != gold;
}
