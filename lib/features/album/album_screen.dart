import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/japan_time.dart';
import '../../core/localized_text.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../data/weather/weather_source.dart';
import '../../platform/share_bridge.dart';
import 'postcard_book.dart';
import 'postcard_view.dart';

LocalizedText _t(String ja, String ko, String en) => LocalizedText({'ja': ja, 'ko': ko, 'en': en});

final albumTitle = _t('旅のアルバム', '여행 앨범', 'Travel Album');
final _empty = _t(
  'まだはがきがありません。\n電車で出かけて降りた駅から、一枚ずつ届きます。',
  '아직 엽서가 없어요.\n전철로 나가서 내린 역마다 한 장씩 도착해요.',
  'No postcards yet.\nEach station you get off at sends you one.',
);
final _yearAgo = _t('むかしの今日', '그날의 오늘', 'On this day');
final _flip = _t('うらがえす', '뒤집기', 'Turn over');
final _memo = _t('ひとこと書く', '한마디 쓰기', 'Write a line');
final _share = _t('シェア', '공유', 'Share');
final _memoHint = _t('この日のことを、ひとこと', '이날의 일을 한마디로', 'A line about this day');
final _save = _t('書く', '쓰기', 'Write');
final _cancel = _t('やめる', '그만두기', 'Cancel');

String _count(int n, String lang) => switch (lang) {
  'ko' => '엽서 $n장',
  'en' => n == 1 ? '1 postcard' : '$n postcards',
  _ => 'はがき $n枚',
};

String _month(String day, String lang) {
  final y = day.substring(0, 4), m = int.parse(day.substring(5, 7));
  return switch (lang) {
    'ko' => '$y년 $m월',
    'en' => '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1]} $y',
    _ => '$y年$m月',
  };
}

String _yearsAgo(String day, String lang) {
  final n = japanNow().year - int.parse(day.substring(0, 4));
  return switch (lang) {
    'ko' => '$n년 전 오늘',
    'en' => n == 1 ? 'A year ago today' : '$n years ago today',
    _ => '$n年前の今日',
  };
}

/// 旅のアルバム: a picture postcard from every station the user got off at,
/// month by month, newest first. "On this day" brings back a postcard from
/// the same day in an earlier year.
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, required this.city});
  final CityData city;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final _book = PostcardBook.instance;

  @override
  void initState() {
    super.initState();
    if (!_book.loaded) _book.load(Services.my);
  }

  void _open(Postcard c) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: const Color(0xCC1B1F2A),
      barrierDismissible: true,
      pageBuilder: (_, a, _) => FadeTransition(
        opacity: a,
        child: PostcardDetail(city: widget.city, cardId: c.id),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    return Scaffold(
      backgroundColor: PixelColors.background,
      appBar: AppBar(
        backgroundColor: PixelColors.background,
        surfaceTintColor: Colors.transparent,
        title: PixelText(albumTitle.of(lang), size: 22),
      ),
      body: ListenableBuilder(
        listenable: _book,
        builder: (context, _) {
          final cards = _book.cards;
          if (!_book.loaded) return const SizedBox.shrink();
          if (cards.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              children: [
                Icon(Icons.local_post_office_rounded, size: 56, color: PixelColors.muted.withValues(alpha: 0.5)),
                const SizedBox(height: 14),
                PixelText(_empty.of(lang), size: 14, color: PixelColors.muted, align: TextAlign.center),
                if (kDebugMode) _DebugAdd(city: widget.city),
              ],
            );
          }
          final ago = _book.onThisDay(japanNow());
          // Month sections.
          final months = <String, List<Postcard>>{};
          for (final c in cards) {
            months.putIfAbsent(c.day.substring(0, 7), () => []).add(c);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              PixelText(_count(cards.length, lang), size: 14, color: PixelColors.muted),
              if (ago.isNotEmpty) ...[
                const SizedBox(height: 12),
                _OnThisDay(city: widget.city, card: ago.first, onTap: () => _open(ago.first)),
              ],
              for (final e in months.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 18, 0, 8),
                  child: PixelText(_month(e.value.first.day, lang), size: 16),
                ),
                _Grid(city: widget.city, cards: e.value, onTap: _open),
              ],
              if (kDebugMode) _DebugAdd(city: widget.city),
            ],
          );
        },
      ),
    );
  }
}

/// Two postcards a row, each tilted a little like they were laid on a table.
class _Grid extends StatelessWidget {
  const _Grid({required this.city, required this.cards, required this.onTap});
  final CityData city;
  final List<Postcard> cards;
  final void Function(Postcard) onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              for (var j = i; j < i + 2; j++) ...[
                if (j > i) const SizedBox(width: 12),
                Expanded(
                  child: j < cards.length
                      ? GestureDetector(
                          onTap: () => onTap(cards[j]),
                          child: Transform.rotate(
                            angle: (math.Random(cards[j].id).nextDouble() - 0.5) * 0.05,
                            child: PostcardFront(city: city, card: cards[j], my: Services.my, small: true),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _OnThisDay extends StatelessWidget {
  const _OnThisDay({required this.city, required this.card, required this.onTap});
  final CityData city;
  final Postcard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEBD49A)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: PostcardFront(city: city, card: card, my: Services.my, small: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelText(_yearAgo.of(lang), size: 11, color: const Color(0xFFB08A2A)),
                  const SizedBox(height: 2),
                  PixelText(_yearsAgo(card.day, lang), size: 16),
                  const SizedBox(height: 4),
                  PixelText(city.stations[card.station]?.name.of(lang) ?? '', size: 13, color: PixelColors.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One postcard, big: tap (or the button) to turn it over, write a line on
/// the back, or share the side shown.
class PostcardDetail extends StatefulWidget {
  const PostcardDetail({super.key, required this.city, required this.cardId});
  final CityData city;
  final int cardId;

  @override
  State<PostcardDetail> createState() => _PostcardDetailState();
}

class _PostcardDetailState extends State<PostcardDetail> with SingleTickerProviderStateMixin {
  late final _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  final _shot = GlobalKey();
  bool _back = false;

  Postcard? get _card => PostcardBook.instance.cards.where((c) => c.id == widget.cardId).firstOrNull;

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  void _flipIt() {
    _back = !_back;
    _back ? _turn.forward() : _turn.reverse();
  }

  Future<void> _writeMemo(Postcard c) async {
    final lang = langOf(context);
    final ctl = TextEditingController(text: c.memo);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PixelColors.card,
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLength: PostcardBook.memoMax,
          maxLines: 2,
          decoration: InputDecoration(hintText: _memoHint.of(lang)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_cancel.of(lang))),
          TextButton(onPressed: () => Navigator.pop(context, ctl.text), child: Text(_save.of(lang))),
        ],
      ),
    );
    ctl.dispose();
    if (text == null) return;
    await PostcardBook.instance.setMemo(c.id, text);
    if (!_back) _flipIt();
  }

  Future<void> _shareIt() async {
    final box = _shot.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (box == null) return;
    final image = await box.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;
    await shareFile(bytes.buffer.asUint8List(), name: 'postcard.png', mime: 'image/png', text: '#つぎはメトロ');
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    return ListenableBuilder(
      listenable: PostcardBook.instance,
      builder: (context, _) {
        final c = _card;
        if (c == null) return const SizedBox.shrink();
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                // Tap outside the card to close.
                Positioned.fill(child: GestureDetector(onTap: () => Navigator.pop(context))),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _flipIt,
                          child: RepaintBoundary(
                            key: _shot,
                            child: AnimatedBuilder(
                              animation: _turn,
                              builder: (context, _) {
                                final v = Curves.easeInOutCubic.transform(_turn.value);
                                final showBack = v > 0.5;
                                final angle = v * math.pi;
                                return Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.0012)
                                    ..rotateY(angle),
                                  child: showBack
                                      ? Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.identity()..rotateY(math.pi),
                                          child: PostcardBack(city: widget.city, card: c),
                                        )
                                      : PostcardFront(city: widget.city, card: c, my: Services.my),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Btn(icon: Icons.flip_rounded, label: _flip.of(lang), onTap: _flipIt),
                            const SizedBox(width: 10),
                            _Btn(icon: Icons.edit_rounded, label: _memo.of(lang), onTap: () => _writeMemo(c)),
                            const SizedBox(width: 10),
                            _Btn(icon: Icons.ios_share_rounded, label: _share.of(lang), onTap: _shareIt),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: PixelColors.ink),
            const SizedBox(width: 6),
            PixelText(label, size: 13),
          ],
        ),
      ),
    ),
  );
}

/// Debug builds: add sample postcards to look at the album.
class _DebugAdd extends StatelessWidget {
  const _DebugAdd({required this.city});
  final CityData city;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () async {
      final ids = city.stations.keys.toList()..shuffle();
      final r = math.Random();
      for (var i = 0; i < 4; i++) {
        final when = japanNow().subtract(Duration(days: r.nextInt(400), hours: r.nextInt(14)));
        await PostcardBook.instance.add(
          my: Services.my,
          station: ids[i],
          from: ids[i + 4],
          weather: WeatherKind.values[r.nextInt(4)],
          gold: r.nextInt(4) == 0,
          now: when,
        );
      }
    },
    child: const Text('テストはがき +4'),
  );
}
