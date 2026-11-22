import '../../core/localized_text.dart';
import '../my_room/sticker_mark_sheet.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../data/my_store.dart';
import '../../l10n/app_localizations.dart';
import '../common/station_name.dart';
import 'trip_controller.dart';
import 'widgets/progress_track.dart';
import 'widgets/side_train_view.dart';
import 'widgets/stamp_slam.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key, required this.controller});
  final TripController controller;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  StreamSubscription<TripEvent>? _sub;

  TripController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _sub = c.events.listen(_onEvent);
    c.start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    c.cancel();
    c.dispose();
    super.dispose();
  }

  Future<void> _buzz() async {
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  }

  void _onEvent(TripEvent event) {
    if (!mounted) return;
    if (event == TripEvent.endedFromNotification) {
      Navigator.of(context).maybePop();
      return;
    }
    final t = AppLocalizations.of(context);
    final dest = c.city.station(c.plan.stops.last.stationId).name.of(langOf(context));
    _buzz();
    if (event == TripEvent.approaching) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('${t.approachingTitle(dest)}\n${t.approachingBody}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.snapshot;
        final plan = c.plan;
        final city = c.city;
        final cur = city.station(plan.stops[s.currentIndex].stationId);
        final next = s.nextIndex == null ? null : city.station(plan.stops[s.nextIndex!].stationId);
        final line = city.line(plan.lineAt(s.currentIndex));
        final forward = plan.route.legs.firstWhere((l) => l.lineId == line.id).forward;
        final hm = DateFormat.Hm();

        return Scaffold(
          body: PixelBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Row(
                    children: [
                      PixelButton(
                        color: PixelColors.card,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        onPressed: () => Navigator.pop(context),
                        child: PixelText('×', size: 22),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: PixelBox(
                          color: line.color,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: PixelText(
                            '${line.name.of(lang)} ${line.directionName(forward).of(lang)}',
                            size: 18,
                            color: PixelColors.card,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PixelBox(
                    color: PixelColors.ink,
                    padding: EdgeInsets.zero,
                    child: SideTrainView(
                      underground: sideTrainUnderground(plan, s),
                      moving: !s.atStation && !s.arrived,
                      lineColor: line.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _GpsChip(state: c.gpsState),
                  ),
                  const SizedBox(height: 20),
                  if (s.arrived)
                    _ArrivedCard(
                      stationName: cur.name.of(langOf(context)),
                      reward: c.reward,
                      city: city,
                      fromId: c.plan.stops.first.stationId,
                      toId: c.plan.stops.last.stationId,
                    )
                  else ...[
                    PixelText(t.nowLabel, size: 16, color: PixelColors.muted),
                    if (s.atStation)
                      StationName(station: cur, size: 26)
                    else
                      PixelText(t.betweenStations(cur.name.ja, next!.name.ja), size: 26),
                    const SizedBox(height: 20),
                    PixelText(t.nextLabel, size: 20, color: line.color),
                    StationName(station: next!, size: 48),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(label: t.remainingLabel, value: t.stopCount(s.remainingStops)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Stat(label: t.etaLabel, value: hm.format(_japanClock(s.eta))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  ProgressTrack(
                    plan: plan,
                    progress: s.progress,
                    moving: !s.atStation && !s.arrived,
                    lineColorOf: (id) => city.line(id).color,
                  ),
                  const SizedBox(height: 8),
                  PixelText(t.estimateNote, size: 13, color: PixelColors.muted),
                  const SizedBox(height: 20),
                  PixelBox(
                    child: Column(
                      children: [
                        for (var i = s.currentIndex; i < plan.stops.length; i++)
                          _StopRow(
                            time: hm.format(
                              _japanClock(
                                DateTime.now().add(Duration(seconds: plan.stops[i].arriveSec - s.elapsedSec)),
                              ),
                            ),
                            name: city.station(plan.stops[i].stationId).name.ja,
                            sub: lang == 'ja' ? '' : city.station(plan.stops[i].stationId).name.of(lang),
                            color: city.line(plan.stops[i].lineId).color,
                            isCurrent: i == s.currentIndex,
                            isLast: i == plan.lastIndex,
                            transferNote: plan.stops[i].transferToLineId == null
                                ? null
                                : plan.stops[i].through
                                ? t.throughHere(city.line(plan.stops[i].transferToLineId!).name.of(lang))
                                : plan.stops[i].walkToStationId != null
                                ? t.transferWalkTo(
                                    city.station(plan.stops[i].walkToStationId!).name.of(lang),
                                    city.line(plan.stops[i].transferToLineId!).name.of(lang),
                                  )
                                : t.transferHere(city.line(plan.stops[i].transferToLineId!).name.of(lang)),
                          ),
                      ],
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    PixelText(t.testSpeed, size: 14, color: PixelColors.muted),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final v in const [1.0, 10.0, 60.0])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: PixelButton(
                                expand: true,
                                color: c.speed == v ? PixelColors.accent : PixelColors.card,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                onPressed: () => c.setSpeed(v),
                                child: PixelText('×${v.toInt()}', size: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  PixelButton(
                    expand: true,
                    color: s.arrived ? PixelColors.accent : PixelColors.card,
                    onPressed: () => Navigator.pop(context),
                    child: PixelText(s.arrived ? t.backHome : t.endTrip, size: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GpsChip extends StatelessWidget {
  const _GpsChip({required this.state});
  final GpsState state;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (icon, text) = switch (state) {
      GpsState.corrected => (Icons.gps_fixed, t.gpsCorrected),
      GpsState.underground => (Icons.subway_outlined, t.gpsUnderground),
      GpsState.waiting => (Icons.schedule, t.gpsWaiting),
      GpsState.off => (Icons.location_off_outlined, t.gpsOff),
    };
    return PixelBox(
      color: PixelColors.soft,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: PixelColors.ink),
          const SizedBox(width: 6),
          PixelText(text, size: 14),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => PixelBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PixelText(label, size: 14, color: PixelColors.muted),
        const SizedBox(height: 4),
        PixelText(value, size: 30),
      ],
    ),
  );
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.time,
    required this.name,
    required this.sub,
    required this.color,
    required this.isCurrent,
    required this.isLast,
    this.transferNote,
  });

  final String time;
  final String name;
  final String sub;
  final Color color;
  final bool isCurrent;
  final bool isLast;
  final String? transferNote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 56, child: PixelText(time, size: 15, color: PixelColors.muted)),
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 12),
            child: PixelSquare(color: color, size: 14, hollow: !isCurrent),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText(sub.isEmpty || sub == name ? name : '$name  $sub', size: isCurrent || isLast ? 20 : 17),
                if (transferNote != null) PixelText(transferNote!, size: 13, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _stickerLabel = LocalizedText({
  'ja': '乗った駅・降りた駅にステッカー',
  'ko': '탄 역·내린 역에 스티커 붙이기',
  'en': 'Sticker where you got on and off',
});

class _ArrivedCard extends StatelessWidget {
  const _ArrivedCard({
    required this.stationName,
    required this.city,
    required this.fromId,
    required this.toId,
    this.reward,
  });
  final String stationName;
  final String fromId;
  final String toId;
  final CityData city;
  final TripReward? reward;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PixelBox(
      color: PixelColors.celebrate,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelText(t.arrivedTitle, size: 32),
          const SizedBox(height: 8),
          PixelText(t.arrivedBody(stationName), size: 17),
          if (reward != null && reward!.total > 0) ...[
            const SizedBox(height: 10),
            PixelText(t.myCoinsEarned(reward!.total), size: 22, bold: true, color: const Color(0xFFB7791F)),
          ],
          if (reward != null && reward!.stamped.isNotEmpty) ...[
            PixelText(t.arrivedStamps(reward!.stamped.length), size: 17, color: const Color(0xFFB7791F)),
            const SizedBox(height: 10),
            StampSlam(
              stamps: [
                for (final id in reward!.stamped)
                  (name: city.station(id).name.of('ja'), color: city.line(city.station(id).lines.first).color),
              ],
            ),
          ],
          for (final id in reward?.completedLines ?? const <String>[])
            if (Services.my.rewardFor(id) case final item?)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: PixelText(
                  t.arrivedLineDone(city.line(id).name.of(langOf(context)), item.name.of(langOf(context))),
                  size: 17,
                  color: const Color(0xFFB7791F),
                ),
              ),
          const SizedBox(height: 12),
          // Stick a sticker on where you got on and off: it shows on the route map.
          GestureDetector(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              backgroundColor: PixelColors.card,
              builder: (_) => StickerMarkSheet(city: city, stationIds: [fromId, toId]),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: PixelColors.card, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/art/stickers/sakura.png',
                    width: 22,
                    height: 22,
                    filterQuality: FilterQuality.none,
                  ),
                  const SizedBox(width: 8),
                  PixelText(_stickerLabel.of(langOf(context)), size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clock times are shown in Japan time, whatever time zone the phone is in.
DateTime _japanClock(DateTime t) => t.toUtc().add(const Duration(hours: 9));
