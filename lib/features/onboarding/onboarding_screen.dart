import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localized_text.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_art.dart';

/// "Seen the first-run tour" flag, kept on the phone.
class OnboardingFlag {
  static const key = 'onboardingSeen';

  static Future<bool> seen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return true; // never block the app on a storage problem
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {}
  }
}

/// Shows the first-run tour once, then [child] (the app) from then on.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child});
  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _seen;

  @override
  void initState() {
    super.initState();
    OnboardingFlag.seen().then((seen) {
      if (mounted) setState(() => _seen = seen);
    });
  }

  void _done() {
    OnboardingFlag.markSeen();
    setState(() => _seen = true);
  }

  @override
  Widget build(BuildContext context) {
    final Widget shown = switch (_seen) {
      null => const ColoredBox(key: ValueKey('wait'), color: PixelColors.background),
      false => OnboardingScreen(key: const ValueKey('tour'), onDone: _done),
      true => KeyedSubtree(key: const ValueKey('app'), child: widget.child),
    };
    return AnimatedSwitcher(duration: const Duration(milliseconds: 280), child: shown);
  }
}

class _Page {
  const _Page({
    required this.tab,
    required this.step,
    required this.accent,
    required this.title,
    required this.body,
    required this.tips,
    required this.art,
  });

  final String tab; // tab icon
  final LocalizedText step;
  final Color accent;
  final LocalizedText title;
  final LocalizedText body;
  final List<(IconData, LocalizedText)> tips;
  final Widget Function(String lang) art;
}

final _pages = [
  _Page(
    tab: 'assets/art/tab_platform.png',
    step: const LocalizedText({'ja': 'のりば', 'ko': '승강장', 'en': 'Platform'}),
    accent: const Color(0xFF2E9447),
    title: const LocalizedText({'ja': 'いつもの道は ☆ で登録', 'ko': '자주 가는 길은 ☆로 등록', 'en': 'Save your usual trips with ☆'}),
    body: const LocalizedText({
      'ja': 'のりばで出発と到着をえらんで ☆ をタップ。「自宅へ」「会社へ」にしておけば、次からワンタップで追跡できます。',
      'ko': '승강장에서 출발과 도착을 고르고 ☆를 탭하세요. \'집으로\' \'회사로\'로 등록해 두면 다음부터 한 번에 추적할 수 있어요.',
      'en': 'Pick From and To on the Platform tab, then tap ☆. Mark it Home or Work and start tracking in one tap.',
    }),
    tips: [
      (Icons.home_rounded, const LocalizedText({'ja': '帰り道は「自宅へ」', 'ko': '귀갓길은 \'집으로\'', 'en': 'The way back: Home'})),
      (Icons.work_rounded, const LocalizedText({'ja': '通勤は「会社へ」', 'ko': '출근길은 \'회사로\'', 'en': 'Your commute: Work'})),
    ],
    art: (lang) => RoutesArt(lang: lang),
  ),
  _Page(
    tab: 'assets/art/tab_platform.png',
    step: const LocalizedText({'ja': '終電アラーム', 'ko': '막차 알림', 'en': 'Last-train alert'}),
    accent: const Color(0xFF4B4FA8),
    title: const LocalizedText({
      'ja': '終電アラームで\nもう乗り遅れない',
      'ko': '막차 알림으로\n이제 놓치지 않아요',
      'en': 'Never miss the last train',
    }),
    body: const LocalizedText({
      'ja': 'ルートカードのベルをタップすると、毎晩 終電の前にお知らせします。朝が早い日は始発アラームもどうぞ。',
      'ko': '경로 카드의 종을 탭하면 매일 밤 막차 전에 알려 드려요. 아침 일찍 나가는 날엔 첫차 알림도 있어요.',
      'en': 'Tap the bell on the route card and we\'ll remind you every night before the last train. Early start? There\'s a first-train alert too.',
    }),
    tips: [
      (
        Icons.notifications_active_rounded,
        const LocalizedText({'ja': '終電の前に 毎晩お知らせ', 'ko': '막차 전에 매일 밤 알림', 'en': 'A nudge before the last train'}),
      ),
      (
        Icons.wb_twilight_rounded,
        const LocalizedText({
          'ja': '始発アラームで 朝もばっちり',
          'ko': '첫차 알림으로 아침도 든든',
          'en': 'First-train alert for early mornings',
        }),
      ),
    ],
    art: (lang) => AlarmArt(lang: lang),
  ),
  _Page(
    tab: 'assets/art/tab_my.png',
    step: const LocalizedText({'ja': 'ウィジェット & MY', 'ko': '위젯 & MY', 'en': 'Widgets & MY'}),
    accent: const Color(0xFFD9577F),
    title: const LocalizedText({
      'ja': 'ホーム画面とMY駅で\nもっと楽しく',
      'ko': '홈 화면과 MY 역으로\n더 즐겁게',
      'en': 'Your station, everywhere',
    }),
    body: const LocalizedText({
      'ja': 'ウィジェットを置けば、アプリを開かずに駅と天気をチェック。MYでは自分だけの駅をつくって、カードでシェアできます。',
      'ko': '위젯을 놓으면 앱을 열지 않아도 역과 날씨를 볼 수 있어요. MY에서는 나만의 역을 꾸미고 카드로 공유해 보세요.',
      'en': 'Add a home-screen widget to see your station and the weather at a glance. In MY, build your own station and share it as a card.',
    }),
    tips: [
      (
        Icons.widgets_rounded,
        const LocalizedText({
          'ja': 'ホーム画面を長押し →「ウィジェット」',
          'ko': '홈 화면 길게 누르기 →「위젯」',
          'en': 'Long-press the home screen → Widgets',
        }),
      ),
      (
        Icons.ios_share_rounded,
        const LocalizedText({'ja': 'MY駅カードでシェア', 'ko': 'MY 역 카드로 공유', 'en': 'Share your MY station card'}),
      ),
    ],
    art: (lang) => WidgetShareArt(lang: lang),
  ),
];

const _skip = LocalizedText({'ja': 'スキップ', 'ko': '건너뛰기', 'en': 'Skip'});
const _next = LocalizedText({'ja': 'つぎへ', 'ko': '다음', 'en': 'Next'});
const _start = LocalizedText({'ja': 'はじめる', 'ko': '시작하기', 'en': 'Get started'});

/// Three-page first-run tour: favourite routes, last-train alarm, widgets
/// and the MY share card. Calls [onDone] on Skip or Start.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone, this.initialPage = 0});
  final VoidCallback onDone;

  /// For review renders.
  final int initialPage;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final _controller = PageController(initialPage: widget.initialPage);
  late int _page = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _last => _page == _pages.length - 1;

  void _onNext() {
    if (_last) {
      widget.onDone();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context).localeName;
    final accent = _pages[_page].accent;
    return Scaffold(
      backgroundColor: PixelColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    PixelText('${_page + 1} / ${_pages.length}', size: 16, color: PixelColors.muted),
                    const Spacer(),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _last ? 0 : 1,
                      child: IgnorePointer(
                        ignoring: _last,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onDone,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            child: PixelText(_skip.of(lang), size: 16, color: PixelColors.muted),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, i) => _PageView(page: _pages[i], index: i, controller: _controller, lang: lang),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dots(count: _pages.length, page: _page, color: accent),
                  const SizedBox(height: 18),
                  PixelButton(
                    expand: true,
                    color: _last ? PixelColors.title : PixelColors.ink,
                    onPressed: _onNext,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PixelText((_last ? _start : _next).of(lang), size: 18),
                        const SizedBox(width: 8),
                        Icon(
                          _last ? Icons.train_rounded : Icons.arrow_forward_rounded,
                          size: 18,
                          color: PixelColors.card,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page, required this.index, required this.controller, required this.lang});
  final _Page page;
  final int index;
  final PageController controller;
  final String lang;

  @override
  Widget build(BuildContext context) {
    // A little parallax: the picture lags behind the swipe and fades.
    final art = AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        var delta = 0.0;
        if (controller.hasClients && controller.position.hasContentDimensions) {
          delta = (controller.page ?? index.toDouble()) - index;
        }
        return Opacity(
          opacity: (1 - delta.abs() * 0.6).clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(delta * 60, 0), child: child),
        );
      },
      child: AspectRatio(
        aspectRatio: artSize.aspectRatio,
        child: FittedBox(
          child: SizedBox.fromSize(size: artSize, child: page.art(lang)),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(child: art),
          const SizedBox(height: 24),
          _StepChip(tab: page.tab, text: page.step.of(lang), color: page.accent),
          const SizedBox(height: 10),
          PixelText(page.title.of(lang), size: 22),
          const SizedBox(height: 10),
          Text(page.body.of(lang), style: pixelStyle(size: 14, height: 1.55, color: const Color(0xFF4A4F58))),
          const SizedBox(height: 14),
          for (final (icon, tip) in page.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      PixelSquare(color: page.accent.withValues(alpha: 0.14), size: 24),
                      Icon(icon, size: 15, color: page.accent),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tip.of(lang), style: pixelStyle(size: 13, color: PixelColors.ink)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.tab, required this.text, required this.color});
  final String tab;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => PixelBox(
    color: color.withValues(alpha: 0.12),
    borderColor: color.withValues(alpha: 0.12),
    padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(tab, width: 20, height: 20, filterQuality: FilterQuality.none),
        const SizedBox(width: 6),
        PixelText(text, size: 16, color: color),
      ],
    ),
  );
}

/// Page dots: the current one stretches into a bar.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page, required this.color});
  final int count;
  final int page;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == page ? 24 : 8,
          height: 8,
          color: i == page ? color : PixelColors.line,
        ),
    ],
  );
}
