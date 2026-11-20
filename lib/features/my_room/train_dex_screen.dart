import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/localized_text.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../data/models/rail_line.dart';
import '../../data/my_store.dart';
import '../../data/train_dex.dart';

const trainDexTitle = LocalizedText({'ja': '車両図鑑', 'ko': '차량 도감', 'en': 'Train Dex'});
const _hint = LocalizedText({
  'ja': '乗った線の車両が図鑑にのるよ。ぜんぶ集めよう！',
  'ko': '탄 노선의 차량이 도감에 실려요. 모두 모아 봐요!',
  'en': 'Ride a line and its train joins the dex. Collect them all!',
});
const _count = LocalizedText({'ja': 'あつめた車両', 'ko': '모은 차량', 'en': 'Collected'});
const _unknown = LocalizedText({'ja': '？？？', 'ko': '？？？', 'en': '???'});
const _runsOn = LocalizedText({'ja': 'はしる路線', 'ko': '달리는 노선', 'en': 'Runs on'});
const _findOn = LocalizedText({'ja': 'この線に乗るとみつかる', 'ko': '이 노선을 타면 발견해요', 'en': 'Ride one of these lines to find it'});
const _firstRide = LocalizedText({'ja': 'はじめて乗った日', 'ko': '처음 탄 날', 'en': 'First ridden'});
const _spotted = LocalizedText({'ja': 'のりばで見つけた！', 'ko': '승강장에서 발견했어요!', 'en': 'Spotted at the platform!'});
const _spotHint = LocalizedText({
  'ja': 'のりばで、めったに来ない黄色い電車に会えたら…',
  'ko': '승강장에서 좀처럼 오지 않는 노란 전철을 만나면…',
  'en': 'Meet the rarely seen yellow train at the platform…',
});
const _more = LocalizedText({'ja': 'ほか', 'ko': '외', 'en': 'more'});
const _rarityName = {
  DexRarity.common: LocalizedText({'ja': 'ふつう', 'ko': '보통', 'en': 'Common'}),
  DexRarity.rare: LocalizedText({'ja': 'レア', 'ko': '레어', 'en': 'Rare'}),
  DexRarity.legendary: LocalizedText({'ja': 'でんせつ', 'ko': '전설', 'en': 'Legendary'}),
};

const _gold = Color(0xFFE2A61E);
const _goldLight = Color(0xFFFFF1C7);
const _silver = Color(0xFFA9B1BE);
const _silverLight = Color(0xFFF0F2F6);
const _shadow = Color(0xFF3B4150);

Color _frame(DexRarity r) => switch (r) {
  DexRarity.legendary => _gold,
  DexRarity.rare => _silver,
  DexRarity.common => PixelColors.line,
};

Color _fill(DexRarity r) => switch (r) {
  DexRarity.legendary => _goldLight,
  DexRarity.rare => _silverLight,
  DexRarity.common => PixelColors.card,
};

String _no(TrainType t) => 'No.${(trainTypes.indexOf(t) + 1).toString().padLeft(2, '0')}';

/// 車両図鑑: a card for every kind of train; the kinds not ridden yet are
/// shown as silhouettes.
class TrainDexScreen extends StatelessWidget {
  const TrainDexScreen({super.key, required this.city, this.store, this.yellow});
  final CityData city;

  /// For tests and previews; the app uses [Services.my] and the real sighting.
  final MyStore? store;
  final bool? yellow;

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    final my = store ?? Services.my;
    return Scaffold(
      backgroundColor: PixelColors.background,
      appBar: AppBar(
        backgroundColor: PixelColors.background,
        surfaceTintColor: Colors.transparent,
        title: PixelText(trainDexTitle.of(lang), size: 22),
      ),
      body: ListenableBuilder(
        listenable: my,
        builder: (context, _) {
          final got = collected(my, city, yellow: yellow);
          final lines = linesByType(city);
          final ridden = {for (final t in my.trips) ...t.lines};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _Header(done: got.length, total: trainTypes.length, lang: lang),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.08,
                children: [
                  for (final t in trainTypes)
                    _DexCard(
                      type: t,
                      got: got.containsKey(t.id),
                      lang: lang,
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          child: TrainDexDetail(
                            type: t,
                            lines: lines[t.id]!,
                            ridden: ridden,
                            firstDay: got[t.id],
                            lang: lang,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.done, required this.total, required this.lang});
  final int done;
  final int total;
  final String lang;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: PixelColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: PixelColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Icon(Icons.train_rounded, size: 22, color: PixelColors.title),
            const SizedBox(width: 6),
            Expanded(child: PixelText(_count.of(lang), size: 16)),
            PixelText('$done', size: 26, bold: true, color: PixelColors.title),
            PixelText(' / $total', size: 16, color: PixelColors.muted),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 8,
            color: PixelColors.title,
            backgroundColor: PixelColors.soft,
          ),
        ),
        const SizedBox(height: 8),
        PixelText(_hint.of(lang), size: 12, color: PixelColors.muted),
      ],
    ),
  );
}

/// Rarity as stars: ★ common, ★★ rare, ★★★ legendary.
class _Stars extends StatelessWidget {
  const _Stars(this.rarity, {this.size = 13, this.dim = false});
  final DexRarity rarity;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i <= rarity.index; i++)
        Icon(
          Icons.star_rounded,
          size: size,
          color: dim
              ? PixelColors.muted
              : rarity == DexRarity.legendary
              ? _gold
              : rarity == DexRarity.rare
              ? const Color(0xFF7D8696)
              : const Color(0xFFB9BDC4),
        ),
    ],
  );
}

/// The picture on a little sky-and-rail panel tinted with the train's colour;
/// a dark silhouette when not collected yet.
class TrainDexArt extends StatelessWidget {
  const TrainDexArt({super.key, required this.type, required this.got, this.radius = 10});
  final TrainType type;
  final bool got;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final top = got ? Color.lerp(type.color, Colors.white, 0.86)! : const Color(0xFFE4E6EA);
    final bottom = got ? Color.lerp(type.color, Colors.white, 0.62)! : const Color(0xFFCFD2D8);
    Widget art = Image.asset(type.art, filterQuality: FilterQuality.none, fit: BoxFit.contain);
    if (!got) {
      art = ColorFiltered(colorFilter: const ColorFilter.mode(_shadow, BlendMode.srcIn), child: art);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Rails under the train.
            Align(
              alignment: const Alignment(0, 0.78),
              child: Container(height: 3, color: got ? const Color(0x667A6F64) : const Color(0x33000000)),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 12), child: art),
          ],
        ),
      ),
    );
  }
}

class _DexCard extends StatelessWidget {
  const _DexCard({required this.type, required this.got, required this.lang, required this.onTap});
  final TrainType type;
  final bool got;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = type.rarity;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
        decoration: BoxDecoration(
          color: got ? _fill(r) : PixelColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: got ? _frame(r) : PixelColors.line, width: r == DexRarity.common ? 1 : 2.5),
          boxShadow: got && r == DexRarity.legendary
              ? const [BoxShadow(color: Color(0x55E2A61E), blurRadius: 8)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _no(type),
                    style: TextStyle(
                      fontFamily: 'DotGothic16',
                      fontFamilyFallback: const ['Galmuri11'],
                      fontSize: 11,
                      color: got ? PixelColors.ink : PixelColors.muted,
                    ),
                  ),
                ),
                _Stars(r, size: 12, dim: !got),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TrainDexArt(type: type, got: got),
            ),
            const SizedBox(height: 6),
            Text(
              got ? type.name.of(lang) : _unknown.of(lang),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DotGothic16',
                fontFamilyFallback: const ['Galmuri11'],
                fontSize: 13,
                color: got ? PixelColors.ink : PixelColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The big card shown when a kind is tapped.
class TrainDexDetail extends StatelessWidget {
  const TrainDexDetail({
    super.key,
    required this.type,
    required this.lines,
    required this.ridden,
    required this.firstDay,
    required this.lang,
  });
  final TrainType type;
  final List<RailLine> lines;

  /// Line ids the user has ridden (shown filled).
  final Set<String> ridden;

  /// Day first ridden (yyyy-mm-dd), '' when spotted, null when not collected.
  final String? firstDay;
  final String lang;

  static const _maxLines = 12;

  @override
  Widget build(BuildContext context) {
    final got = firstDay != null;
    final r = type.rarity;
    final shown = [...lines.where((l) => ridden.contains(l.id)), ...lines.where((l) => !ridden.contains(l.id))];
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: got ? _fill(r) : PixelColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: got ? _frame(r) : PixelColors.line, width: r == DexRarity.common ? 1.5 : 4),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PixelText(_no(type), size: 16, color: PixelColors.muted),
                const Spacer(),
                _Stars(r, size: 16, dim: !got),
                const SizedBox(width: 4),
                Text(
                  _rarityName[r]!.of(lang),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: !got
                        ? PixelColors.muted
                        : r == DexRarity.legendary
                        ? const Color(0xFFB07C0C)
                        : PixelColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 2.2,
              child: TrainDexArt(type: type, got: got, radius: 14),
            ),
            const SizedBox(height: 12),
            PixelText(got ? type.name.of(lang) : _unknown.of(lang), size: 22, align: TextAlign.center),
            if (got) ...[
              const SizedBox(height: 8),
              Text(type.flavor.of(lang), style: const TextStyle(fontSize: 13, height: 1.5, color: PixelColors.ink)),
            ],
            const SizedBox(height: 14),
            if (type.bySighting)
              _InfoRow(
                icon: got ? Icons.auto_awesome_rounded : Icons.help_outline_rounded,
                text: got ? _spotted.of(lang) : _spotHint.of(lang),
                gold: got,
              )
            else ...[
              if (got) ...[
                _InfoRow(icon: Icons.event_rounded, text: '${_firstRide.of(lang)}  ${firstDay!.replaceAll('-', '/')}'),
                const SizedBox(height: 12),
              ],
              Text(
                got ? _runsOn.of(lang) : _findOn.of(lang),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PixelColors.muted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final l in shown.take(_maxLines)) _LineChip(line: l, ridden: ridden.contains(l.id), lang: lang),
                  if (shown.length > _maxLines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(
                        '${_more.of(lang)} ${shown.length - _maxLines}',
                        style: const TextStyle(fontSize: 12, color: PixelColors.muted),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.gold = false});
  final IconData icon;
  final String text;
  final bool gold;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: gold ? const Color(0xFFFFF4D6) : PixelColors.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: gold ? _gold : PixelColors.line),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: gold ? _gold : PixelColors.title),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: PixelColors.ink)),
        ),
      ],
    ),
  );
}

class _LineChip extends StatelessWidget {
  const _LineChip({required this.line, required this.ridden, required this.lang});
  final RailLine line;
  final bool ridden;
  final String lang;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: ridden ? Color.lerp(line.color, Colors.white, 0.82) : PixelColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ridden ? line.color : PixelColors.line, width: ridden ? 1.5 : 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: line.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          line.name.of(lang),
          style: TextStyle(
            fontSize: 12,
            color: ridden ? PixelColors.ink : PixelColors.muted,
            fontWeight: ridden ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}
