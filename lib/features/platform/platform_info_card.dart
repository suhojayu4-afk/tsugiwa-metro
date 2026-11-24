import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/japan_time.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/last_train_alarm.dart';
import '../../data/models/city.dart';
import '../../data/models/timetable.dart';
import '../../l10n/app_localizations.dart';
import '../trip/route_finder.dart';
import '../trip/train_sheet.dart';
import '../trip/train_text.dart';

/// "のりば情報": when the next train comes on the first leg of the route.
/// Uses live data when a RealtimeProvider has it; otherwise the timetable
/// interval ("約3分おき"), clearly marked as 予想.
class PlatformInfoCard extends StatelessWidget {
  const PlatformInfoCard({super.key, required this.city, required this.route});
  final CityData city;
  final RouteResult route;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final leg = route.legs.first;
    final line = city.line(leg.lineId);
    final tt = city.timetables[leg.lineId];
    // Japan time, also on a phone set to another time zone.
    final now = japanNow();
    final lastDep = lastDepartureMin(city, route);

    return FutureBuilder<int?>(
      future: Services.realtime.nextTrainMinutes(
        stationId: leg.stationIds.first,
        lineId: leg.lineId,
        forward: leg.forward,
      ),
      builder: (context, snap) {
        final live = snap.data;
        final String main;
        String? sub;
        // Real trains (Tottori): the actual next departures.
        final real = live != null
            ? const []
            : realDepartures(city, leg.lineId, leg.stationIds.first, leg.stationIds.last, now);
        if (live != null) {
          main = t.nextTrainIn(live);
        } else if (real.isNotEmpty) {
          final d = real.first;
          main = t.departsIn(LineTimetable.clock(d.departMin), d.departMin - LineTimetable.serviceMinute(now));
          final late = Services.jrwest.delayOf(d.run.no);
          sub = [
            trainText(t, city, d, lang),
            if (late > 0) t.delayMin(late),
            if (real.length > 1) t.thenTrain(LineTimetable.clock(real[1].departMin)),
          ].join('  ·  ');
        } else if (tt != null && !tt.inService(now)) {
          main = t.outOfService(LineTimetable.clock(tt.firstTrainMin));
        } else {
          main = t.trainsEvery(tt?.headwayMinAt(now) ?? 5);
          if (lastDep != null) sub = t.lastTrainAbout(LineTimetable.clock(lastDep));
        }
        return PixelBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PixelText(t.platformInfo, size: 15, color: PixelColors.muted),
                  const Spacer(),
                  PixelBox(
                    color: live != null ? PixelColors.title : PixelColors.soft,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    child: PixelText(
                      live != null
                          ? t.liveBadge
                          : real.isNotEmpty
                          ? t.timetableBadge
                          : t.estimateBadge,
                      size: 12,
                      color: live != null ? PixelColors.card : PixelColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  PixelSquare(color: line.color, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PixelText('${line.name.of(lang)} ${line.directionName(leg.forward).of(lang)}', size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (real.isNotEmpty)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showTrainSheet(context, city, leg.lineId, real.first.run),
                  child: Row(
                    children: [
                      Expanded(child: PixelText(main, size: 22)),
                      const Icon(Icons.chevron_right_rounded, color: PixelColors.muted),
                    ],
                  ),
                )
              else
                PixelText(main, size: 22),
              if (sub != null) PixelText(sub, size: 13, color: PixelColors.muted),
            ],
          ),
        );
      },
    );
  }
}
