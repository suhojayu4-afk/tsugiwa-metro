import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../l10n/app_localizations.dart';
import 'stamp_book_screen.dart';
import 'station_plate.dart';

/// Bottom sheet: a picture card of the user's station (scene, sign and
/// stamp count) to post on X / Instagram through the phone's share menu.
class ShareCardSheet extends StatefulWidget {
  const ShareCardSheet({super.key, required this.city, required this.plate, required this.lineColor});

  final CityData city;
  final PlateData plate;
  final Color lineColor;

  @override
  State<ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<ShareCardSheet> {
  final _card = GlobalKey();
  bool _busy = false;

  /// Card size in logical pixels; saved at 3× (1080×1350, Instagram 4:5).
  static const cardWidth = 360.0;
  static const cardHeight = 450.0;

  Future<void> _share() async {
    final t = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final boundary = _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1080 / cardWidth);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await SharePlus.instance.share(
        ShareParams(
          text: t.shareText,
          files: [XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png', name: 'my_station.png')],
          fileNameOverrides: ['my_station.png'],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.shareFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelText(t.shareTitle, size: 24),
            const SizedBox(height: 12),
            Center(
              child: FittedBox(
                child: RepaintBoundary(
                  key: _card,
                  child: ShareCard(city: widget.city, plate: widget.plate, lineColor: widget.lineColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _busy ? null : _share,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: PixelColors.ink, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.ios_share_rounded, color: PixelColors.card, size: 20),
                    const SizedBox(width: 8),
                    PixelText(t.shareButton, size: 18, color: PixelColors.card),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card itself (360×450 logical).
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.city, required this.plate, required this.lineColor});

  final CityData city;
  final PlateData plate;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final store = Services.my;
    final stamps = city.stations.keys.where(store.stamped).length;
    final lines = city.lines.where((l) => store.lineComplete(l.id)).length;
    final recent =
        (store.stamps.entries.where((e) => city.stations.containsKey(e.key)).toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(6)
            .toList();
    return Container(
      width: _ShareCardSheetState.cardWidth,
      height: _ShareCardSheetState.cardHeight,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: PixelColors.background,
        border: Border.all(color: PixelColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelText(t.shareHeading, size: 13, color: PixelColors.muted),
          const SizedBox(height: 2),
          PixelText(t.shareStation(plate.name), size: 24),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MediaQuery(
              // Draw the pixel art for the saved size (3×), not the screen.
              data: MediaQuery.of(context).copyWith(devicePixelRatio: 1080 / _ShareCardSheetState.cardWidth),
              child: MyStationView(look: store.look, plate: plate, lineColor: lineColor, aspect: 1.45),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(label: t.shareStamps, value: '$stamps', unit: t.shareStampUnit),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(label: t.shareLines, value: '$lines', unit: t.shareLineUnit),
              ),
            ],
          ),
          const Spacer(),
          // The latest stamps, like a page of the stamp book.
          if (recent.isNotEmpty)
            Row(
              children: [
                for (final e in recent)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: StationStamp(
                        name: city.station(e.key).name.of('ja'),
                        day: e.value,
                        color: city.line(city.station(e.key).lines.first).color,
                        seed: e.key.hashCode,
                      ),
                    ),
                  ),
              ],
            ),
          const Spacer(),
          Row(
            children: [
              Image.asset(
                'assets/art/tab_platform.png',
                width: 20,
                height: 20,
                filterQuality: FilterQuality.none,
              ),
              const SizedBox(width: 6),
              PixelText(t.appTitle, size: 16),
              const Spacer(),
              PixelText('#つぎはMetro', size: 12, color: PixelColors.muted),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    decoration: BoxDecoration(
      color: PixelColors.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: PixelColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PixelText(label, size: 11, color: PixelColors.muted),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PixelText(value, size: 24, bold: true),
            const SizedBox(width: 4),
            Padding(padding: const EdgeInsets.only(bottom: 3), child: PixelText(unit, size: 12)),
          ],
        ),
      ],
    ),
  );
}
