import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../data/models/timetable.dart';
import '../../l10n/app_localizations.dart';
import '../trip/route_finder.dart';

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
    final now = DateTime.now();

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
        if (live != null) {
          main = t.nextTrainIn(live);
        } else if (tt != null && !tt.inService(now)) {
          main = t.outOfService(LineTimetable.clock(tt.firstTrainMin));
        } else {
          main = t.trainsEvery(tt?.headwayMinAt(now) ?? 5);
          if (tt != null) {
            sub = t.lastTrainAbout(LineTimetable.clock(tt.lastTrainMin));
          }
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
                      live != null ? t.liveBadge : t.estimateBadge,
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
              PixelText(main, size: 22),
              if (sub != null) PixelText(sub, size: 13, color: PixelColors.muted),
            ],
          ),
        );
      },
    );
  }
}
