import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/japan_time.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../data/models/timetable.dart';
import '../../data/models/train_run.dart';
import '../../l10n/app_localizations.dart';
import 'train_text.dart';

/// One real train, stop by stop: its times, how late it runs and where it
/// is now (JR西日本's 走行位置 when known, otherwise from the timetable).
Future<void> showTrainSheet(BuildContext context, CityData city, String lineId, TrainRun run) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PixelColors.card,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scroll) => ListenableBuilder(
          listenable: Services.jrwest,
          builder: (context, _) => TrainSheet(city: city, lineId: lineId, run: run, scroll: scroll),
        ),
      ),
    );

/// Where [run] is at [minute] (service-day minutes, delay already added):
/// (index of the stop it is at or last left, standing there).
({int index, bool standing})? trainPosition(TrainRun run, double minute) {
  final st = run.stops;
  if (minute < st.first.departMin - 1 || minute > st.last.arriveMin + 1) return null;
  for (var i = st.length - 1; i >= 0; i--) {
    if (minute >= st[i].arriveMin) return (index: i, standing: minute <= st[i].departMin || i == st.length - 1);
  }
  return (index: 0, standing: true);
}

class TrainSheet extends StatelessWidget {
  const TrainSheet({super.key, required this.city, required this.lineId, required this.run, this.scroll});
  final CityData city;
  final String lineId;
  final TrainRun run;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final line = city.line(lineId);
    final live = Services.jrwest.trains[run.no];
    final delay = live?.delayMin ?? 0;
    final jst = japanNow();
    final minute = LineTimetable.serviceMinute(jst) + jst.second / 60 - delay;
    // Live position by station name, else the timetable's.
    int? at;
    var standing = false;
    if (live != null) {
      final i = run.stops.indexWhere((s) => city.station(s.stationId).name.ja == live.at);
      if (i >= 0) {
        at = i;
        standing = live.next == null;
      }
    }
    if (at == null) {
      final p = trainPosition(run, minute);
      at = p?.index;
      standing = p?.standing ?? false;
    }
    String name(String id) => city.station(id).name.of(lang);
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Row(
          children: [
            PixelSquare(color: line.color, size: 16),
            const SizedBox(width: 8),
            Expanded(child: PixelText(line.name.of(lang), size: 14, color: PixelColors.muted, maxLines: 1)),
            PixelText(t.trainNo(run.no), size: 12, color: PixelColors.muted),
          ],
        ),
        const SizedBox(height: 4),
        PixelText(t.trainAt(trainKindText(run, lang), trainToText(city, run, lang)), size: 22),
        if (live != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: delay > 0 ? PixelColors.danger : const Color(0xFF3FA66B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: PixelText(delay > 0 ? t.delayMin(delay) : t.onTime, size: 13, color: PixelColors.card),
            ),
          ),
        ],
        const SizedBox(height: 14),
        for (final (i, s) in run.stops.indexed) ...[
          _StopLine(
            time: LineTimetable.clock(i == 0 ? s.departMin : s.arriveMin),
            late: delay > 0 && i >= (at ?? 0)
                ? LineTimetable.clock((i == 0 ? s.departMin : s.arriveMin) + delay)
                : null,
            name: name(s.stationId),
            color: line.color,
            here: at == i && standing,
            passed: at != null && i < at || (at == i && !standing),
          ),
          // Running between this stop and the next.
          if (at == i && !standing && i < run.stops.length - 1) _Running(color: line.color),
        ],
        const SizedBox(height: 10),
        PixelText(live != null ? t.positionLive : t.positionPlan, size: 12, color: PixelColors.muted),
      ],
    );
  }
}

class _StopLine extends StatelessWidget {
  const _StopLine({
    required this.time,
    required this.late,
    required this.name,
    required this.color,
    required this.here,
    required this.passed,
  });
  final String time;
  final String? late;
  final String name;
  final Color color;
  final bool here;
  final bool passed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(width: 52, child: PixelText(time, size: 15, color: passed ? PixelColors.muted : PixelColors.ink)),
        SizedBox(width: 52, child: late == null ? null : PixelText(late!, size: 13, color: PixelColors.danger)),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: here ? color : (passed ? color.withValues(alpha: 0.35) : PixelColors.card),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PixelText(name, size: 16, color: passed && !here ? PixelColors.muted : PixelColors.ink, maxLines: 1),
        ),
        if (here) Icon(Icons.train_rounded, color: color, size: 20),
      ],
    ),
  );
}

class _Running extends StatelessWidget {
  const _Running({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 108),
    child: Row(
      children: [
        Icon(Icons.arrow_downward_rounded, color: color, size: 16),
        const SizedBox(width: 6),
        Icon(Icons.train_rounded, color: color, size: 20),
      ],
    ),
  );
}
