import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/congestion/congestion_source.dart';
import '../../data/congestion/estimate_congestion.dart';

import '../../app.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../data/models/timetable.dart';
import '../../data/last_train_alarm.dart';
import '../../data/night_options.dart';
import '../../data/route_store.dart';
import '../../l10n/app_localizations.dart';
import '../trip/route_finder.dart';
import '../trip/trip_plan.dart';

const _green = Color(0xFF2E9447);

IconData favouriteIcon(FavouriteKind k) => switch (k) {
  FavouriteKind.work => Icons.work_rounded,
  FavouriteKind.home => Icons.home_rounded,
  FavouriteKind.other => Icons.star_rounded,
};

String favouriteLabel(AppLocalizations t, FavouriteKind k) => switch (k) {
  FavouriteKind.work => t.favWork,
  FavouriteKind.home => t.favHome,
  FavouriteKind.other => t.favOther,
};

/// The card between the weather and the route panel. Before a route is
/// chosen it offers saved and recent routes (one tap fills both stations);
/// once a route is chosen it shows when the next train comes, with a star
/// to save the route.
class ContextCard extends StatelessWidget {
  const ContextCard({
    super.key,
    required this.city,
    required this.route,
    required this.fromId,
    required this.toId,
    required this.store,
    required this.onPick,
    required this.onToggleFavourite,
    required this.onRemoveFavourite,
    this.alarmOn = false,
    this.onBell,
    this.firstAlarmOn = false,
    this.onFirstBell,
    this.onUseAlt,
  });

  final CityData city;
  final RouteResult? route;
  final String? fromId;
  final String? toId;
  final RouteStore store;
  final ValueChanged<SavedRoute> onPick;
  final VoidCallback onToggleFavourite;
  final ValueChanged<SavedRoute> onRemoveFavourite;

  /// 終電アラーム for this route; [onBell] null hides the bell.
  final bool alarmOn;
  final VoidCallback? onBell;

  /// 始発アラーム, shown when the trains have stopped.
  final bool firstAlarmOn;
  final VoidCallback? onFirstBell;

  /// 「このルートにする」: ride the other way that still works tonight,
  /// avoiding these lines.
  final ValueChanged<Set<String>>? onUseAlt;

  @override
  Widget build(BuildContext context) {
    final r = route;
    final isFavourite = fromId != null && toId != null && store.favouriteFor(fromId!, toId!) != null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: r == null
          ? _QuickRoutes(
              key: const ValueKey('quick'),
              city: city,
              favourites: store.favourites,
              recents: store.recents,
              onPick: onPick,
              onRemove: onRemoveFavourite,
            )
          : _NextTrain(
              key: ValueKey(r),
              city: city,
              route: r,
              favourite: isFavourite,
              onStar: onToggleFavourite,
              alarmOn: alarmOn,
              onBell: onBell,
              firstAlarmOn: firstAlarmOn,
              onFirstBell: onFirstBell,
              onUseAlt: onUseAlt,
            ),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: PixelColors.card,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: PixelColors.line),
);

class _QuickRoutes extends StatelessWidget {
  const _QuickRoutes({
    super.key,
    required this.city,
    required this.favourites,
    required this.recents,
    required this.onPick,
    required this.onRemove,
  });

  final CityData city;
  final List<SavedRoute> favourites;
  final List<SavedRoute> recents;
  final ValueChanged<SavedRoute> onPick;
  final ValueChanged<SavedRoute> onRemove;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    String name(String id) => city.station(id).name.ja;
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF2B33D)),
              const SizedBox(width: 4),
              PixelText(t.quickRoutes, size: 13, color: PixelColors.muted),
            ],
          ),
          const SizedBox(height: 8),
          if (favourites.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: PixelColors.background, borderRadius: BorderRadius.circular(12)),
              child: PixelText(t.favHint, size: 13, color: PixelColors.muted, maxLines: 2),
            )
          else
            SizedBox(
              height: 48,
              child: LayoutBuilder(
                builder: (context, box) {
                  // Two chips fill the row; more scroll sideways.
                  final w = favourites.length == 1 ? box.maxWidth : (box.maxWidth - 8) / 2;
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: favourites.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = favourites[i];
                      return SizedBox(
                        width: w,
                        child: _FavouriteChip(
                          icon: favouriteIcon(f.kind),
                          label: favouriteLabel(t, f.kind),
                          detail: '${name(f.fromId)} → ${name(f.toId)}',
                          onTap: () => onPick(f),
                          onLongPress: () => onRemove(f),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          if (recents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 15, color: PixelColors.muted),
                const SizedBox(width: 4),
                PixelText(t.recentRoutes, size: 12, color: PixelColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final r in recents)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => onPick(r),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: PixelColors.background,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: PixelText('${name(r.fromId)} → ${name(r.toId)}', size: 13),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FavouriteChip extends StatelessWidget {
  const _FavouriteChip({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    required this.onLongPress,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    onLongPress: onLongPress,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: const Color(0xFFEFF7F1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(color: PixelColors.card, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: _green),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText(label, size: 16, maxLines: 1),
                PixelText(detail, size: 11, color: PixelColors.muted, maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Next train on the first leg: line colour, direction, interval (or the
/// live minutes when a RealtimeProvider has them) and the trip summary.
class _NextTrain extends StatelessWidget {
  const _NextTrain({
    super.key,
    required this.city,
    required this.route,
    required this.favourite,
    required this.onStar,
    this.alarmOn = false,
    this.onBell,
    this.firstAlarmOn = false,
    this.onFirstBell,
    this.onUseAlt,
  });

  final CityData city;
  final RouteResult route;
  final bool favourite;
  final VoidCallback onStar;
  final bool alarmOn;
  final VoidCallback? onBell;
  final bool firstAlarmOn;
  final VoidCallback? onFirstBell;
  final ValueChanged<Set<String>>? onUseAlt;

  /// A last train on this route has gone: say so, then offer another way
  /// that still works tonight, or (none left) the first train and the ways
  /// home without trains.
  List<Widget> _missed(AppLocalizations t, String lang, LineTimetable? tt, DateTime jst, int nowMin) {
    final from = route.legs.first.stationIds.first, to = route.legs.last.stationIds.last;
    final alt = stillPossible(city, from, to, nowMin);
    final via = alt == null ? '' : {for (final l in alt.route.legs) city.line(l.lineId).name.of(lang)}.join(' → ');
    return [
      const SizedBox(height: 6),
      Row(
        children: [
          const Icon(Icons.do_not_disturb_on_rounded, size: 15, color: PixelColors.danger),
          const SizedBox(width: 4),
          Expanded(child: PixelText(t.routeMissed, size: 13, color: PixelColors.danger, maxLines: 1)),
        ],
      ),
      if (alt != null) ...[
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          decoration: BoxDecoration(color: const Color(0xFFEFF7F1), borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PixelText(t.altRouteTitle, size: 14, color: _green, bold: true, maxLines: 1),
              const SizedBox(height: 2),
              PixelText(t.altRouteInfo(LineTimetable.clock(alt.lastDep), via), size: 12, color: PixelColors.muted),
              if (onUseAlt != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => onUseAlt!(alt.avoid),
                    icon: const Icon(Icons.alt_route_rounded, size: 18, color: _green),
                    label: PixelText(t.altRouteUse, size: 13, color: _green),
                  ),
                ),
            ],
          ),
        ),
      ] else if (tt != null)
        ..._noTrains(t, tt, jst),
    ];
  }

  /// No trains now: when the first one comes (with its alarm) and the ways
  /// home without trains — a rough taxi fare and, if not too far, walking.
  List<Widget> _noTrains(AppLocalizations t, LineTimetable tt, DateTime jst) {
    final toFirst = tt.minutesToFirstTrain(jst);
    final from = route.legs.first.stationIds.first, to = route.legs.last.stationIds.last;
    final metres = roadMetres(city, from, to);
    final walk = walkMinutes(metres);
    final fare = NumberFormat.decimalPattern('ja').format(taxiFareYen(metres, lateNight: isLateNight(jst)));
    return [
      if (toFirst != null) ...[
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.wb_twilight_rounded, size: 16, color: _green),
            const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PixelText(
                  t.firstTrainIn(toFirst ~/ 60, toFirst % 60, LineTimetable.clock(tt.firstTrainMin)),
                  size: 14,
                  color: _green,
                  maxLines: 1,
                ),
              ),
            ),
            if (onFirstBell != null)
              Semantics(
                button: true,
                label: t.firstTrainAlarm,
                selected: firstAlarmOn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onFirstBell,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Icon(
                      firstAlarmOn ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                      size: 22,
                      color: firstAlarmOn ? _green : PixelColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
      const SizedBox(height: 4),
      PixelText(t.nightWays, size: 11, color: PixelColors.muted),
      const SizedBox(height: 2),
      Wrap(
        spacing: 12,
        runSpacing: 2,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_taxi_rounded, size: 16, color: Color(0xFFB58A12)),
              const SizedBox(width: 3),
              PixelText(isLateNight(jst) ? t.taxiFareNight(fare) : t.taxiFare(fare), size: 13),
            ],
          ),
          if (walk <= maxWalkMinutes)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_walk_rounded, size: 16, color: PixelColors.muted),
                const SizedBox(width: 3),
                PixelText(t.walkTime(walk), size: 13),
              ],
            ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final leg = route.legs.first;
    final line = city.line(leg.lineId);
    final tt = city.timetables[leg.lineId];
    final now = DateTime.now();
    final plan = TripPlan.build(city, route, now);
    final minutes = (plan.totalSec / 60).ceil();

    return FutureBuilder<int?>(
      future: Services.realtime.nextTrainMinutes(
        stationId: leg.stationIds.first,
        lineId: leg.lineId,
        forward: leg.forward,
      ),
      builder: (context, snap) {
        final live = snap.data;
        final String main;
        final extra = <String>[];
        // Japan time: last trains and rush hours are Tokyo's.
        final jst = now.toUtc().add(const Duration(hours: 9));
        final toLast = tt?.minutesToLastTrain(jst);
        // Every last train on the way, not just the first line's.
        final nowMin = LineTimetable.serviceMinute(jst);
        final missed = missedLines(city, route, nowMin);
        final ended = tt != null && tt.endedFor(jst);
        if (live != null) {
          main = t.nextTrainIn(live);
        } else if (tt != null && !tt.inService(jst)) {
          main = ended
              // The first train has its own line below.
              ? t.serviceEndedShort
              : t.outOfService(LineTimetable.clock(tt.firstTrainMin));
        } else {
          main = t.trainsEvery(tt?.headwayMinAt(now) ?? 5);
          if (tt != null) {
            extra.add(t.lastTrainAbout(LineTimetable.clock(tt.lastTrainMin)));
          }
        }
        extra.add(t.routeSummary(minutes, route.stopCount, route.transferCount));

        return Container(
          decoration: _cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: line.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            PixelText(t.nextTrainTitle, size: 12, color: PixelColors.muted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: PixelText(
                                '${line.name.of(lang)} ${line.directionName(leg.forward).of(lang)}',
                                size: 12,
                                maxLines: 1,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: live != null ? _green : PixelColors.background,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: PixelText(
                                live != null ? t.liveBadge : t.estimateBadge,
                                size: 11,
                                color: live != null ? PixelColors.card : PixelColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        PixelText(main, size: ended ? 18 : 24, bold: live != null, maxLines: 1),
                        // Last train within the hour: in red, it matters.
                        if (toLast != null && toLast <= 60)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 15, color: PixelColors.danger),
                                const SizedBox(width: 4),
                                PixelText(t.lastTrainWarn(toLast), size: 14, color: PixelColors.danger),
                              ],
                            ),
                          ),
                        const SizedBox(height: 2),
                        PixelText(extra.join('  ·  '), size: 12, color: PixelColors.muted, maxLines: 1),
                        if (missed.isNotEmpty)
                          ..._missed(t, lang, tt, jst, nowMin)
                        else if (tt == null || tt.inService(jst)) ...[
                          const SizedBox(height: 6),
                          CrowdChip(level: EstimateCongestionSource.levelAt(leg.lineId, jst)),
                        ] else
                          ..._noTrains(t, tt, jst),
                      ],
                    ),
                  ),
                ),
                if (onBell != null)
                  Semantics(
                    button: true,
                    label: t.lastTrainAlarm,
                    selected: alarmOn,
                    child: Tooltip(
                      message: t.lastTrainAlarm,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onBell,
                        child: SizedBox(
                          width: 40,
                          child: Icon(
                            alarmOn ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                            size: 26,
                            color: alarmOn ? PixelColors.danger : PixelColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                Semantics(
                  button: true,
                  label: t.favOther,
                  selected: favourite,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onStar,
                    child: SizedBox(
                      width: 48,
                      child: Icon(
                        favourite ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 28,
                        color: favourite ? const Color(0xFFF2B33D) : PixelColors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Crowding estimate: 1–4 little people plus a word, so it reads without colour.
class CrowdChip extends StatelessWidget {
  const CrowdChip({super.key, required this.level});
  final CongestionLevel level;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (label, color) = switch (level) {
      CongestionLevel.relaxed => (t.crowdRelaxed, const Color(0xFF2E9447)),
      CongestionLevel.normal => (t.crowdNormal, const Color(0xFFB58A12)),
      CongestionLevel.crowded => (t.crowdCrowded, const Color(0xFFE07B22)),
      CongestionLevel.packed => (t.crowdPacked, PixelColors.danger),
    };
    return Row(
      children: [
        PixelText(t.crowdTitle, size: 12, color: PixelColors.muted),
        const SizedBox(width: 6),
        for (var i = 0; i < 4; i++)
          Icon(Icons.person_rounded, size: 15, color: i <= level.index ? color : PixelColors.line),
        const SizedBox(width: 4),
        PixelText(label, size: 13, color: color),
      ],
    );
  }
}
