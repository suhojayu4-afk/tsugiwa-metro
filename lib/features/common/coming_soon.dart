import 'package:material_ui/material_ui.dart';

import '../../core/pixel/pixel_art.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../l10n/app_localizations.dart';

/// Placeholder for a tab that is not built yet (MY room for now).
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({super.key, required this.title, required this.body, required this.sprite});
  final String title;
  final String body;
  final PixelSprite sprite;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        PixelText(title, size: 32),
        const SizedBox(height: 48),
        Center(
          child: PixelSpriteView(sprite: sprite, pixelSize: 6, lineColor: PixelColors.muted),
        ),
        const SizedBox(height: 32),
        PixelBox(
          child: Column(
            children: [
              PixelText(t.comingSoon, size: 24),
              const SizedBox(height: 8),
              PixelText(body, size: 16, color: PixelColors.muted, align: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}
