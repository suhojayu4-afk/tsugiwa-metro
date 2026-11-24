import 'package:material_ui/material_ui.dart';

import '../../core/localized_text.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/achievements.dart';
import '../../data/models/city.dart';
import '../../l10n/app_localizations.dart';

/// A round medal: ribbon-less coin in the tier's metal with the badge's
/// picture in the middle; grey and faded until earned.
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({super.key, required this.badge, required this.earned, this.size = 56});
  final TripBadge badge;
  final bool earned;
  final double size;

  static const _metal = {
    BadgeTier.bronze: (Color(0xFFE3A06A), Color(0xFFA9622F)),
    BadgeTier.silver: (Color(0xFFE6EAF0), Color(0xFF9AA3B2)),
    BadgeTier.gold: (Color(0xFFFFE07A), Color(0xFFD49A1E)),
  };

  @override
  Widget build(BuildContext context) {
    final (light, dark) = earned ? _metal[badge.tier]! : (const Color(0xFFE7E7E2), const Color(0xFFBDBDB6));
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, dark]),
          border: Border.all(color: dark, width: size * 0.05),
          boxShadow: earned
              ? [
                  BoxShadow(
                    color: dark.withValues(alpha: 0.45),
                    blurRadius: size * 0.08,
                    offset: Offset(0, size * 0.04),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.17),
          child: Opacity(
            opacity: earned ? 1 : 0.28,
            child: ColorFiltered(
              colorFilter: earned
                  ? const ColorFilter.mode(Color(0x00000000), BlendMode.dst)
                  : const ColorFilter.matrix([
                      0.33, 0.33, 0.33, 0, 0, //
                      0.33, 0.33, 0.33, 0, 0,
                      0.33, 0.33, 0.33, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
              child: Image.asset(badge.icon, filterQuality: FilterQuality.none, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet with every badge: earned ones shine, the rest say how.
class BadgesSheet extends StatelessWidget {
  const BadgesSheet({super.key, required this.city});
  final CityData city;

  static const title = LocalizedText({'ja': 'バッジ', 'ko': '배지', 'en': 'Badges'});
  static const _count = LocalizedText({'ja': '{n} / {all} 個ゲット', 'ko': '{n} / {all}개 획득', 'en': '{n} of {all} earned'});

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context).localeName;
    final got = earnedBadges(city, Services.my);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelText(title.of(lang), size: 24),
            const SizedBox(height: 2),
            Text(
              _count.of(lang).replaceAll('{n}', '${got.length}').replaceAll('{all}', '${badges.length}'),
              style: TextStyle(fontSize: 12, color: PixelColors.muted),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 8,
                childAspectRatio: 0.68,
                children: [
                  for (final b in badges)
                    Column(
                      children: [
                        BadgeMedal(badge: b, earned: got.contains(b.id), size: 58),
                        const SizedBox(height: 4),
                        Text(
                          b.name.of(lang),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: got.contains(b.id) ? PixelColors.ink : PixelColors.muted,
                          ),
                        ),
                        if (!got.contains(b.id))
                          Text(
                            b.how.of(lang),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 9, color: PixelColors.muted),
                          ),
                      ],
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
