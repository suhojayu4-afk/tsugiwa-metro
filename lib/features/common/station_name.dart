import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../data/models/station.dart';

/// Station name: Japanese original, plus reading / translation underneath.
/// ja → 渋谷 / しぶや, ko → 渋谷 / 시부야, en → 渋谷 / Shibuya.
class StationName extends StatelessWidget {
  const StationName({
    super.key,
    required this.station,
    this.size = 24,
    this.align = CrossAxisAlignment.start,
  });

  final Station station;
  final double size;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    final sub = lang == 'ja' ? station.kana : station.name.of(lang);
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelText(station.name.ja, size: size),
        PixelText(sub, size: size / 2 < 14 ? 14 : size / 2, color: PixelColors.muted),
      ],
    );
  }
}
