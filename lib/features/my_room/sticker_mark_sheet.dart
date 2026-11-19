import 'package:material_ui/material_ui.dart';

import '../../core/localized_text.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../data/sticker_marks.dart';
import '../../l10n/app_localizations.dart';

/// Bottom sheet after a trip: pick a sticker for each station (where you got
/// on and off); it is stuck on that station of the route map. Only the
/// stickers from packs the user owns are offered (more in MY's shop).
class StickerMarkSheet extends StatefulWidget {
  const StickerMarkSheet({super.key, required this.city, required this.stationIds});

  final CityData city;
  final List<String> stationIds;

  @override
  State<StickerMarkSheet> createState() => _StickerMarkSheetState();
}

class _StickerMarkSheetState extends State<StickerMarkSheet> {
  static const _title = LocalizedText({'ja': 'ステッカーで駅をマーク', 'ko': '스티커로 역 표시하기', 'en': 'Mark the stations'});
  static const _hint = LocalizedText({
    'ja': '路線図のその駅に貼られます。もう一度タップではがせます',
    'ko': '노선도의 그 역에 붙어요. 한 번 더 누르면 떼어져요',
    'en': 'It goes on that station on the route map. Tap again to take it off',
  });
  static const _more = LocalizedText({
    'ja': 'MYのショップでステッカーセットが買えます',
    'ko': 'MY 상점에서 스티커 세트를 살 수 있어요',
    'en': 'More sticker sets in the MY shop',
  });

  @override
  void initState() {
    super.initState();
    Services.stickers.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context).localeName;
    final marks = Services.stickers;
    final mine = ownedStickers(Services.my);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelText(_title.of(lang), size: 22),
            const SizedBox(height: 4),
            Text(_hint.of(lang), style: const TextStyle(fontSize: 12, color: PixelColors.muted)),
            for (final id in widget.stationIds.toSet()) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.city.line(widget.city.station(id).lines.first).color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  PixelText(widget.city.station(id).name.of(lang), size: 17),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final s in mine)
                      GestureDetector(
                        onTap: () async {
                          await marks.put(id, marks.at(id) == s ? null : s);
                          if (mounted) setState(() {});
                        },
                        child: Container(
                          width: 52,
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: marks.at(id) == s ? const Color(0xFFFFF0C2) : PixelColors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: marks.at(id) == s ? const Color(0xFFE0A100) : PixelColors.line,
                              width: marks.at(id) == s ? 2 : 1,
                            ),
                          ),
                          child: Image.asset('assets/art/stickers/$s.png', filterQuality: FilterQuality.none),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(_more.of(lang), style: const TextStyle(fontSize: 12, color: PixelColors.muted)),
          ],
        ),
      ),
    );
  }
}
