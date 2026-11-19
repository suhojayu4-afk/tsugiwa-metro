import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../data/models/city.dart';
import '../../data/models/rail_line.dart';
import '../../data/models/timetable.dart';
import '../../l10n/app_localizations.dart';
import '../route_map/map_trains.dart';

/// One train leaving a station: which line and way, when (seconds since
/// 04:00, the start of the service day in Japan) and where it is bound.
class Departure {
  const Departure({required this.line, required this.forward, required this.sec, required this.terminusId});
  final RailLine line;
  final bool forward;
  final int sec;

  /// Last station that way (null on a loop line: the direction name is shown).
  final String? terminusId;

  /// 「12:03」.
  String get clock => LineTimetable.clock(240 + sec ~/ 60);
}

/// The next trains from [stationId] after [now], soonest first, estimated
/// from the timetables exactly as the route map's running trains are (same
/// spacing, run times, stops and first / last trains).
List<Departure> nextDepartures(CityData city, String stationId, DateTime now, {int count = 4, int perWay = 2}) {
  final jst = now.toUtc().add(const Duration(hours: 9));
  final sec = (LineTimetable.serviceMinute(jst) - 240) * 60 + jst.second;
  final out = <Departure>[];
  for (final lineId in city.station(stationId).lines) {
    final line = city.line(lineId);
    final i = line.stations.indexOf(stationId);
    if (i < 0) continue;
    final tt = city.timetables[line.id];
    if (tt != null && !tt.inService(jst)) continue;
    final head = (tt?.headwayMinAt(jst) ?? 6) * 60;
    final first = tt == null ? -1 << 30 : (tt.firstTrainMin - 240) * 60;
    final last = tt == null ? 1 << 30 : (tt.lastTrainMin - 240) * 60;
    // Arrive / leave times along the line, as in TrainSim.
    final arrive = <int>[0], depart = <int>[0];
    var t = 0;
    for (var k = 0; k < line.segmentCount; k++) {
      t += math.max(30, line.runSec[k]);
      arrive.add(t);
      final end = k == line.segmentCount - 1;
      if (!end || line.loop) t += line.dwellSec;
      depart.add(t);
    }
    final total = t;
    final n = line.stations.length;
    for (final forward in const [true, false]) {
      if (!line.loop && (forward ? i == n - 1 : i == 0)) continue; // the end of the line
      final offset = (trainPhase(line.id) + (forward ? 0 : reversePhase)) % head;
      // When a train leaves this station, counted from leaving its first station.
      final at = forward ? depart[i] : total - arrive[i];
      final double base, period;
      if (line.loop) {
        final trains = math.max(1, (total / head).round());
        period = total / trains;
        base = (forward ? depart[i] : total - arrive[i]) - offset.toDouble();
      } else {
        period = head.toDouble();
        base = (offset + at).toDouble();
      }
      var x = base + ((sec - base) / period).ceil() * period;
      var found = 0;
      for (var guard = 0; found < perWay && guard < 40; guard++, x += period) {
        if (!line.loop) {
          final leftEnd = x.round() - at;
          if (leftEnd < first) continue;
          if (leftEnd > last) break;
        }
        out.add(
          Departure(
            line: line,
            forward: forward,
            sec: x.round(),
            terminusId: line.loop ? null : (forward ? line.stations.last : line.stations.first),
          ),
        );
        found++;
      }
    }
  }
  out.sort((a, b) => a.sec - b.sec);
  return out.take(count).toList();
}

/// 発車標: the next trains from the start station, in orange LEDs on a dark
/// board like the ones over Japanese platforms. A train about to leave
/// blinks 「まもなく」; a note scrolls along the bottom (times are estimates).
class DepartureBoard extends StatefulWidget {
  const DepartureBoard({super.key, required this.city, required this.stationId});
  final CityData city;

  /// Start station; null shows a hint to pick one.
  final String? stationId;

  @override
  State<DepartureBoard> createState() => _DepartureBoardState();
}

class _DepartureBoardState extends State<DepartureBoard> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    // Twice a second: the clock, the blinking 「まもなく」 and the ticker.
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && TickerMode.valuesOf(context).enabled) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const _led = Color(0xFFFFA43A);
  static const _green = Color(0xFF7CF08C);
  static const _board = Color(0xFF141318);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final city = widget.city;
    final id = widget.stationId;
    final now = DateTime.now();
    final jst = now.toUtc().add(const Duration(hours: 9));
    final clock =
        '${jst.hour.toString().padLeft(2, '0')}${_tick.isEven ? ':' : ' '}${jst.minute.toString().padLeft(2, '0')}';
    final rows = id == null ? const <Departure>[] : nextDepartures(city, id, now);
    final nowSec = (LineTimetable.serviceMinute(jst) - 240) * 60 + jst.second;
    final note = id == null ? t.boardPickStation : (rows.isEmpty ? t.boardEnded : t.boardNote);
    return Semantics(
      label: id == null ? note : '${city.station(id).name.of(lang)} ${t.boardTitle}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: _board,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3A3842), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(width: 4, height: 14, color: _led),
                const SizedBox(width: 6),
                Expanded(
                  child: PixelText(
                    id == null ? t.boardTitle : '${city.station(id).name.of(lang)}  ${t.boardTitle}',
                    size: 13,
                    color: const Color(0xFFE8E6EE),
                    maxLines: 1,
                  ),
                ),
                PixelText(clock, size: 15, color: _green, bold: true),
              ],
            ),
            const SizedBox(height: 6),
            // 「まもなく」 only on the first train, as on real boards.
            for (final (k, d) in rows.indexed) _row(d, t, lang, soon: k == 0 && d.sec - nowSec <= 60),
            if (rows.isEmpty) const SizedBox(height: 4),
            const SizedBox(height: 4),
            Container(height: 1, color: const Color(0xFF2E2C36)),
            const SizedBox(height: 4),
            SizedBox(
              height: 16,
              child: _Ticker(text: note, step: _tick, color: _led),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Departure d, AppLocalizations t, String lang, {required bool soon}) {
    final to = d.terminusId == null
        ? d.line.directionName(d.forward).of(lang)
        : t.boardBound(widget.city.station(d.terminusId!).name.of(lang));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 54, child: PixelText(d.clock, size: 17, color: _led, bold: true)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: d.line.color, borderRadius: BorderRadius.circular(4)),
            constraints: const BoxConstraints(maxWidth: 104),
            child: PixelText(d.line.name.of(lang), size: 11, color: PixelColors.card, maxLines: 1),
          ),
          const SizedBox(width: 8),
          Expanded(child: PixelText(to, size: 15, color: _led, maxLines: 1)),
          if (soon)
            Opacity(
              opacity: _tick.isEven ? 1 : 0.25,
              child: PixelText(t.boardSoon, size: 12, color: const Color(0xFFFFE066)),
            ),
        ],
      ),
    );
  }
}

/// The note running along the bottom of the board, right to left.
class _Ticker extends StatelessWidget {
  const _Ticker({required this.text, required this.step, required this.color});
  final String text;
  final int step;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: pixelStyle(size: 12, color: color),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final run = box.maxWidth + tp.width + 24;
      final x = box.maxWidth - (step * 9.0) % run;
      tp.dispose();
      return ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: x,
              top: 0,
              child: PixelText(text, size: 12, color: color, maxLines: 1),
            ),
          ],
        ),
      );
    },
  );
}
