import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../core/localized_text.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import 'first_ride_data.dart';
import 'guide_card.dart';

LocalizedText _t(String ja, String ko, String en) => LocalizedText({'ja': ja, 'ko': ko, 'en': en});

final _read = _t('よんだ', '읽음', 'Read');
final _progress = _t('よんだ章', '읽은 장', 'Chapters read');
final _graduate = _t('はじめてガイド 卒業！', '첫걸음 가이드 졸업!', 'Guide complete!');
final _graduateBody = _t(
  'これで電車はばっちり。お祝いに コインをどうぞ。',
  '이제 전철은 문제없어요. 축하 코인을 드릴게요.',
  "You're ready to ride. Here are some coins to celebrate.",
);
final _sounds = _t('よみ', '읽는 법', 'Say');

/// Which chapters of 「日本の電車はじめて」 have been opened, and whether the
/// guide is finished (its coins are given once).
class FirstRideProgress {
  static const _readKey = 'guide.firstRide.read';
  static const _doneKey = 'guide.firstRide.done';

  /// Coins for reading every chapter.
  static const coins = 100;

  static final read = ValueNotifier<Set<String>>({});
  static final done = ValueNotifier<bool>(false);
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      read.value = {...?prefs.getStringList(_readKey)};
      done.value = prefs.getBool(_doneKey) ?? false;
    } catch (_) {
      // A nicety: start from nothing.
    }
  }

  /// Marks [id] read. Returns true when this finished the guide (coins given).
  static Future<bool> markRead(String id) async {
    if (read.value.contains(id)) return false;
    read.value = {...read.value, id};
    final finished = !done.value && firstRideChapters.every((c) => read.value.contains(c.id));
    if (finished) {
      done.value = true;
      if (Services.my.loaded) await Services.my.addCoins(coins);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_readKey, read.value.toList());
      await prefs.setBool(_doneKey, done.value);
    } catch (_) {
      // Kept until the app closes.
    }
    return finished;
  }
}

/// 「日本の電車はじめて」: how to ride, chapter by chapter, with つぎはさん.
/// Each chapter opens with a tap; reading them all gives [FirstRideProgress.coins].
class FirstRideGuideScreen extends StatefulWidget {
  const FirstRideGuideScreen({super.key, required this.cityId});
  final String cityId;

  @override
  State<FirstRideGuideScreen> createState() => _FirstRideGuideScreenState();
}

class _FirstRideGuideScreenState extends State<FirstRideGuideScreen> {
  String? _open;

  @override
  void initState() {
    super.initState();
    FirstRideProgress.load().then((_) => mounted ? setState(() {}) : null);
  }

  Future<void> _toggle(FirstRideChapter c) async {
    setState(() => _open = _open == c.id ? null : c.id);
    if (_open != c.id) return;
    final finished = await FirstRideProgress.markRead(c.id);
    if (!finished || !mounted) return;
    final lang = langOf(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PixelColors.card,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AttendantFigure(pointing: true, height: 90),
            const SizedBox(height: 10),
            PixelText(_graduate.of(lang), size: 22, align: TextAlign.center),
            const SizedBox(height: 6),
            PixelText(_graduateBody.of(lang), size: 14, align: TextAlign.center, color: PixelColors.muted),
            const SizedBox(height: 8),
            PixelText('+${FirstRideProgress.coins}', size: 26, bold: true, color: const Color(0xFFB7791F)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    final chapters = firstRideChaptersFor(widget.cityId);
    return Scaffold(
      backgroundColor: PixelColors.background,
      appBar: AppBar(
        backgroundColor: PixelColors.background,
        surfaceTintColor: Colors.transparent,
        title: PixelText(firstRideTitle.of(lang), size: 20),
      ),
      body: ValueListenableBuilder<Set<String>>(
        valueListenable: FirstRideProgress.read,
        builder: (context, read, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const AttendantFigure(height: 72),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: PixelColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PixelColors.line),
                    ),
                    child: PixelText(firstRideIntro.of(lang), size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                PixelText('${_progress.of(lang)}  ', size: 13, color: PixelColors.muted),
                for (final c in chapters)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      read.contains(c.id) ? Icons.circle : Icons.circle_outlined,
                      size: 10,
                      color: read.contains(c.id) ? c.color : PixelColors.muted,
                    ),
                  ),
                const Spacer(),
                PixelText('${read.length}/${chapters.length}', size: 13, color: PixelColors.muted),
              ],
            ),
            const SizedBox(height: 10),
            for (final (i, c) in chapters.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ChapterCard(
                  number: i + 1,
                  chapter: c,
                  open: _open == c.id,
                  read: read.contains(c.id),
                  lang: lang,
                  onTap: () => _toggle(c),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.number,
    required this.chapter,
    required this.open,
    required this.read,
    required this.lang,
    required this.onTap,
  });
  final int number;
  final FirstRideChapter chapter;
  final bool open;
  final bool read;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = chapter;
    return GestureDetector(
      key: ValueKey('firstRide.${c.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PixelColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: open ? c.color : PixelColors.line, width: open ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(12)),
                  child: Icon(c.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PixelText('$number. ${c.title.of(lang)}', size: 17),
                      const SizedBox(height: 2),
                      PixelText(c.lead.of(lang), size: 12, color: PixelColors.muted, maxLines: open ? 3 : 1),
                    ],
                  ),
                ),
                if (read && !open) ...[const SizedBox(width: 6), PixelText(_read.of(lang), size: 11, color: c.color)],
                Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: PixelColors.muted),
              ],
            ),
            if (open) ...[
              const SizedBox(height: 12),
              for (final (i, s) in c.steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.color.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: PixelText('${i + 1}', size: 12, color: c.color, bold: true),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: PixelText(s.of(lang), size: 14)),
                    ],
                  ),
                ),
              for (final p in c.phrases)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: c.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PixelText(p.ja, size: 17),
                      PixelText('${_sounds.of(lang)}: ${p.roma}', size: 12, color: PixelColors.muted),
                      if (lang != 'ja') PixelText(p.means.of(lang), size: 13, color: c.color),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
