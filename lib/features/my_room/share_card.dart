import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/pixel/pixel_scene.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../data/my_stats.dart';
import '../../data/my_store.dart';
import '../../data/sticker_marks.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/share_bridge.dart';
import 'share_gif.dart';
import 'stamp_book_screen.dart';
import 'station_plate.dart';

/// Looks of the share card.
enum ShareStyle { ticket, poster, report }

/// Bottom sheet: a picture card of the user's station to post on X /
/// Instagram through the phone's share menu, in three looks: a commemorative
/// train ticket, a station poster, and this month's ride report. Each shows
/// the level and title, the user's train and their invite code.
class ShareCardSheet extends StatefulWidget {
  const ShareCardSheet({super.key, required this.city, required this.plate, required this.lineColor});

  final CityData city;
  final PlateData plate;
  final Color lineColor;

  @override
  State<ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<ShareCardSheet> {
  final _card = GlobalKey();
  final _cardOnly = GlobalKey();
  final _stickerLayer = GlobalKey();
  final _scene = GlobalKey();
  bool _busy = false;
  ShareStyle _style = ShareStyle.ticket;
  final List<_Placed> _stickers = [];
  int? _moving;

  void _addSticker(String name) => setState(() {
    // A little to the side each time, so new ones don't hide each other.
    final n = _stickers.length;
    _stickers.add(_Placed(name, Offset(120.0 + (n * 37) % 150, 150.0 + (n * 53) % 160), 52));
  });

  /// The moving card: the train pulls in and the passengers get on, as a GIF.
  Future<void> _shareGif() async {
    final t = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      const ratio = 1.2; // 432×540: light and quick enough for a GIF
      Future<ui.Image> grab(GlobalKey k) =>
          (k.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: ratio);
      final cardBox = _cardOnly.currentContext!.findRenderObject()! as RenderBox;
      final sceneBox = _scene.currentContext!.findRenderObject()! as RenderBox;
      final at = sceneBox.localToGlobal(Offset.zero, ancestor: cardBox);
      final card = await grab(_cardOnly);
      final stickers = _stickers.isEmpty ? null : await grab(_stickerLayer);
      final store = Services.my;
      final look = lookWithLed(store.look, widget.plate).withSign(
        StationSign(name: widget.plate.name, sub: widget.plate.kana, band: store.look.trainColor ?? widget.lineColor),
      );
      final place = ShareCard.sceneOf(_style);
      final gif = await buildShareGif(
        card: card,
        stickers: stickers,
        pixelRatio: ratio,
        scene: at & sceneBox.size,
        aspect: place.aspect,
        radius: place.radius,
        look: look,
        lineColor: widget.lineColor,
      );
      card.dispose();
      stickers?.dispose();
      await shareFile(gif, name: 'my_station.gif', mime: 'image/gif', text: t.shareText);
    } catch (e, st) {
      debugPrint('share gif failed: $e $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.shareFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final t = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final boundary = _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1080 / ShareCard.width);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await shareFile(png!.buffer.asUint8List(), name: 'my_station.png', mime: 'image/png', text: t.shareText);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.shareFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final names = {
      ShareStyle.ticket: t.shareStyleTicket,
      ShareStyle.poster: t.shareStylePoster,
      ShareStyle.report: t.shareStyleReport,
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelText(t.shareTitle, size: 24),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final s in ShareStyle.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Chip(label: names[s]!, selected: s == _style, onTap: () => setState(() => _style = s)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: FittedBox(
                child: RepaintBoundary(
                  key: _card,
                  child: SizedBox(
                    width: ShareCard.width,
                    height: ShareCard.height,
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          key: _cardOnly,
                          child: ShareCard(
                            city: widget.city,
                            plate: widget.plate,
                            lineColor: widget.lineColor,
                            style: _style,
                            sceneKey: _scene,
                          ),
                        ),
                        Positioned.fill(
                          child: RepaintBoundary(
                            key: _stickerLayer,
                            child: Stack(
                              children: [
                                for (var i = 0; i < _stickers.length; i++)
                                  Positioned(
                                    left: _stickers[i].at.dx - _stickers[i].size / 2,
                                    top: _stickers[i].at.dy - _stickers[i].size / 2,
                                    width: _stickers[i].size,
                                    height: _stickers[i].size,
                                    child: GestureDetector(
                                      // Drag to move, pinch to resize, double-tap to take off.
                                      onScaleStart: (_) => _moving = i,
                                      onScaleUpdate: (e) => setState(() {
                                        final p = _stickers[i];
                                        p.at = Offset(
                                          (p.at.dx + e.focalPointDelta.dx).clamp(0, ShareCard.width),
                                          (p.at.dy + e.focalPointDelta.dy).clamp(0, ShareCard.height),
                                        );
                                        if (e.pointerCount > 1) {
                                          p.size = (p.base * e.scale).clamp(28, 140);
                                        }
                                      }),
                                      onScaleEnd: (_) {
                                        if (_moving != null && _moving! < _stickers.length) {
                                          _stickers[_moving!].base = _stickers[_moving!].size;
                                        }
                                        _moving = null;
                                      },
                                      onDoubleTap: () => setState(() => _stickers.removeAt(i)),
                                      child: Image.asset(
                                        'assets/art/stickers/${_stickers[i].name}.png',
                                        filterQuality: FilterQuality.none,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Stickers to put on the card.
            Row(
              children: [
                PixelText(t.shareStickers, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.shareStickersHint, style: const TextStyle(fontSize: 10, color: PixelColors.muted)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final name in ownedStickers(Services.my))
                    GestureDetector(
                      onTap: () => _addSticker(name),
                      child: Container(
                        width: 48,
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: PixelColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: PixelColors.line),
                        ),
                        child: Image.asset('assets/art/stickers/$name.png', filterQuality: FilterQuality.none),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _busy ? null : _shareGif,
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PixelColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PixelColors.ink, width: 1.5),
                ),
                child: PixelText(_busy ? t.shareMaking : t.shareAnimated, size: 16),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _busy ? null : _share,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: PixelColors.ink, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.ios_share_rounded, color: PixelColors.card, size: 20),
                    const SizedBox(width: 8),
                    PixelText(t.shareButton, size: 18, color: PixelColors.card),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stickers in assets/art/stickers (tools/cut_gpt_stickers.py).
const stickerNames = [
  'sakura',
  'heart',
  'star',
  'cat',
  'onigiri',
  'fuji',
  'train',
  'ticket',
  'sparkle',
  'hanko',
  'coffee',
  'rainbow',
];

/// A sticker on the card: where its middle is and how big (logical px).
class _Placed {
  _Placed(this.name, this.at, this.size) : base = size;
  final String name;
  Offset at;
  double size;

  /// Size when the current pinch began.
  double base;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? PixelColors.ink : PixelColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? PixelColors.ink : PixelColors.line),
      ),
      child: PixelText(label, size: 13, color: selected ? PixelColors.card : PixelColors.ink),
    ),
  );
}

/// The card itself (360×450 logical; saved at 3×, 1080×1350, Instagram 4:5).
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.city,
    required this.plate,
    required this.lineColor,
    this.style = ShareStyle.ticket,
    this.now,
    this.sceneKey,
  });

  /// Put on the station picture, so the GIF knows where it is.
  final GlobalKey? sceneKey;

  static const width = 360.0;
  static const height = 450.0;

  /// How each look shows the station picture (also used for the GIF).
  static ({double aspect, double radius}) sceneOf(ShareStyle style) => switch (style) {
    ShareStyle.ticket => (aspect: 2.2, radius: 6.0),
    ShareStyle.poster => (aspect: 1.25, radius: 0.0),
    ShareStyle.report => (aspect: 2.4, radius: 10.0),
  };

  final CityData city;
  final PlateData plate;
  final Color lineColor;
  final ShareStyle style;

  /// Japan time (tests).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final jst = now ?? DateTime.now().toUtc().add(const Duration(hours: 9));
    final stats = MyStats.of(city, Services.my, now: jst);
    final data = _CardData(
      city: city,
      plate: plate,
      lineColor: lineColor,
      stats: stats,
      now: jst,
      scene: sceneOf(style),
      sceneKey: sceneKey,
    );
    return SizedBox(
      width: width,
      height: height,
      child: switch (style) {
        ShareStyle.ticket => _TicketCard(data),
        ShareStyle.poster => _PosterCard(data),
        ShareStyle.report => _ReportCard(data),
      },
    );
  }
}

class _CardData {
  const _CardData({
    required this.city,
    required this.plate,
    required this.lineColor,
    required this.stats,
    required this.now,
    required this.scene,
    this.sceneKey,
  });
  final ({double aspect, double radius}) scene;
  final GlobalKey? sceneKey;
  final CityData city;
  final PlateData plate;
  final Color lineColor;
  final MyStats stats;
  final DateTime now;

  MyStore get store => Services.my;

  /// The latest stamps, newest first.
  List<MapEntry<String, String>> recent(int n) =>
      (store.stamps.entries.where((e) => city.stations.containsKey(e.key)).toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(n)
          .toList();
  String get date => '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
}

// ---------------- shared pieces ----------------

/// The station picture, drawn for the saved size (3×), not the screen.
class _Scene extends StatelessWidget {
  const _Scene(this.d);
  final _CardData d;

  @override
  Widget build(BuildContext context) => ClipRRect(
    key: d.sceneKey,
    borderRadius: BorderRadius.circular(d.scene.radius),
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(devicePixelRatio: 1080 / ShareCard.width),
      child: MyStationView(look: d.store.look, plate: d.plate, lineColor: d.lineColor, aspect: d.scene.aspect),
    ),
  );
}

/// "Lv.12" in a little gold badge with the title beside it.
class _LevelTitle extends StatelessWidget {
  const _LevelTitle(this.d, {this.dark = false});
  final _CardData d;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fg = dark ? Colors.white : PixelColors.ink;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFFFFC93C), borderRadius: BorderRadius.circular(6)),
          child: PixelText(t.shareLevel(d.stats.level), size: 13, bold: true, color: PixelColors.ink),
        ),
        const SizedBox(width: 7),
        Expanded(child: PixelText(d.stats.title.of(t.localeName), size: 16, color: fg, maxLines: 1)),
      ],
    );
  }
}

/// The user's train: the colour or the shinkansen they put on in MY.
class _MyTrain extends StatelessWidget {
  const _MyTrain(this.d, {this.size = 40});
  final _CardData d;
  final double size;

  @override
  Widget build(BuildContext context) {
    final look = d.store.look;
    final art = look.trainArt;
    final stripe = look.trainColor ?? d.lineColor;
    return SizedBox(
      width: size * 75 / 96,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(SceneArt.trainBase(DayPart.day, art), filterQuality: FilterQuality.none, fit: BoxFit.contain),
          Image.asset(
            SceneArt.trainStripeOf(art),
            filterQuality: FilterQuality.none,
            fit: BoxFit.contain,
            color: stripe,
            colorBlendMode: BlendMode.modulate,
          ),
        ],
      ),
    );
  }
}

/// The invite code in a little box: friends type it into the app.
class _Invite extends StatelessWidget {
  const _Invite(this.d, {this.dark = false});
  final _CardData d;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fg = dark ? Colors.white : PixelColors.ink;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.shareInvite, style: TextStyle(fontSize: 8.5, color: fg.withValues(alpha: 0.7))),
          PixelText(d.store.inviteCode, size: 16, bold: true, color: fg),
        ],
      ),
    );
  }
}

/// A row of the latest stamps, like a page of the stamp book.
class _Stamps extends StatelessWidget {
  const _Stamps(this.d, {this.n = 5, this.size = 40});
  final _CardData d;
  final int n;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final e in d.recent(n))
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: SizedBox(
            width: size,
            height: size,
            child: StationStamp(
              name: d.city.station(e.key).name.of('ja'),
              day: e.value,
              color: d.city.line(d.city.station(e.key).lines.first).color,
              seed: e.key.hashCode,
            ),
          ),
        ),
    ],
  );
}

class _Brand extends StatelessWidget {
  const _Brand({this.dark = false});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fg = dark ? Colors.white : PixelColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/art/tab_platform.png', width: 18, height: 18, filterQuality: FilterQuality.none),
        const SizedBox(width: 5),
        PixelText(t.appTitle, size: 14, color: fg),
      ],
    );
  }
}

// ---------------- ① commemorative ticket (硬券) ----------------

class _TicketCard extends StatelessWidget {
  const _TicketCard(this.d);
  final _CardData d;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    const paper = Color(0xFFF6EBD2), ink = Color(0xFF3B2F2A), red = Color(0xFFC8432F);
    return Container(
      color: const Color(0xFF2B3A4A),
      padding: const EdgeInsets.all(14),
      child: CustomPaint(
        painter: _TicketPaper(paper: paper, band: d.lineColor),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // A red "乗車記念" stamp.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: red, width: 1.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: PixelText(t.shareTicketHead, size: 13, color: red),
                  ),
                  const Spacer(),
                  PixelText(t.shareTicketNo(d.stats.trips.toString().padLeft(5, '0')), size: 12, color: ink),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(child: PixelText(d.plate.name, size: 30, bold: true, color: ink, maxLines: 1)),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: PixelText(t.shareStampUnit, size: 16, color: ink),
                  ),
                ],
              ),
              if (d.plate.kana.isNotEmpty) PixelText(d.plate.kana, size: 12, color: ink.withValues(alpha: 0.6)),
              const SizedBox(height: 8),
              _Scene(d),
              const SizedBox(height: 10),
              _LevelTitle(d),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MyTrain(d, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Row(label: t.shareStamps, value: '${d.stats.stamps}${t.shareStampUnit}', color: ink),
                        _Row(label: t.shareLines, value: '${d.stats.linesDone.length}${t.shareLineUnit}', color: ink),
                      ],
                    ),
                  ),
                  _Invite(d),
                ],
              ),
              const Spacer(),
              _Stamps(d, n: 6, size: 44),
              const Spacer(),
              // Perforation, then the stub with the date.
              CustomPaint(size: const Size(double.infinity, 2), painter: _Dots(ink.withValues(alpha: 0.35))),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: PixelText(t.shareTicketValid(d.date), size: 11, color: ink, maxLines: 1)),
                  const _Brand(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
        const SizedBox(width: 6),
        PixelText(value, size: 14, bold: true, color: color),
      ],
    ),
  );
}

/// Ticket paper: cream card with the line-colour band at the top, punched
/// half-circles on both sides and a faint wavy pattern.
class _TicketPaper extends CustomPainter {
  _TicketPaper({required this.paper, required this.band});
  final Color paper;
  final Color band;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    final notch = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, size.height * 0.62), radius: 10))
      ..addOval(Rect.fromCircle(center: Offset(size.width, size.height * 0.62), radius: 10));
    final shape = Path.combine(PathOperation.difference, Path()..addRRect(r), notch);
    canvas.drawPath(shape, Paint()..color = paper);
    canvas.save();
    canvas.clipPath(shape);
    final wave = Paint()
      ..color = const Color(0x14A0603A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 7) {
      final p = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 6) {
        p.lineTo(x, y + ((x ~/ 6).isEven ? 2 : -2));
      }
      canvas.drawPath(p, wave);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 8), Paint()..color = band);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TicketPaper old) => old.band != band || old.paper != paper;
}

class _Dots extends CustomPainter {
  _Dots(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawCircle(Offset(x, size.height / 2), 1.1, p);
    }
  }

  @override
  bool shouldRepaint(_Dots old) => old.color != color;
}

// ---------------- ② station poster ----------------

class _PosterCard extends StatelessWidget {
  const _PosterCard(this.d);
  final _CardData d;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      color: const Color(0xFF1B2233),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Scene(d),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LevelTitle(d, dark: true),
                  const SizedBox(height: 8),
                  // The best lines, as bars in their own colours.
                  for (final p in d.stats.lineProgress.take(2))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 92,
                            child: Text(
                              d.city.line(p.lineId).name.of(t.localeName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: SizedBox(
                                height: 6,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    const ColoredBox(color: Colors.white12),
                                    FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: p.done / p.total,
                                      child: ColoredBox(color: d.city.line(p.lineId).color),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${p.done}/${p.total}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _DarkStat(label: t.shareStamps, value: '${d.stats.stamps}', unit: t.shareStampUnit),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _DarkStat(
                          label: t.shareLines,
                          value: '${d.stats.linesDone.length}',
                          unit: t.shareLineUnit,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _DarkStat(
                          label: t.shareReportTrips,
                          value: '${d.stats.trips}',
                          unit: t.shareReportTripUnit,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _Stamps(d, n: 5, size: 38)),
                      _MyTrain(d, size: 44),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [const _Brand(dark: true), const Spacer(), _Invite(d, dark: true)]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkStat extends StatelessWidget {
  const _DarkStat({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, style: const TextStyle(fontSize: 9, color: Colors.white60)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: PixelText(value, size: 18, bold: true, color: Colors.white, maxLines: 1)),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: PixelText(unit, size: 10, color: Colors.white70),
            ),
          ],
        ),
      ],
    ),
  );
}

// ---------------- ③ this month's ride report ----------------

class _ReportCard extends StatelessWidget {
  const _ReportCard(this.d);
  final _CardData d;

  static const _monthEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final m = d.stats.month;
    final top = m.topLine == null ? null : d.city.line(m.topLine!);
    final month = t.localeName == 'en' ? _monthEn[m.month - 1] : '${m.month}';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4E0), Color(0xFFE8F1FF)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelText(t.shareReportTitle(month), size: 22, bold: true),
          const SizedBox(height: 6),
          _LevelTitle(d),
          const SizedBox(height: 10),
          _Scene(d),
          const SizedBox(height: 10),
          if (m.trips == 0)
            Expanded(
              child: Center(child: PixelText(t.shareReportNone, size: 16, color: PixelColors.muted)),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _Big(label: t.shareReportTrips, value: '${m.trips}', unit: t.shareReportTripUnit),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Big(label: t.shareReportKm, value: m.km.toStringAsFixed(m.km < 100 ? 1 : 0), unit: 'km'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Big(label: t.shareReportStations, value: '${m.stations}', unit: t.shareStampUnit),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (top != null)
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Text(t.shareReportTopLine, style: const TextStyle(fontSize: 10, color: PixelColors.muted)),
                    const Spacer(),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: top.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    PixelText(top.name.of(t.localeName), size: 14, bold: true),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _Time(icon: 'sun', label: t.shareReportEarliest, minute: m.earliest),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Time(icon: 'moon', label: t.shareReportLatest, minute: m.latest),
                ),
              ],
            ),
            const Spacer(),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [_MyTrain(d, size: 40), const SizedBox(width: 8), const _Brand(), const Spacer(), _Invite(d)],
          ),
        ],
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: PixelColors.muted)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: PixelText(value, size: 22, bold: true, maxLines: 1)),
            const SizedBox(width: 2),
            Padding(padding: const EdgeInsets.only(bottom: 3), child: PixelText(unit, size: 11)),
          ],
        ),
      ],
    ),
  );
}

class _Time extends StatelessWidget {
  const _Time({required this.icon, required this.label, required this.minute});
  final String icon;
  final String label;
  final int? minute;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
    child: Row(
      children: [
        // The widget's pixel weather icons.
        Image.asset('assets/art/widget/icon_$icon.png', width: 24, height: 24, filterQuality: FilterQuality.none),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 9, color: PixelColors.muted)),
              PixelText(minute == null ? '―' : MonthRides.clock(minute!), size: 16, bold: true),
            ],
          ),
        ),
      ],
    ),
  );
}
