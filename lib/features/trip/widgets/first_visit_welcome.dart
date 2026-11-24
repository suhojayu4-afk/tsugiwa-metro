import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app.dart';
import '../../../core/localized_text.dart';
import '../../../core/pixel/pixel_ui.dart';
import '../../../core/services.dart';
import '../../../data/models/city.dart';
import '../../../data/models/route_map.dart';
import '../../album/album_screen.dart';
import '../../album/postcard_book.dart';
import '../../album/postcard_view.dart';
import '../../guide/guide_card.dart';
import '../../route_map/landmark_sheet.dart';

LocalizedText _t(String ja, String ko, String en) => LocalizedText({'ja': ja, 'ko': ko, 'en': en});

LocalizedText _hello(String st) => _t('はじめまして、$st駅！', '처음 뵙겠습니다, $st역!', 'Nice to meet you, $st!');
final _firstTime = _t('はじめて来た駅です。スタンプをどうぞ', '처음 온 역이에요. 스탬프를 드릴게요', 'Your first time here. Have a stamp!');
final _nearby = _t('近くの名所', '근처 명소', 'Nearby');
final _postcard = _t('はがきが届きました', '엽서가 도착했어요', 'A postcard has arrived');
final _album = _t('アルバムで見る', '앨범에서 보기', 'Open the album');
final _ok = _t('OK', '확인', 'OK');

/// The welcome at a station reached for the first time: its station sign
/// swings down, つぎはさん says hello, the nearest sight and the postcard of
/// the day come up, and little pieces of colour fall. Tap OK (or outside).
Future<void> showFirstVisitWelcome(
  BuildContext context, {
  required CityData city,
  required String stationId,
  String? lineId,
}) {
  HapticFeedback.mediumImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'welcome',
    barrierColor: const Color(0xCC141826),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, _, _) => FirstVisitWelcome(city: city, stationId: stationId, lineId: lineId),
  );
}

class FirstVisitWelcome extends StatefulWidget {
  const FirstVisitWelcome({super.key, required this.city, required this.stationId, this.lineId});
  final CityData city;
  final String stationId;
  final String? lineId;

  @override
  State<FirstVisitWelcome> createState() => _FirstVisitWelcomeState();
}

class _FirstVisitWelcomeState extends State<FirstVisitWelcome> with TickerProviderStateMixin {
  late final _swing = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final _fall = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  ({String name, String image, LocalizedText about})? _sight;

  @override
  void initState() {
    super.initState();
    _swing.forward();
    _fall.repeat();
    _findSight();
  }

  /// The landmark whose nearest stations include this one.
  Future<void> _findSight() async {
    try {
      final info = await loadLandmarkInfo(widget.city.id);
      final map = await RouteMapData.load(widget.city.id);
      for (final lm in map.landmarks) {
        final key = landmarkKey(lm);
        final i = info[key];
        if (i != null && i.stations.contains(widget.stationId)) {
          if (mounted) setState(() => _sight = (name: lm.name.of(langOf(context)), image: lm.image, about: i.about));
          return;
        }
      }
    } catch (_) {
      // Only a nicety.
    }
  }

  @override
  void dispose() {
    _swing.dispose();
    _fall.dispose();
    super.dispose();
  }

  Postcard? get _card {
    final today = DateTime.now().toUtc().add(const Duration(hours: 9)).toIso8601String().substring(0, 10);
    return PostcardBook.instance.cards.where((c) => c.station == widget.stationId && c.day == today).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    final city = widget.city;
    final st = city.station(widget.stationId);
    final lineId = widget.lineId ?? st.lines.first;
    final line = city.line(lineId);
    final i = line.stations.indexOf(widget.stationId);
    String? nameAt(int k) => k >= 0 && k < line.stations.length ? city.station(line.stations[k]).name.ja : null;
    final still = MediaQuery.disableAnimationsOf(context);
    final card = _card;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Little pieces of colour falling (not with reduce motion).
          if (!still)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _fall,
                  builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_fall.value, line.color)),
                ),
              ),
            ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The station sign drops in on its wires and settles.
                    AnimatedBuilder(
                      animation: _swing,
                      builder: (context, child) {
                        final v = still ? 1.0 : _swing.value;
                        final drop = Curves.easeOutBack.transform(math.min(1, v * 2.2));
                        final angle = still ? 0.0 : math.sin(v * math.pi * 5) * 0.12 * (1 - v);
                        return Transform.translate(
                          offset: Offset(0, (1 - drop) * -160),
                          child: Transform.rotate(angle: angle, alignment: Alignment.topCenter, child: child),
                        );
                      },
                      child: _StationSign(
                        name: st.name.ja,
                        kana: st.kana,
                        en: st.name.of('en'),
                        color: line.color,
                        prev: nameAt(i - 1),
                        next: nameAt(i + 1),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const AttendantFigure(pointing: true, height: 70),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(color: PixelColors.card, borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PixelText(_hello(st.name.of(lang)).of(lang), size: 18),
                                const SizedBox(height: 2),
                                PixelText(_firstTime.of(lang), size: 13, color: PixelColors.muted),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_sight case final s?) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: PixelColors.card, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: Image.asset(s.image, filterQuality: FilterQuality.none, fit: BoxFit.contain),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PixelText(_nearby.of(lang), size: 11, color: PixelColors.muted),
                                  PixelText(s.name, size: 16),
                                  PixelText(s.about.of(lang), size: 12, color: PixelColors.muted, maxLines: 2),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (card != null) ...[
                      const SizedBox(height: 14),
                      PixelText(_postcard.of(lang), size: 14, color: PixelColors.card),
                      const SizedBox(height: 8),
                      Transform.rotate(
                        angle: -0.04,
                        child: SizedBox(
                          width: 250,
                          child: PostcardFront(city: city, card: card, my: Services.my, small: true),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (card != null) ...[
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PixelColors.card,
                                side: BorderSide(color: PixelColors.card),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.of(context)
                                    .push(MaterialPageRoute<void>(builder: (_) => AlbumScreen(city: city)));
                              },
                              child: Text(_album.of(lang)),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey('firstVisit.ok'),
                            onPressed: () => Navigator.pop(context),
                            child: Text(_ok.of(lang)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 駅名標: white board, the name big, its reading, the English name, the
/// line's band with the stations either side.
class _StationSign extends StatelessWidget {
  const _StationSign({
    required this.name,
    required this.kana,
    required this.en,
    required this.color,
    this.prev,
    this.next,
  });
  final String name, kana, en;
  final Color color;
  final String? prev, next;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The wires it hangs from.
        SizedBox(width: 220, height: 26, child: CustomPaint(painter: _WiresPainter())),
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF2B2F3A), width: 3),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              PixelText(kana, size: 13, color: PixelColors.muted),
              PixelText(name, size: 40),
              PixelText(en.toUpperCase(), size: 12, color: PixelColors.muted),
              const SizedBox(height: 8),
              Container(
                color: color,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (prev != null) const Icon(Icons.arrow_left_rounded, color: Colors.white, size: 18),
                          Flexible(child: PixelText(prev ?? '', size: 12, color: Colors.white, maxLines: 1)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(child: PixelText(next ?? '', size: 12, color: Colors.white, maxLines: 1)),
                          if (next != null) const Icon(Icons.arrow_right_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WiresPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFB9C0CC)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(size.width * 0.15, 0), Offset(size.width * 0.15, size.height), p);
    canvas.drawLine(Offset(size.width * 0.85, 0), Offset(size.width * 0.85, size.height), p);
  }

  @override
  bool shouldRepaint(_WiresPainter old) => false;
}

/// Small square pieces of colour (the line's colour and a few happy ones)
/// falling and turning, in a 4 second loop.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.lineColor);
  final double t;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [lineColor, const Color(0xFFFFD166), const Color(0xFFFF8FB1), const Color(0xFF7FDBDA), Colors.white];
    final r = math.Random(3);
    for (var i = 0; i < 46; i++) {
      final x0 = r.nextDouble() * size.width;
      final speed = 0.6 + r.nextDouble() * 0.8;
      final phase = r.nextDouble();
      final y = ((t * speed + phase) % 1) * (size.height + 40) - 20;
      final x = x0 + math.sin((t + phase) * math.pi * 4) * 14;
      final s = 4.0 + r.nextInt(3) * 2;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((t + phase) * math.pi * 2 * (i.isEven ? 1 : -1));
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: s, height: s * 0.6),
        Paint()..color = colors[i % colors.length],
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
