import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/localized_text.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../data/models/city.dart';
import '../../data/models/route_map.dart';
import '../../l10n/app_localizations.dart';

/// A landmark's note and the stations to go from (`assets/cities/<city>/landmarks.json`),
/// keyed by the picture's name (e.g. 'tower' for assets/art/landmarks/tower.png).
typedef LandmarkInfo = ({LocalizedText about, List<String> stations});

Future<Map<String, LandmarkInfo>> loadLandmarkInfo(String cityId) async {
  try {
    final raw = jsonDecode(await rootBundle.loadString('assets/cities/$cityId/landmarks.json')) as Map<String, dynamic>;
    return {
      for (final e in raw.entries)
        e.key: (
          about: LocalizedText.fromJson((e.value as Map<String, dynamic>)['about'] as Map<String, dynamic>),
          stations: [for (final s in (e.value as Map<String, dynamic>)['stations'] as List) s as String],
        ),
    };
  } catch (_) {
    return const {};
  }
}

String landmarkKey(MapLandmark lm) {
  final file = lm.image.split('/').last;
  return file.substring(0, file.lastIndexOf('.'));
}

/// Landmark card: the picture (moving, if it does), a short note and the
/// nearest stations, each with 出発 / 到着. Pops (stationId, from).
class LandmarkSheet extends StatelessWidget {
  const LandmarkSheet({super.key, required this.city, required this.landmark, required this.image, this.info});

  final CityData city;
  final MapLandmark landmark;
  final ui.Image? image;
  final LandmarkInfo? info;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final info = this.info;
    final name = landmark.name;
    final sub = lang == 'ja' ? name.of('en') : name.ja;
    final near = info?.stations.where(city.stations.containsKey).firstOrNull;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (image != null)
                  Container(
                    width: 104,
                    height: 104,
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F0E2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: PixelColors.line),
                    ),
                    child: _LandmarkPicture(image: image!, frames: landmark.frames),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PixelText(name.of(lang), size: 26),
                      if (sub != name.of(lang)) ...[
                        const SizedBox(height: 2),
                        PixelText(sub, size: 13, color: PixelColors.muted, maxLines: 1),
                      ],
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
            // One big button: the nearest station as where to go.
            if (near != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  key: const ValueKey('landmark.goHere'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE0513F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context, (near, false)),
                  icon: const Icon(Icons.directions_transit_rounded),
                  label: Text(t.mapGoHere(city.station(near).name.of(lang)), style: const TextStyle(fontSize: 17)),
                ),
              ),
            ],
            if (info != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: PixelColors.background, borderRadius: BorderRadius.circular(14)),
                child: PixelText(info.about.of(lang), size: 15),
              ),
              if (info.stations.isNotEmpty) ...[
                const SizedBox(height: 16),
                PixelText(t.mapLmStations, size: 13, color: PixelColors.muted),
                const SizedBox(height: 6),
                for (final id in info.stations)
                  if (city.stations.containsKey(id)) _StationRow(city: city, stationId: id, lang: lang),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StationRow extends StatelessWidget {
  const _StationRow({required this.city, required this.stationId, required this.lang});
  final CityData city;
  final String stationId;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final station = city.station(stationId);
    Widget button(String label, Color color, bool from) => Semantics(
      button: true,
      label: '${station.name.of(lang)} $label',
      child: GestureDetector(
        onTap: () => Navigator.pop(context, (stationId, from)),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: PixelText(label, size: 15, color: PixelColors.card),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText(station.name.ja, size: 19, maxLines: 1),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (final id in station.lines.take(8))
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: city.line(id).color, borderRadius: BorderRadius.circular(3)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          button(t.mapFrom, const Color(0xFF2E9447), true),
          const SizedBox(width: 8),
          button(t.mapTo, const Color(0xFFE0513F), false),
        ],
      ),
    );
  }
}

/// 名所をさがす: every landmark of the city as a list, picture first; picking
/// one pops it (the map then flies there and opens its card).
class SightsSheet extends StatelessWidget {
  const SightsSheet({
    super.key,
    required this.city,
    required this.landmarks,
    required this.images,
    required this.info,
    this.scroll,
  });
  final CityData city;
  final List<MapLandmark> landmarks;
  final Map<String, ui.Image> images;
  final Map<String, LandmarkInfo> info;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        PixelText(t.mapSightsTitle, size: 22),
        const SizedBox(height: 2),
        PixelText(t.mapSightsHint, size: 12, color: PixelColors.muted),
        const SizedBox(height: 12),
        for (final lm in landmarks) _row(context, lm, lang, t),
      ],
    );
  }

  Widget _row(BuildContext context, MapLandmark lm, String lang, AppLocalizations t) {
    final i = info[landmarkKey(lm)];
    final img = images[lm.image];
    final near = i?.stations.where(city.stations.containsKey).firstOrNull;
    return Semantics(
      button: true,
      label: lm.name.of(lang),
      child: GestureDetector(
        key: ValueKey('sight.${landmarkKey(lm)}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context, lm),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: PixelColors.background, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: const Color(0xFFE9F0E2), borderRadius: BorderRadius.circular(12)),
                child: img == null ? null : CustomPaint(painter: _PicturePainter(img, lm.frames, 0)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PixelText(lm.name.of(lang), size: 17, maxLines: 1),
                    if (i != null) PixelText(i.about.of(lang), size: 12, color: PixelColors.muted, maxLines: 2),
                    if (near != null)
                      PixelText(
                        t.mapNearSt(city.station(near).name.of(lang)),
                        size: 12,
                        color: const Color(0xFF2E9447),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: PixelColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The landmark's pixel art, crisp, playing its frames if it moves.
class _LandmarkPicture extends StatefulWidget {
  const _LandmarkPicture({required this.image, required this.frames});
  final ui.Image image;
  final int frames;

  @override
  State<_LandmarkPicture> createState() => _LandmarkPictureState();
}

class _LandmarkPictureState extends State<_LandmarkPicture> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((e) {
    final f = (e.inMilliseconds ~/ 140) % widget.frames;
    if (f != _frame) setState(() => _frame = f);
  });
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    if (widget.frames > 1) _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PicturePainter(widget.image, widget.frames, _frame));
}

class _PicturePainter extends CustomPainter {
  _PicturePainter(this.image, this.frames, this.frame);
  final ui.Image image;
  final int frames;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final fw = image.width / frames, h = image.height.toDouble();
    // As large as fits (whole quarter steps keep the pixels even enough).
    final k = (((size.shortestSide - 10) / (fw > h ? fw : h)) * 4).floorToDouble() / 4;
    final w = fw * k, hh = h * k;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(frame * fw, 0, fw, h),
      Rect.fromLTWH((size.width - w) / 2, (size.height - hh) / 2, w, hh),
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_PicturePainter old) => old.frame != frame || old.image != image;
}
