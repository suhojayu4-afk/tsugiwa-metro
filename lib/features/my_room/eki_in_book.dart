import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/localized_text.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../data/models/city.dart';
import '../../data/models/rail_line.dart';
import '../../data/models/station.dart';

// 駅印帳 (eki-in-chō): a station seal book in the manner of a 御朱印帳.
// PROTOTYPE - not wired into the app yet.
//
// Every stamped station gets one page of an accordion (蛇腹) book on washi:
// the station name in brush ink, a vermilion seal with an original emblem,
// the date in 和暦, the line and its colour. Finishing a whole line adds a
// gold-leaf (金箔) page. Pages run right to left like a Japanese book.
//
// Brush lettering for 2,000+ stations: one OFL brush font (Yuji Boku),
// subset to every character used in the city data plus all kana
// (assets/art/eki_in/yuji_boku_eki.ttf, tools/gen_eki_in_gpt.py font),
// set vertically by hand (ー and brackets turned, small kana nudged), with a
// little per-glyph jitter, ink bleed and dry-brush (かすれ) streaks seeded by
// the station id - so the same station always looks the same, any new
// station works, and nothing is drawn per station.

// ---------------------------------------------------------------- strings

const ekiInTitle = LocalizedText({'ja': '駅印帳', 'ko': '역인첩', 'en': 'Station Seal Book'});
const ekiInEmpty = LocalizedText({
  'ja': 'まだ駅印がありません。\n駅に着くと、ここに一枚ずつ増えていきます。',
  'ko': '아직 역인이 없어요.\n역에 도착하면 여기에 한 장씩 늘어나요.',
  'en': 'No seals yet.\nEach station you reach adds a page here.',
});
const ekiInSwipeHint = LocalizedText({
  'ja': '右へめくると次の頁',
  'ko': '오른쪽으로 넘기면 다음 장',
  'en': 'Swipe right for the next page',
});

// ---------------------------------------------------------------- logic

/// The small red label at the top right (where a 御朱印 says 奉拝).
enum EkiInMark {
  ride('乗車記念'),
  alight('下車印'),
  complete('完乗記念');

  const EkiInMark(this.label);
  final String label;
}

/// One page of the book: a station seal, or (station == null) the gold page
/// for finishing [line].
class EkiInEntry {
  const EkiInEntry({required this.line, required this.day, this.station, this.number = 0, this.mark = EkiInMark.ride});

  final Station? station;
  final RailLine line;
  final DateTime day;

  /// 1-based order of the station pages (0 for gold pages).
  final int number;
  final EkiInMark mark;

  bool get isLineComplete => station == null;
}

/// The book's pages from [stamps] (station id -> first visit 'yyyy-mm-dd'):
/// in visit order, each station once (under its first line in city order), and
/// a gold page right after the stamp that finished a line.
List<EkiInEntry> ekiInEntries(CityData city, Map<String, String> stamps) {
  final lineIndex = {for (var i = 0; i < city.lines.length; i++) city.lines[i].id: i};
  final days = <String, DateTime>{};
  for (final e in stamps.entries) {
    final d = DateTime.tryParse(e.value);
    if (d != null && city.stations.containsKey(e.key)) days[e.key] = d;
  }
  RailLine lineOf(Station s) {
    final ids = s.lines.where(lineIndex.containsKey).toList()..sort((a, b) => lineIndex[a]!.compareTo(lineIndex[b]!));
    return city.line(ids.isEmpty ? s.lines.first : ids.first);
  }

  final ids = days.keys.toList();
  int key(String id) {
    final line = lineOf(city.station(id));
    return lineIndex[line.id]! * 1000 + line.stations.indexOf(id);
  }

  ids.sort((a, b) {
    final c = days[a]!.compareTo(days[b]!);
    return c != 0 ? c : key(a).compareTo(key(b));
  });
  final pos = {for (var i = 0; i < ids.length; i++) ids[i]: i};

  // Lines finished, keyed by the position of the stamp that finished them.
  final finished = <int, List<RailLine>>{};
  for (final line in city.lines) {
    if (line.stations.isEmpty || !line.stations.every(days.containsKey)) continue;
    final last = line.stations.map((s) => pos[s]!).reduce(math.max);
    finished.putIfAbsent(last, () => []).add(line);
  }

  final out = <EkiInEntry>[];
  for (var i = 0; i < ids.length; i++) {
    final s = city.station(ids[i]);
    out.add(EkiInEntry(station: s, line: lineOf(s), day: days[s.id]!, number: i + 1));
    for (final line in finished[i] ?? const <RailLine>[]) {
      out.add(EkiInEntry(line: line, day: days[s.id]!, mark: EkiInMark.complete));
    }
  }
  return out;
}

/// 0 -> 〇, 8 -> 八, 21 -> 二十一, 2026 -> 二千二十六.
String kanjiNumber(int n) {
  const digits = '〇一二三四五六七八九';
  if (n <= 0) return digits[0];
  final b = StringBuffer();
  for (final (unit, mark) in [(1000, '千'), (100, '百'), (10, '十')]) {
    final q = (n ~/ unit) % 10;
    if (q > 0) b.write('${q == 1 ? '' : digits[q]}$mark');
  }
  if (n >= 10000) return '${kanjiNumber(n ~/ 10000)}万${n % 10000 == 0 ? '' : kanjiNumber(n % 10000)}';
  if (n % 10 > 0) b.write(digits[n % 10]);
  return b.toString();
}

/// 2026-11-21 -> 令和八年十一月二十一日 (the first year of an era is 元年).
String ekiInWareki(DateTime d) {
  final (era, start) = d.isBefore(DateTime(2019, 5)) ? ('平成', 1989) : ('令和', 2019);
  final y = d.year - start + 1;
  return '$era${y == 1 ? '元' : kanjiNumber(y)}年${kanjiNumber(d.month)}月${kanjiNumber(d.day)}日';
}

/// A station name as vertical columns (right to left) plus a smaller note
/// from brackets: '小川町（千代田区）' -> (['小川町'], '千代田区').
({List<String> columns, String? note}) ekiInColumns(String name, {int maxPerColumn = 8}) {
  String? note;
  final open = name.indexOf(RegExp('[（(]'));
  if (open > 0) {
    note = name.substring(open + 1).replaceAll(RegExp('[）)]'), '');
    name = name.substring(0, open);
  }
  final chars = name.runes.map(String.fromCharCode).toList();
  if (chars.length <= maxPerColumn) return (columns: [name], note: note);
  // Prefer a natural break: after ・, or before a long katakana word.
  final dot = chars.indexOf('・');
  if (dot > 0 && dot < chars.length - 1) {
    return (columns: [chars.take(dot + 1).join(), chars.skip(dot + 1).join()], note: note);
  }
  final n = (chars.length / maxPerColumn).ceil();
  final per = (chars.length / n).ceil();
  return (
    columns: [for (var i = 0; i < chars.length; i += per) chars.sublist(i, math.min(i + per, chars.length)).join()],
    note: note,
  );
}

/// The emblem carved in a station's seal.
enum EkiInMotif {
  sakura,
  plum,
  wave,
  mountain,
  bridge,
  pine,
  ginkgo,
  river,
  pagoda,
  tower,
  train,
  lantern,
  crane,
  maple,
  rice,
  hill,
}

/// Picks an emblem from the station's name (桜 -> sakura, 橋 -> bridge, 谷 -> hill ...),
/// or a steady pick from a calm set when nothing matches.
EkiInMotif ekiInMotif(String name, String id) {
  const words = <String, EkiInMotif>{
    'スカイツリー': EkiInMotif.tower,
    'タワー': EkiInMotif.tower,
    'テレポート': EkiInMotif.tower,
    '公園': EkiInMotif.ginkgo,
    'パーク': EkiInMotif.ginkgo,
    '空港': EkiInMotif.crane,
    'ターミナル': EkiInMotif.crane,
    '紅葉': EkiInMotif.maple,
    'シーサイド': EkiInMotif.wave,
  };
  for (final w in words.entries) {
    if (name.contains(w.key)) return w.value;
  }
  const kanji = <EkiInMotif, String>{
    EkiInMotif.sakura: '桜櫻',
    EkiInMotif.plum: '梅',
    EkiInMotif.maple: '楓',
    EkiInMotif.crane: '鶴鷹鳥鴨鷺鳩',
    EkiInMotif.pine: '松',
    EkiInMotif.bridge: '橋',
    EkiInMotif.pagoda: '寺院宮神社蔵',
    EkiInMotif.tower: '塔',
    EkiInMotif.mountain: '山岳峰富',
    EkiInMotif.wave: '海浜濱港湾洲島汐潮浦岬',
    EkiInMotif.river: '川河沢池泉水江渡瀬淵堀',
    EkiInMotif.hill: '坂台丘岡谷',
    EkiInMotif.rice: '田稲畑',
    EkiInMotif.lantern: '宿町通門',
    EkiInMotif.ginkgo: '杏森林苑',
  };
  for (final k in kanji.entries) {
    if (name.runes.any((r) => k.value.contains(String.fromCharCode(r)))) return k.key;
  }
  const calm = [
    EkiInMotif.train,
    EkiInMotif.lantern,
    EkiInMotif.sakura,
    EkiInMotif.pine,
    EkiInMotif.plum,
    EkiInMotif.crane,
    EkiInMotif.ginkgo,
    EkiInMotif.maple,
  ];
  return calm[_seed(id) % calm.length];
}

/// A steady 31-bit hash (String.hashCode may change between runs).
int _seed(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

// ---------------------------------------------------------------- art

/// Brush font, washi, gold leaf and the 16 emblems. Load once before showing
/// pages; pages paint plain colours until it is done.
class EkiInArt {
  static const brush = 'EkiInBrush';
  static const _dir = 'assets/art/eki_in';
  static ui.Image? washi;
  static ui.Image? gold;
  static final motifs = <EkiInMotif, ui.Image>{};
  static Future<void>? _loading;
  static final loaded = ValueNotifier(false);

  static Future<void> load() => _loading ??= _load();

  static Future<void> _load() async {
    final font = FontLoader(brush)..addFont(rootBundle.load('$_dir/yuji_boku_eki.ttf'));
    await font.load();
    Future<ui.Image> image(String name) async {
      final data = await rootBundle.load('$_dir/$name.webp');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    }

    washi = await image('washi');
    gold = await image('gold_leaf');
    for (final m in EkiInMotif.values) {
      motifs[m] = await image('motif_${m.name}');
    }
    loaded.value = true;
  }
}

// ---------------------------------------------------------------- widgets

/// One page, 300 x 440 design units (a 御朱印帳 page is about 11 x 16 cm),
/// scaled to the width it gets.
class EkiInPage extends StatefulWidget {
  const EkiInPage({super.key, required this.entry, required this.city});
  final EkiInEntry entry;
  final CityData city;

  static const size = Size(300, 440);

  @override
  State<EkiInPage> createState() => _EkiInPageState();
}

class _EkiInPageState extends State<EkiInPage> {
  @override
  void initState() {
    super.initState();
    EkiInArt.load();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: EkiInPage.size.width / EkiInPage.size.height,
    child: ValueListenableBuilder<bool>(
      valueListenable: EkiInArt.loaded,
      builder: (context, ready, _) =>
          CustomPaint(painter: _EkiInPainter(widget.entry, widget.city.name.ja, ready), child: const SizedBox.expand()),
    ),
  );
}

/// The book: one page at a time, swiped like a Japanese book (the next page
/// lies to the left), with the accordion folds leaning in.
class EkiInBookScreen extends StatefulWidget {
  const EkiInBookScreen({super.key, required this.city, required this.stamps});
  final CityData city;

  /// MyStore.stamps (station id -> first visit day).
  final Map<String, String> stamps;

  @override
  State<EkiInBookScreen> createState() => _EkiInBookScreenState();
}

class _EkiInBookScreenState extends State<EkiInBookScreen> {
  final _pages = PageController(viewportFraction: 0.8);
  late final List<EkiInEntry> _entries = ekiInEntries(widget.city, widget.stamps);
  int _index = 0;

  static const _cloth = Color(0xFF232A43); // 紺 book cover cloth
  static const _goldInk = Color(0xFFE2C27A);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    return Scaffold(
      backgroundColor: _cloth,
      appBar: AppBar(
        backgroundColor: _cloth,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _goldInk,
        title: Text(
          ekiInTitle.of(lang),
          style: const TextStyle(fontFamily: EkiInArt.brush, fontSize: 26, color: _goldInk),
        ),
      ),
      body: _entries.isEmpty
          ? Center(
              child: PixelText(ekiInEmpty.of(lang), size: 14, color: _goldInk, align: TextAlign.center),
            )
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    reverse: true, // right to left, like a Japanese book
                    itemCount: _entries.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => AnimatedBuilder(
                      animation: _pages,
                      builder: (context, child) {
                        final page = _pages.hasClients && _pages.position.haveDimensions
                            ? _pages.page ?? _index.toDouble()
                            : _index.toDouble();
                        final d = (i - page).clamp(-1.0, 1.0);
                        // Accordion: neighbours fold away at their shared edge.
                        return Transform(
                          alignment: d > 0 ? Alignment.centerRight : Alignment.centerLeft,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0011)
                            ..rotateY(-d * 0.55),
                          child: Opacity(opacity: 1 - d.abs() * 0.25, child: child),
                        );
                      },
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 6))],
                            ),
                            child: EkiInPage(entry: _entries[i], city: widget.city),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(
                    children: [
                      PixelText('${_index + 1} / ${_entries.length}', size: 16, color: _goldInk),
                      const SizedBox(height: 2),
                      PixelText(ekiInSwipeHint.of(lang), size: 11, color: _goldInk.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------- painting

const _sumi = Color(0xFF1B1613); // ink
const _shu = Color(0xFFC63A2B); // vermilion seal paste
const _paperFlat = Color(0xFFF2EADA);
const _goldFlat = Color(0xFFD9B456);

const _turned = 'ー－-–〜~（）()「」『』…‥=＝';
const _smallKana = 'ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ';

class _EkiInPainter extends CustomPainter {
  _EkiInPainter(this.entry, this.cityName, this.ready);
  final EkiInEntry entry;
  final String cityName;
  final bool ready;

  static const w = 300.0;
  static const h = 440.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / w, size.height / h);
    final seed = _seed(entry.station?.id ?? 'line:${entry.line.id}');
    if (entry.isLineComplete) {
      _goldPaper(canvas, math.Random(seed));
      _goldPage(canvas, math.Random(seed + 1));
    } else {
      _washi(canvas);
      _stationPage(canvas, math.Random(seed + 1));
    }
    _folds(canvas);
    canvas.restore();
  }

  // ---- paper

  void _washi(Canvas canvas) {
    final paint = Paint()..color = _paperFlat;
    final img = EkiInArt.washi;
    if (img != null) {
      paint.shader = ImageShader(
        img,
        TileMode.repeated,
        TileMode.repeated,
        (Matrix4.identity()..scaleByDouble(0.55, 0.55, 1, 1)).storage,
      );
    }
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), paint);
    // A faint warm vignette, like paper that has been handled.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const RadialGradient(
          radius: 0.95,
          colors: [Color(0x00000000), Color(0x149A7B4F)],
        ).createShader(const Rect.fromLTWH(0, 0, w, h)),
    );
  }

  void _goldPaper(Canvas canvas, math.Random r) {
    const rect = Rect.fromLTWH(0, 0, w, h);
    final paint = Paint()..color = _goldFlat;
    final img = EkiInArt.gold;
    if (img != null) {
      paint.shader = ImageShader(
        img,
        TileMode.repeated,
        TileMode.repeated,
        (Matrix4.identity()..scaleByDouble(0.42, 0.42, 1, 1)).storage,
      );
    }
    canvas.drawRect(rect, paint);
    // Metallic sheen: a soft light band across the leaf.
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.softLight
        ..shader = const LinearGradient(
          begin: Alignment(-1, -1),
          end: Alignment(1, 1),
          colors: [Color(0x00FFFFFF), Color(0xAAFFF4D0), Color(0x00FFFFFF), Color(0x66FFF0C0), Color(0x00FFFFFF)],
          stops: [0.1, 0.32, 0.55, 0.75, 0.95],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(radius: 0.9, colors: [Color(0x00000000), Color(0x30603A00)]).createShader(rect),
    );
    // 砂子: flecks of brighter and darker leaf.
    for (var i = 0; i < 140; i++) {
      final p = Offset(r.nextDouble() * w, r.nextDouble() * h);
      final s = 0.6 + r.nextDouble() * 2.2;
      final bright = r.nextBool();
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(r.nextDouble());
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: s, height: s * (0.6 + r.nextDouble())),
        Paint()..color = bright ? const Color(0x88FFF6D8) : const Color(0x557A5410),
      );
      canvas.restore();
    }
  }

  /// The accordion folds: shade at the left crease, light at the right edge.
  void _folds(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 18, h),
      Paint()
        ..shader = const LinearGradient(colors: [Color(0x38000000), Color(0x00000000)])
            .createShader(const Rect.fromLTWH(0, 0, 18, h)),
    );
    canvas.drawRect(
      const Rect.fromLTWH(w - 10, 0, 10, h),
      Paint()
        ..shader = const LinearGradient(colors: [Color(0x00000000), Color(0x1F000000)])
            .createShader(const Rect.fromLTWH(w - 10, 0, 10, h)),
    );
    canvas.drawLine(const Offset(0.6, 0), const Offset(0.6, h), Paint()..color = const Color(0x40000000));
  }

  // ---- pages

  void _stationPage(Canvas canvas, math.Random r) {
    final s = entry.station!;
    final name = s.name.ja;
    final lineName = _plainLine(entry.line.name.ja);

    // 1. The vermilion seal (pressed first; the brush writes over it).
    final motif = ekiInMotif(name, s.id);
    final round = _seed(s.id) % 5 < 3;
    _seal(canvas, r, const Offset(w / 2, 226), (c) {
      if (round) {
        _roundSeal(c, 70, '$name駅・$lineName・$cityName・つぎはメトロ・', motif);
      } else {
        _squareSeal(c, 132, name, motif);
      }
    }, rotate: (r.nextDouble() - 0.5) * 0.22);

    // 2. The red label, top right, and the line under it.
    final labelBottom = _label(canvas, r, entry.mark.label, const Offset(262, 24));
    _lineTag(canvas, r, lineName, entry.line.color, Offset(262, labelBottom + 14));

    // 3. The station name in brush ink, down the middle.
    final cols = ekiInColumns(name);
    _brushName(canvas, r, cols.columns, cols.note, top: 44, bottom: 400, maxSize: 88);

    // 4. The date, bottom left.
    _brushColumn(canvas, r, ekiInWareki(entry.day), const Offset(36, 0), 15, bottomAt: 402, jitter: 0.6);

    // 5. The app's own little pixel seal and the page number.
    _seal(canvas, r, const Offset(262, 400), (c) => _pixelSeal(c, 26), rotate: (r.nextDouble() - 0.5) * 0.1);
    _pixel(canvas, 'No.${entry.number.toString().padLeft(3, '0')}', const Offset(w / 2, 418), 8, _sumi, 0.45);
  }

  void _goldPage(Canvas canvas, math.Random r) {
    final line = entry.line;
    final lineName = _plainLine(line.name.ja);
    final note = line.name.ja.contains('（') ? ekiInColumns(line.name.ja).note : null;

    // A line-colour 帯 (ribbon) down the right side.
    final band = Paint()..color = line.color.withValues(alpha: 0.85);
    canvas.drawRect(const Rect.fromLTWH(w - 26, 0, 7, h), band);
    canvas.drawRect(const Rect.fromLTWH(w - 17, 0, 1.6, h), Paint()..color = line.color.withValues(alpha: 0.7));

    final labelBottom = _label(canvas, r, entry.mark.label, const Offset(250, 24));
    _brushColumn(canvas, r, '全${kanjiNumber(line.stations.length)}駅', Offset(250, labelBottom + 14), 17, jitter: 0.8);

    // The big seal: 全線完乗, carved white out of red, inside a line-colour ring.
    _seal(
      canvas,
      r,
      const Offset(w / 2, 300),
      (c) {
        c.drawCircle(
          Offset.zero,
          71,
          Paint()
            ..color = line.color.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7,
        );
        final sq = Rect.fromCenter(center: Offset.zero, width: 96, height: 96);
        c.drawCircle(
          Offset.zero,
          64,
          Paint()
            ..color = _shu
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
        c.drawRRect(RRect.fromRectAndRadius(sq, const Radius.circular(5)), Paint()..color = _shu);
        c.drawRRect(
          RRect.fromRectAndRadius(sq.deflate(5), const Radius.circular(3)),
          Paint()
            ..color = const Color(0xFFFFF7E8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        // Read right column first: 全線 | 完乗.
        for (final (i, ch) in ['全', '線', '完', '乗'].indexed) {
          final x = i < 2 ? 20.0 : -20.0;
          final y = (i % 2 == 0) ? -21.0 : 21.0;
          _glyph(c, ch, Offset(x, y), 38, const Color(0xFFFFF7E8));
        }
      },
      rotate: (r.nextDouble() - 0.5) * 0.12,
      multiply: false,
    );

    // The line name, large, in brush ink above the seal.
    _brushName(canvas, r, [lineName], note, top: 40, bottom: 236, maxSize: 74, suffix: '');

    _brushColumn(canvas, r, ekiInWareki(entry.day), const Offset(40, 0), 15, bottomAt: 402, jitter: 0.6);
    _pixel(canvas, '${line.name.of('en')} COMPLETE', const Offset(w / 2, 418), 8, const Color(0xFF5A3D08), 0.7);
  }

  static String _plainLine(String name) => name.split(RegExp('[（(]')).first;

  // ---- seals

  /// Paints [draw] around [center] in a layer, then wears it like a real
  /// pressing: uneven paste, specks where the paste missed, soft edges.
  void _seal(
    Canvas canvas,
    math.Random r,
    Offset center,
    void Function(Canvas c) draw, {
    double rotate = 0,
    bool multiply = true,
  }) {
    final bounds = Rect.fromCenter(center: center, width: 200, height: 200);
    canvas.saveLayer(
      bounds,
      Paint()
        ..color = const Color(0xE6000000)
        ..blendMode = multiply ? BlendMode.multiply : BlendMode.srcOver,
    );
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotate);
    draw(canvas);
    // Where the paste was thin: a soft pale blotch or two.
    for (var i = 0; i < 2; i++) {
      final p = Offset((r.nextDouble() - 0.5) * 90, (r.nextDouble() - 0.5) * 90);
      canvas.drawCircle(
        p,
        28 + r.nextDouble() * 30,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..shader = RadialGradient(colors: [const Color(0x52000000), const Color(0x00000000)])
              .createShader(Rect.fromCircle(center: p, radius: 58)),
      );
    }
    // Specks where the rubber did not touch.
    final speck = Paint()..blendMode = BlendMode.dstOut;
    for (var i = 0; i < 520; i++) {
      final a = r.nextDouble() * math.pi * 2;
      final d = math.sqrt(r.nextDouble()) * 82;
      speck.color = Color.fromRGBO(0, 0, 0, 0.25 + r.nextDouble() * 0.7);
      canvas.drawCircle(Offset(math.cos(a) * d, math.sin(a) * d), 0.25 + r.nextDouble() * r.nextDouble() * 1.6, speck);
    }
    canvas.restore();
  }

  void _roundSeal(Canvas c, double radius, String ring, EkiInMotif motif) {
    final line = Paint()
      ..color = _shu
      ..style = PaintingStyle.stroke;
    c.drawCircle(Offset.zero, radius, line..strokeWidth = 5);
    c.drawCircle(Offset.zero, radius - 19, line..strokeWidth = 1.6);
    // Ring text in the app's pixel font.
    var text = ring;
    while (text.runes.length < 30) {
      text += ring;
    }
    final chars = text.runes.map(String.fromCharCode).toList();
    final step = math.pi * 2 / chars.length;
    for (var i = 0; i < chars.length; i++) {
      final a = -math.pi / 2 + i * step;
      c.save();
      c.rotate(a + math.pi / 2);
      c.translate(0, -(radius - 10.5));
      final tp = _tp(chars[i], 'DotGothic16', 10, _shu);
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
    }
    _motif(c, motif, (radius - 23) * 1.5, _shu);
  }

  void _squareSeal(Canvas c, double side, String name, EkiInMotif motif) {
    final rect = Rect.fromCenter(center: Offset.zero, width: side, height: side);
    final line = Paint()
      ..color = _shu
      ..style = PaintingStyle.stroke;
    c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), line..strokeWidth = 5);
    c.drawRRect(RRect.fromRectAndRadius(rect.deflate(7), const Radius.circular(4)), line..strokeWidth = 1.4);
    // A carved band at the bottom: the name in white on red (陰刻).
    final band = Rect.fromLTRB(rect.left + 7, rect.bottom - 31, rect.right - 7, rect.bottom - 7);
    c.drawRect(band, Paint()..color = _shu);
    final label = '$name駅';
    final tp = _tp(label, 'DotGothic16', label.runes.length > 8 ? 9 : 13, const Color(0xFFFFF7EE));
    tp.paint(c, band.center - Offset(tp.width / 2, tp.height / 2));
    final top = _tp('つぎはメトロ', 'DotGothic16', 9, _shu);
    top.paint(c, Offset(-top.width / 2, rect.top + 10));
    c.save();
    c.translate(0, -6);
    _motif(c, motif, side * 0.52, _shu);
    c.restore();
  }

  /// The app's own small seal: a square with a pixel train, white on red.
  void _pixelSeal(Canvas c, double side) {
    final rect = Rect.fromCenter(center: Offset.zero, width: side, height: side);
    c.drawRect(rect, Paint()..color = _shu);
    const art = [
      '.#######.',
      '#########',
      '#..#.#..#',
      '#..#.#..#',
      '#########',
      '#.#####.#',
      '#########',
      '.#.....#.',
      '#########',
    ];
    final px = (side - 8) / art.length;
    final white = Paint()..color = const Color(0xFFFFF7EE);
    for (var y = 0; y < art.length; y++) {
      for (var x = 0; x < art[y].length; x++) {
        if (art[y][x] == '#') {
          c.drawRect(Rect.fromLTWH(rect.left + 4 + x * px, rect.top + 4 + y * px, px + 0.05, px + 0.05), white);
        }
      }
    }
  }

  void _motif(Canvas c, EkiInMotif motif, double size, Color color) {
    final img = EkiInArt.motifs[motif];
    if (img == null) return;
    final dst = Rect.fromCenter(center: Offset.zero, width: size, height: size);
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  /// The red label (乗車記念 ...), white brush letters on vermilion. Returns its bottom.
  double _label(Canvas canvas, math.Random r, String text, Offset topCenter) {
    const size = 17.0;
    final n = text.runes.length;
    final height = n * size * 1.02 + 14;
    final rect = Rect.fromLTWH(-15, 0, 30, height);
    _seal(canvas, r, topCenter + Offset(0, height / 2), (c) {
      c.translate(0, -height / 2);
      c.drawRect(rect, Paint()..color = _shu);
      c.drawRect(
        rect.deflate(2.5),
        Paint()
          ..color = const Color(0xFFFFF7EE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
      var y = 7 + size / 2;
      for (final ch in text.runes.map(String.fromCharCode)) {
        _glyph(c, ch, Offset(0, y), size, const Color(0xFFFFF7EE));
        y += size * 1.02;
      }
    }, rotate: (r.nextDouble() - 0.5) * 0.05);
    return topCenter.dy + height;
  }

  /// A line-colour dot and stripe beside the line's name.
  void _lineTag(Canvas canvas, math.Random r, String name, Color color, Offset top) {
    const size = 15.0;
    canvas.drawCircle(top + const Offset(0, 6), 6.5, Paint()..color = color);
    canvas.drawCircle(top + const Offset(0, 6), 2.6, Paint()..color = const Color(0xFFFFFBF2));
    final end = _brushColumn(canvas, r, name, top + const Offset(0, 18), size, jitter: 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(top.dx + 11, top.dy + 18, top.dx + 14, end), const Radius.circular(1.5)),
      Paint()..color = color,
    );
  }

  // ---- brush lettering

  /// The big name: columns right to left, 駅 a little smaller at the end, an
  /// optional bracket note in a thin column to the left.
  void _brushName(
    Canvas canvas,
    math.Random r,
    List<String> columns,
    String? note, {
    required double top,
    required double bottom,
    required double maxSize,
    String suffix = '駅',
  }) {
    final lens = [for (final c in columns) c.runes.length];
    final longest = lens.reduce(math.max) + (suffix.isEmpty ? 0 : 0.8);
    final size = math.min(maxSize / (columns.length == 1 ? 1 : 1.15), (bottom - top) / (longest * 1.0));
    final gap = size * 1.02;
    final xs = [for (var i = 0; i < columns.length; i++) w / 2 + (columns.length - 1) * gap / 2 - i * gap];

    canvas.saveLayer(const Rect.fromLTWH(0, 0, w, h), Paint()..blendMode = BlendMode.multiply);
    var maxY = top;
    for (var i = 0; i < columns.length; i++) {
      final text = columns[i] + (i == columns.length - 1 ? suffix : '');
      // Centre short names a little lower, as a calligrapher would.
      final n = text.runes.length - (suffix.isNotEmpty && i == columns.length - 1 ? 0.2 : 0);
      final start = columns.length == 1 ? top + math.max(0, (bottom - top - n * size) * 0.35) : top;
      final end = _brushColumn(
        canvas,
        r,
        text,
        Offset(xs[i], start),
        size,
        jitter: 1,
        smallLast: suffix.isNotEmpty && i == columns.length - 1,
        layer: false,
      );
      maxY = math.max(maxY, end);
    }
    if (note != null) {
      final x = xs.last - size * 0.62 - 12;
      _brushColumn(canvas, r, '（$note）', Offset(x, top + size * 0.9), math.min(20, size * 0.32), layer: false);
    }
    _kasure(canvas, r, Rect.fromLTRB(xs.last - size * 0.6, top, xs.first + size * 0.6, maxY));
    canvas.restore();
  }

  /// One vertical column of brush text from [top] (or ending at [bottomAt]).
  /// Returns the bottom y.
  double _brushColumn(
    Canvas canvas,
    math.Random r,
    String text,
    Offset top,
    double size, {
    double jitter = 0.7,
    double? bottomAt,
    bool smallLast = false,
    bool layer = true,
  }) {
    final chars = text.runes.map(String.fromCharCode).toList();
    double adv(int i) =>
        (smallLast && i == chars.length - 1 ? 0.78 : 1.0) *
        size *
        (_turned.contains(chars[i])
            ? 0.9
            : _smallKana.contains(chars[i])
            ? 0.72
            : 0.98);
    final total = [for (var i = 0; i < chars.length; i++) adv(i)].fold(0.0, (a, b) => a + b);
    var y = bottomAt != null ? bottomAt - total : top.dy;
    if (layer) canvas.saveLayer(const Rect.fromLTWH(0, 0, w, h), Paint()..blendMode = BlendMode.multiply);
    final startY = y;
    for (var i = 0; i < chars.length; i++) {
      final ch = chars[i];
      final a = adv(i);
      final s = (smallLast && i == chars.length - 1 ? 0.78 : 1.0) * size * (1 + (r.nextDouble() - 0.5) * 0.06 * jitter);
      var c = Offset(top.dx + (r.nextDouble() - 0.5) * size * 0.05 * jitter, y + a / 2);
      if (_smallKana.contains(ch)) c += Offset(size * 0.14, -size * 0.08);
      final rot = (_turned.contains(ch) ? math.pi / 2 : 0) + (r.nextDouble() - 0.5) * 0.07 * jitter;
      _glyph(canvas, ch, c, s, _sumi, rotate: rot, bleed: size > 30);
      y += a;
    }
    if (layer) {
      _kasure(canvas, r, Rect.fromLTRB(top.dx - size * 0.6, startY, top.dx + size * 0.6, y), amount: 0.4);
      canvas.restore();
    }
    return y;
  }

  /// One glyph centred on [center].
  void _glyph(Canvas c, String ch, Offset center, double size, Color color, {double rotate = 0, bool bleed = false}) {
    c.save();
    c.translate(center.dx, center.dy);
    if (rotate != 0) c.rotate(rotate);
    if (bleed) {
      // Ink soaking into the paper around each stroke.
      final soft = _tp(
        ch,
        EkiInArt.brush,
        size,
        null,
        foreground: Paint()
          ..color = color.withValues(alpha: 0.38)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.018),
      );
      soft.paint(c, Offset(-soft.width / 2, -soft.height / 2));
    }
    final tp = _tp(ch, EkiInArt.brush, size, color);
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();
  }

  /// Dry-brush streaks: thin gaps running along the stroke direction.
  void _kasure(Canvas canvas, math.Random r, Rect area, {double amount = 1}) {
    final p = Paint()
      ..blendMode = BlendMode.dstOut
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final count = (area.width * area.height / 70 * amount).round().clamp(10, 900);
    for (var i = 0; i < count; i++) {
      final x = area.left + r.nextDouble() * area.width;
      final y = area.top + r.nextDouble() * area.height;
      final len = 3 + r.nextDouble() * 14;
      final slant = (r.nextDouble() - 0.5) * 0.5;
      p
        ..strokeWidth = 0.35 + r.nextDouble() * 1.0
        ..color = Color.fromRGBO(0, 0, 0, 0.12 + r.nextDouble() * 0.45);
      // Mostly vertical and horizontal streaks, the way a brush drags.
      final horiz = r.nextDouble() < 0.4;
      final d = horiz ? Offset(len, len * slant) : Offset(len * slant, len);
      canvas.drawLine(Offset(x, y), Offset(x, y) + d, p);
    }
  }

  void _pixel(Canvas canvas, String text, Offset center, double size, Color color, double alpha) {
    final tp = _tp(text, 'DotGothic16', size, color.withValues(alpha: alpha));
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  static TextPainter _tp(String text, String family, double size, Color? color, {Paint? foreground}) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: family,
        fontSize: size,
        height: 1.0,
        color: foreground == null ? color : null,
        foreground: foreground,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(_EkiInPainter old) => old.entry != entry || old.ready != ready || old.cityName != cityName;
}
