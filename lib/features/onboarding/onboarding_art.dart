import 'package:material_ui/material_ui.dart';

import '../../core/localized_text.dart';
import '../../core/pixel/pixel_ui.dart';

/// Every picture is laid out on this canvas and scaled to fit the screen.
const artSize = Size(320, 260);

const _shibuya = LocalizedText({'ja': '渋谷', 'ko': '시부야', 'en': 'Shibuya'});
const _tokyo = LocalizedText({'ja': '東京', 'ko': '도쿄', 'en': 'Tokyo'});
const _otemachi = LocalizedText({'ja': '大手町', 'ko': '오테마치', 'en': 'Otemachi'});
const _ueno = LocalizedText({'ja': '上野', 'ko': '우에노', 'en': 'Ueno'});

const _yamanote = Color(0xFF80C241);
const _star = Color(0xFFF2B33D);
const _bell = Color(0xFFE5484D);

Widget _pixelImage(String asset, {double? width, double? height, BoxFit fit = BoxFit.cover}) =>
    Image.asset(asset, width: width, height: height, fit: fit, filterQuality: FilterQuality.none);

/// A pixel-art scene with the train coming in, in a soft frame.
class _Scene extends StatelessWidget {
  const _Scene({required this.asset, required this.part});
  final String asset;
  final String part; // day / evening / night

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: 320,
      height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _pixelImage(asset),
          Positioned(
            left: 162,
            top: 34,
            width: 62,
            height: 80,
            child: _TrainFront(part: part, line: _yamanote),
          ),
        ],
      ),
    ),
  );
}

class _TrainFront extends StatelessWidget {
  const _TrainFront({required this.part, required this.line});
  final String part;
  final Color line;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _pixelImage('assets/art/train_front_base_$part.webp', fit: BoxFit.fill),
      ColorFiltered(
        colorFilter: ColorFilter.mode(line, BlendMode.modulate),
        child: _pixelImage('assets/art/train_front_stripe.webp', fit: BoxFit.fill),
      ),
    ],
  );
}

class _Sticker extends StatelessWidget {
  const _Sticker(this.name, {this.size = 48, this.turn = 0});
  final String name;
  final double size;
  final double turn;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: turn,
    child: _pixelImage('assets/art/stickers/$name.png', width: size, height: size, fit: BoxFit.contain),
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon, {required this.color, this.fill, this.size = 30});
  final IconData icon;
  final Color color;
  final Color? fill;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: fill ?? PixelColors.card, shape: BoxShape.circle),
    child: Icon(icon, size: size * 0.56, color: color),
  );
}

TextStyle _small(Color color, {double size = 10}) => pixelStyle(size: size, color: color, height: 1.2);

// ---------------------------------------------------------------------------
// 1. Favourite routes

class RoutesArt extends StatelessWidget {
  const RoutesArt({super.key, required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, LocalizedText from, LocalizedText to) => Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(color: const Color(0xFFEEF6EF), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          _RoundIcon(icon, color: PixelColors.title),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText(label, size: 16),
                const SizedBox(height: 1),
                Text('${from.of(lang)} → ${to.of(lang)}', style: _small(PixelColors.muted)),
              ],
            ),
          ),
          const Icon(Icons.star_rounded, size: 22, color: _star),
        ],
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 0,
          top: 0,
          child: _Scene(asset: 'assets/art/scenes/tokyo_day.webp', part: 'day'),
        ),
        Positioned(
          left: 22,
          right: 22,
          top: 112,
          child: PixelBox(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: _star),
                    const SizedBox(width: 4),
                    Text(
                      const LocalizedText({'ja': 'よく使うルート', 'ko': '자주 가는 경로', 'en': 'Your routes'}).of(lang),
                      style: _small(PixelColors.muted, size: 11),
                    ),
                  ],
                ),
                row(
                  Icons.home_rounded,
                  const LocalizedText({'ja': '自宅へ', 'ko': '집으로', 'en': 'Home'}).of(lang),
                  _otemachi,
                  _shibuya,
                ),
                row(
                  Icons.work_rounded,
                  const LocalizedText({'ja': '会社へ', 'ko': '회사로', 'en': 'Work'}).of(lang),
                  _shibuya,
                  _otemachi,
                ),
              ],
            ),
          ),
        ),
        const Positioned(right: -6, top: -14, child: _Sticker('star', size: 52, turn: 0.22)),
        const Positioned(left: 4, top: 86, child: _Sticker('sakura', size: 34, turn: -0.2)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Last-train alarm

class AlarmArt extends StatelessWidget {
  const AlarmArt({super.key, required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) {
    final notice = PixelBox(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: const Color(0xFFFDE8E8), borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: _pixelImage('assets/art/widget/icon_bell.webp', width: 20, height: 20, fit: BoxFit.contain),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  const LocalizedText({'ja': '終電まであと30分', 'ko': '막차까지 30분', 'en': 'Last train in 30 min'}).of(lang),
                  style: pixelStyle(
                    size: 12,
                    color: PixelColors.ink,
                    height: 1.2,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  const LocalizedText({'ja': 'そろそろ帰る準備を！', 'ko': '슬슬 돌아갈 준비를!', 'en': 'Time to head home!'}).of(lang),
                  style: _small(PixelColors.muted),
                ),
              ],
            ),
          ),
          Text('23:58', style: _small(PixelColors.muted, size: 9)),
        ],
      ),
    );

    final card = PixelBox(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          Container(width: 3, height: 64, color: _yamanote),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_tokyo.of(lang)} → ${_ueno.of(lang)}', style: _small(PixelColors.muted, size: 10)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PixelText(
                        const LocalizedText({'ja': '終電', 'ko': '막차', 'en': 'Last'}).of(lang),
                        size: 16,
                        color: PixelColors.muted,
                      ),
                      const SizedBox(width: 6),
                      const PixelText('00:30', size: 26, bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 12, color: PixelColors.title),
                    const SizedBox(width: 3),
                    Text(
                      const LocalizedText({'ja': '始発 04:50', 'ko': '첫차 04:50', 'en': 'First 04:50'}).of(lang),
                      style: _small(PixelColors.title),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _bell.withValues(alpha: 0.25), width: 3),
                ),
              ),
              _RoundIcon(Icons.notifications_active_rounded, color: _bell, fill: const Color(0xFFFDE8E8), size: 36),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, size: 24, color: _star),
        ],
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 0,
          top: 0,
          child: _Scene(asset: 'assets/art/scenes/shinjuku_night.webp', part: 'night'),
        ),
        Positioned(left: 30, right: 30, top: 12, child: notice),
        Positioned(left: 22, right: 22, top: 136, child: card),
        Positioned(
          right: -10,
          top: -18,
          child: _pixelImage('assets/art/widget/icon_moon.webp', width: 48, height: 48, fit: BoxFit.contain),
        ),
        const Positioned(left: -4, top: 110, child: _Sticker('onigiri', size: 34, turn: -0.18)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Home-screen widgets and the MY share card

class WidgetShareArt extends StatelessWidget {
  const WidgetShareArt({super.key, required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) {
    // The MY station widget: scene, hanging station sign, weather chip.
    final station = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 184,
        height: 92,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _pixelImage('assets/art/scenes/asakusa_evening.webp'),
            Positioned(
              left: 88,
              top: 22,
              width: 36,
              height: 46,
              child: _TrainFront(part: 'evening', line: _pink),
            ),
            Positioned(left: 40, top: 8, width: 104, child: _StationSign(lang: lang)),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  const LocalizedText({'ja': '晴れ 18℃', 'ko': '맑음 18℃', 'en': 'Sunny 18℃'}).of(lang),
                  style: _small(PixelColors.card, size: 9).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // The last-train board widget.
    final board = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 184,
        height: 54,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _pixelImage('assets/art/widget/board_night_clear.webp'),
            Positioned(
              left: 8,
              top: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1714),
                  border: Border.all(color: const Color(0xFF4A4038), width: 2),
                ),
                child: Text(
                  '${const LocalizedText({'ja': '終電', 'ko': '막차', 'en': 'Last'}).of(lang)} 00:30',
                  style: pixelStyle(size: 16, color: const Color(0xFFFFA43A), height: 1),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      _pixelImage('assets/art/widget/icon_bell.webp', width: 12, height: 12, fit: BoxFit.contain),
                      const SizedBox(width: 2),
                      Text(
                        const LocalizedText({'ja': '始発', 'ko': '첫차', 'en': 'First'}).of(lang),
                        style: _small(const Color(0xFF9BE39B), size: 9),
                      ),
                    ],
                  ),
                  Text('04:50', style: _small(const Color(0xFF9BE39B), size: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    Widget appIcon(String asset) => Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: const Color(0xFFF4F4F1), borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: _pixelImage(asset, width: 26, height: 26, fit: BoxFit.contain),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Home-screen wallpaper: the night skyline.
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF1F2350)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 120,
                  child: _pixelImage('assets/art/side_far_night.webp', fit: BoxFit.cover),
                ),
              ],
            ),
          ),
        ),
        Positioned(left: 14, top: 16, child: station),
        Positioned(left: 14, top: 118, child: board),
        Positioned(
          left: 14,
          bottom: 14,
          child: Row(
            children: [
              appIcon('assets/art/tab_platform.png'),
              const SizedBox(width: 12),
              appIcon('assets/art/tab_map.png'),
              const SizedBox(width: 12),
              appIcon('assets/art/tab_my.png'),
            ],
          ),
        ),
        Positioned(
          right: 10,
          top: 30,
          child: Transform.rotate(angle: 0.08, child: _ShareTicket(lang: lang)),
        ),
        const Positioned(right: 0, bottom: 34, child: _Sticker('hanko', size: 44, turn: -0.15)),
        const Positioned(right: 100, top: 2, child: _Sticker('sparkle', size: 28)),
      ],
    );
  }
}

const _pink = Color(0xFFE88AA8);

class _StationSign extends StatelessWidget {
  const _StationSign({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: Border.all(color: const Color(0xFF3A3D46), width: 2)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: PixelColors.card,
          width: double.infinity,
          padding: const EdgeInsets.only(top: 1),
          child: Column(
            children: [
              Text('さくらざか', style: _small(PixelColors.ink, size: 6)),
              Text('桜坂', style: pixelStyle(size: 16, height: 1)),
            ],
          ),
        ),
        Container(
          color: _pink,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.arrow_left_rounded, size: 8, color: PixelColors.card),
                  Text('うえの', style: _small(PixelColors.card, size: 6)),
                ],
              ),
              Row(
                children: [
                  Text('かんだ', style: _small(PixelColors.card, size: 6)),
                  Icon(Icons.arrow_right_rounded, size: 8, color: PixelColors.card),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A small 乗車記念 ticket like the MY share card.
class _ShareTicket extends StatelessWidget {
  const _ShareTicket({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    decoration: BoxDecoration(
      color: const Color(0xFFF6EDD9),
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 4), blurRadius: 0)],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 5, color: _yamanote),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD2473C), width: 1)),
                child: Text(
                  const LocalizedText({'ja': '乗車記念', 'ko': '승차 기념', 'en': 'Ride pass'}).of(lang),
                  style: _small(const Color(0xFFD2473C), size: 7),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('桜坂', style: pixelStyle(size: 20, height: 1, color: const Color(0xFF3A2E25))),
                  const SizedBox(width: 2),
                  Text('駅', style: _small(const Color(0xFF3A2E25), size: 9)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 96,
                  height: 48,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _pixelImage('assets/art/scenes/tokyo_day.webp'),
                      const Positioned(
                        left: 48,
                        top: 10,
                        width: 19,
                        height: 25,
                        child: _TrainFront(part: 'day', line: _yamanote),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    color: const Color(0xFFF7C948),
                    child: Text('Lv.4', style: _small(const Color(0xFF3A2E25), size: 8)),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      const LocalizedText({'ja': 'スタンプ 20駅', 'ko': '스탬프 20역', 'en': '20 stamps'}).of(lang),
                      style: _small(const Color(0xFF3A2E25), size: 7),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _yamanote, width: 2),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
