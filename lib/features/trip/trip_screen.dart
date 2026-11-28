import '../settings/app_look.dart';
import '../../core/localized_text.dart';
import '../my_room/sticker_mark_sheet.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/japan_time.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../data/models/timetable.dart';
import '../../data/my_store.dart';
import '../../l10n/app_localizations.dart';
import '../common/station_name.dart';
import 'train_sheet.dart';
import 'train_text.dart';
import 'trip_controller.dart';
import 'widgets/layered_train_view.dart';
import 'widgets/progress_track.dart';
import 'widgets/trip_props.dart';
import 'widgets/side_train_view.dart';
import 'widgets/first_visit_welcome.dart';
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

  /// The first-visit welcome has been shown (once a trip).
  bool _welcomed = false;

  @override
  void initState() {
    super.initState();
    _sub = c.events.listen(_onEvent);
    c.addListener(_maybeWelcome);
    c.start();
    // The phone turning dark at dusk must not rebuild the app in mid-ride.
    AppLook.hold();
  }

  /// Arrived at a station never reached before: its welcome, once the coins
  /// and stamps (and the postcard) are in.
  void _maybeWelcome() {
    final reward = c.reward;
    if (_welcomed || reward == null || !mounted) return;
    final dest = c.plan.stops.last.stationId;
    if (!reward.stamped.contains(dest)) return;
    _welcomed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showFirstVisitWelcome(context, city: c.city, stationId: dest, lineId: c.plan.stops.last.lineId);
    });
  }

  @override
  void dispose() {
    AppLook.release();
    c.removeListener(_maybeWelcome);
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
                      // The line, and which way: two lines, so a long name is not cut.
                      Expanded(
                        child: PixelBox(
                          color: line.color,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PixelText(line.name.of(lang), size: 17, color: PixelColors.card, maxLines: 1),
                              PixelText(
                                line.directionName(forward).of(lang),
                                size: 13,
                                color: PixelColors.card,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // The train as a layered diorama: drag it to look around.
                  LayeredTrainView(
                    theme: sceneryFor(city.id, line.id, s.currentIndex),
                    electric: lineElectric(line.id),
                    underground: sideTrainUnderground(plan, s),
                    moving: !s.atStation && !s.arrived,
                    lineColor: line.color,
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
                    // Started away from the station: how far, and whether the train can be caught.
                    if (c.approaching) ...[_ToStationCard(controller: c), const SizedBox(height: 16)],
                    // Where the train is now, and the next stop: one card.
                    PixelBox(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!c.approaching) ...[
                            PixelText(t.nowLabel, size: 14, color: PixelColors.muted),
                            if (s.atStation)
                              StationName(station: cur, size: 26)
                            else
                              PixelText(t.betweenStations(cur.name.ja, next!.name.ja), size: 26),
                          ],
                          // Waiting for a real train (Tottori): when it leaves, which one.
                          if (plan.trainLeaving(s.currentIndex) case final train?
                              when s.atStation && !c.approaching) ...[
                            const SizedBox(height: 6),
                            if (plan.stops[s.currentIndex].departSec - s.elapsedSec >= 30)
                              PixelText(
                                t.departsIn(
                                  LineTimetable.clock(train.departMin),
                                  ((plan.stops[s.currentIndex].departSec - s.elapsedSec) / 60).ceil(),
                                ),
                                size: 20,
                                color: line.color,
                              ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => showTrainSheet(context, city, plan.lineAt(s.currentIndex), train.run),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: PixelText(
                                      trainText(t, city, train, lang),
                                      size: 14,
                                      color: PixelColors.muted,
                                    ),
                                  ),
                                  if (c.delayMin > 0) ...[
                                    const SizedBox(width: 8),
                                    PixelText(t.delayMin(c.delayMin), size: 14, color: PixelColors.danger),
                                  ],
                                  Icon(Icons.chevron_right_rounded, size: 18, color: PixelColors.muted),
                                ],
                              ),
                            ),
                          ],
                          // On board a late train: say so.
                          if (!s.atStation && c.delayMin > 0) ...[
                            const SizedBox(height: 4),
                            PixelText(t.delayMin(c.delayMin), size: 14, color: PixelColors.danger),
                          ],
                          if (!c.approaching)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(height: 2, color: PixelColors.soft),
                            ),
                          PixelText(t.nextLabel, size: 16, color: line.color),
                          StationName(station: next!, size: 44),
                          if (c.toNextM case final m?) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.near_me_rounded, size: 16, color: line.color),
                                const SizedBox(width: 6),
                                PixelText(t.toNextDistance(distanceText(m)), size: 16, color: PixelColors.muted),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
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
                  PixelText(plan.timetabled ? t.realTimesNote : t.estimateNote, size: 13, color: PixelColors.muted),
                  const SizedBox(height: 20),
                  PixelBox(
                    child: Column(
                      children: [
                        for (var i = s.currentIndex; i < plan.stops.length; i++)
                          _StopRow(
                            time: hm.format(
                              _japanClock(
                                DateTime.now().add(
                                  Duration(
                                    // Waiting here: when the train leaves.
                                    seconds:
                                        (i == s.currentIndex && s.atStation
                                            ? plan.stops[i].departSec
                                            : plan.stops[i].arriveSec) -
                                        s.elapsedSec,
                                  ),
                                ),
                              ),
                            ),
                            name: city.station(plan.stops[i].stationId).name.ja,
                            sub: lang == 'ja' ? '' : city.station(plan.stops[i].stationId).name.of(lang),
                            color: city.line(plan.stops[i].lineId).color,
                            nextColor: i < plan.lastIndex ? city.line(plan.lineAt(i)).color : null,
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

/// 350m, 1.2km.
String distanceText(double m) => m < 1000 ? '${(m / 10).round() * 10}m' : '${(m / 1000).toStringAsFixed(1)}km';

/// On the way to the first station, in three bands: how far (and the walk),
/// when the train leaves (and whether there is time), where to board.
class _ToStationCard extends StatelessWidget {
  const _ToStationCard({required this.controller});
  final TripController controller;

  static const _good = Color(0xFF3FA66B);

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final plan = c.plan;
    final city = c.city;
    final first = plan.stops.first;
    final line = city.line(plan.lineAt(0));
    final forward = plan.route.legs.first.forward;
    final train = plan.trainLeaving(0);
    final timed = train != null || first.departSec > 0;
    final walk = c.walkMin;
    final left = (c.departAt.difference(DateTime.now()).inSeconds / 60).floor() + c.delayMin;
    final spare = walk == null ? null : left - walk;
    final divider = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(height: 2, color: PixelColors.soft),
    );

    final Widget when;
    if (!timed) {
      when = PixelText(t.trainsEvery(city.timetables[line.id]?.headwayMinAt(japanNow()) ?? 5), size: 18);
    } else if (left < 0) {
      when = PixelText(t.toStationMissed, size: 15, color: PixelColors.danger);
    } else {
      final clock = DateFormat.Hm().format(_japanClock(c.departAt.add(Duration(minutes: c.delayMin))));
      when = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PixelText(t.departLabel, size: 13, color: PixelColors.muted),
              PixelText(clock, size: 30, color: line.color),
            ],
          ),
          const SizedBox(width: 14),
          Padding(padding: const EdgeInsets.only(bottom: 4), child: PixelText(t.minutesLater(left), size: 18)),
          const Spacer(),
          if (spare != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _Pill(
                text: spare >= 0 ? t.toStationSpare(spare) : t.toStationHurry,
                color: spare >= 2 ? _good : PixelColors.danger,
              ),
            ),
        ],
      );
    }

    return PixelBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // How far.
          Row(
            children: [
              Icon(Icons.directions_walk_rounded, color: line.color, size: 24),
              const SizedBox(width: 6),
              Expanded(
                child: PixelText(t.toStationTitle(city.station(first.stationId).name.of(lang)), size: 20, maxLines: 1),
              ),
              if (c.toStationM case final m?) PixelText(distanceText(m), size: 24),
            ],
          ),
          if (walk != null)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: PixelText(t.walkAbout(walk), size: 14, color: PixelColors.muted),
            ),
          divider,
          // When.
          when,
          divider,
          // Where to board, and which train.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 64, child: PixelText(t.boardLabel, size: 13, color: PixelColors.muted)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PixelSquare(color: line.color, size: 12),
                        const SizedBox(width: 6),
                        Expanded(child: PixelText(line.name.of(lang), size: 15, maxLines: 1)),
                      ],
                    ),
                    PixelText(line.directionName(forward).of(lang), size: 13, color: PixelColors.muted, maxLines: 1),
                    if (train != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => showTrainSheet(context, city, line.id, train.run),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Flexible(
                                child: PixelText(
                                  trainText(t, city, train, lang),
                                  size: 13,
                                  color: line.color,
                                  maxLines: 1,
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, size: 18, color: line.color),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PixelButton(
            expand: true,
            color: PixelColors.soft,
            padding: const EdgeInsets.symmetric(vertical: 8),
            onPressed: c.reachedStation,
            child: PixelText(t.toStationHere, size: 16),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
    child: PixelText(text, size: 13, color: PixelColors.card),
  );
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
        PixelText(value, size: 26, maxLines: 1),
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
    this.nextColor,
    this.transferNote,
  });

  final String time;
  final String name;
  final String sub;

  /// Line arriving here, and the one leaving (null at the last stop).
  final Color color;
  final Color? nextColor;
  final bool isCurrent;
  final bool isLast;
  final String? transferNote;

  static const _head = 38.0;
  static const _timeW = 52.0;
  static const _railW = 28.0;

  @override
  Widget build(BuildContext context) {
    final strong = isCurrent || isLast;
    final dot = strong ? 14.0 : 11.0;
    final railX = _timeW + _railW / 2 - 1.5;
    return Stack(
      children: [
        // The line through the stops: in from above, out below.
        if (!isCurrent)
          Positioned(
            left: railX,
            top: 0,
            height: _head / 2,
            width: 3,
            child: ColoredBox(color: color),
          ),
        if (nextColor != null)
          Positioned(
            left: railX,
            top: _head / 2,
            bottom: 0,
            width: 3,
            child: ColoredBox(color: nextColor!),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _head,
              child: Row(
                children: [
                  SizedBox(
                    width: _timeW,
                    child: PixelText(time, size: 15, color: strong ? PixelColors.ink : PixelColors.muted),
                  ),
                  SizedBox(
                    width: _railW,
                    child: Center(
                      child: Container(
                        width: dot,
                        height: dot,
                        decoration: BoxDecoration(
                          color: isCurrent ? color : PixelColors.card,
                          border: Border.all(color: isLast ? (nextColor ?? color) : color, width: 3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(child: PixelText(name, size: strong ? 19 : 16, maxLines: 1)),
                        if (sub.isNotEmpty && sub != name) ...[
                          const SizedBox(width: 8),
                          Flexible(child: PixelText(sub, size: 13, color: PixelColors.muted, maxLines: 1)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (transferNote != null)
              Padding(
                padding: const EdgeInsets.only(left: _timeW + _railW + 10, bottom: 8),
                child: PixelText(transferNote!, size: 13, color: nextColor ?? color),
              ),
          ],
        ),
      ],
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
            if (reward!.limited) PixelText(t.myCoinsLimited, size: 12, color: PixelColors.muted),
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
