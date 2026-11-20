import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/localized_text.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../data/car_guide.dart';
import '../../data/models/city.dart';

const _title = LocalizedText({'ja': '乗換便利号車', 'ko': '환승 편리 호차', 'en': 'Best car to ride'});
const _estimate = LocalizedText({'ja': '目安', 'ko': '참고', 'en': 'approx.'});
const _carDoor = LocalizedText({'ja': '{car}号車 {door}番ドア', 'ko': '{car}호차 {door}번 문', 'en': 'Car {car} · door {door}'});
const _carOnly = LocalizedText({'ja': '{car}号車', 'ko': '{car}호차', 'en': 'Car {car}'});
const _forLine = LocalizedText({
  'ja': '{station}で{line}へ乗り換えに便利',
  'ko': '{station}에서 {line} 환승에 편리',
  'en': 'Handy for {line} at {station}',
});
const _forExit = LocalizedText({
  'ja': '{station}で{exit}方面に便利',
  'ko': '{station}에서 {exit} 방면에 편리',
  'en': 'Handy for {exit} at {station}',
});
const _front = LocalizedText({'ja': '進行方向', 'ko': '진행 방향', 'en': 'front'});
const _source = LocalizedText({'ja': '出典', 'ko': '출처', 'en': 'Source'});
const _caveat = LocalizedText({
  'ja': '停車位置は変わることがあります。ホームの表示もご確認ください。',
  'ko': '정차 위치는 바뀔 수 있어요. 승강장 표시도 확인하세요.',
  'en': 'Stopping spots can change; check the platform signs.',
});

String _fill(String s, Map<String, Object> v) =>
    v.entries.fold(s, (acc, e) => acc.replaceAll('{${e.key}}', '${e.value}'));

/// 乗換便利号車: for each change of trains (and the final gate) the car and
/// door that stop nearest the stairs, drawn as a little pixel train.
/// Shows nothing when [advice] is empty.
class CarGuideCard extends StatelessWidget {
  const CarGuideCard({super.key, required this.city, required this.advice});
  final CityData city;
  final List<CarAdvice> advice;

  @override
  Widget build(BuildContext context) {
    if (advice.isEmpty) return const SizedBox.shrink();
    final lang = langOf(context);
    final hosts = {for (final a in advice) a.spot.sourceHost};
    return PixelBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PixelText(_title.of(lang), size: 15, color: PixelColors.muted),
              const Spacer(),
              PixelBox(
                color: PixelColors.soft,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                child: PixelText(_estimate.of(lang), size: 12, color: PixelColors.ink),
              ),
            ],
          ),
          for (final a in advice) ...[const SizedBox(height: 12), CarGuideRow(city: city, advice: a)],
          const SizedBox(height: 10),
          PixelText(_caveat.of(lang), size: 11, color: PixelColors.muted),
          PixelText('${_source.of(lang)}: ${hosts.join(', ')}', size: 11, color: PixelColors.muted),
        ],
      ),
    );
  }
}

/// One piece of advice: "3号車 2番ドア", what it is handy for, and the train.
class CarGuideRow extends StatelessWidget {
  const CarGuideRow({super.key, required this.city, required this.advice});
  final CityData city;
  final CarAdvice advice;

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    final spot = advice.spot;
    final station = city.stations[advice.stationId]?.name.of(lang) ?? advice.stationId;
    final what = spot.isExit
        ? _fill(
            // "スクランブルスクエア方面改札" already says 方面.
            spot.exitName!.contains('方面') ? _forExit.of(lang).replaceAll('{exit}方面', '{exit}') : _forExit.of(lang),
            {'station': station, 'exit': spot.exitName!},
          )
        : _fill(_forLine.of(lang), {'station': station, 'line': _lineName(spot.to, lang)});
    final carDoor = spot.door == null
        ? _fill(_carOnly.of(lang), {'car': spot.car})
        : _fill(_carDoor.of(lang), {'car': spot.car, 'door': spot.door!});
    final color = _lineColor(advice.lineId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PixelText(what, size: 13, color: PixelColors.muted, maxLines: 2),
        const SizedBox(height: 2),
        PixelText(carDoor, size: 20),
        const SizedBox(height: 6),
        CarTrain(layout: advice.layout, car: spot.car, door: spot.door, color: color, frontLabel: _front.of(lang)),
        if (spot.note != null) ...[
          const SizedBox(height: 4),
          PixelText(spot.note!.of(lang), size: 11, color: PixelColors.muted, maxLines: 2),
        ],
      ],
    );
  }

  String _lineName(String id, String lang) {
    try {
      return city.line(id).name.of(lang);
    } catch (_) {
      return id;
    }
  }

  Color _lineColor(String id) {
    try {
      return city.line(id).color;
    } catch (_) {
      return PixelColors.title;
    }
  }
}

/// The train seen from the platform: the front on the left (nose and a
/// "進行方向" arrow), one box per car with its number, the recommended car
/// filled in the line colour and its door marked with a pointer.
class CarTrain extends StatelessWidget {
  const CarTrain({
    super.key,
    required this.layout,
    required this.car,
    this.door,
    required this.color,
    required this.frontLabel,
  });
  final CarLayout layout;
  final int car;
  final int? door;
  final Color color;
  final String frontLabel;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const CustomPaint(size: Size(8, 10), painter: _ArrowPainter()),
          const SizedBox(width: 4),
          PixelText(frontLabel, size: 11, color: PixelColors.muted),
        ],
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 48,
        width: double.infinity,
        child: CustomPaint(
          painter: _TrainPainter(layout: layout, car: car, door: door, color: color),
        ),
      ),
    ],
  );
}

/// A small pixel arrow pointing left (the way the train runs).
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = PixelColors.muted;
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(Rect.fromLTWH(i * pu, 4 - i * pu + 1, pu, 2 + i * 2 * pu - 2 + pu), p);
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}

class _TrainPainter extends CustomPainter {
  _TrainPainter({required this.layout, required this.car, required this.door, required this.color});
  final CarLayout layout;
  final int car;
  final int? door;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Everything on a 2px grid so it stays crisp and blocky.
    double snap(double v) => (v / pu).floorToDouble() * pu;
    final order = layout.frontToBack;
    const nose = 6.0;
    const gap = 2.0;
    const top = 8.0; // room for the door pointer
    const bodyH = 20.0;
    final carW = snap((size.width - nose - gap * (order.length - 1)) / order.length);
    final outline = Paint()..color = PixelColors.muted;
    final idle = Paint()..color = PixelColors.soft;
    final idleDoor = Paint()..color = Color.lerp(PixelColors.soft, PixelColors.muted, 0.45)!;
    final ink = Paint()..color = PixelColors.ink;
    final pick = Paint()..color = color;
    final pickDoor = Paint()..color = Color.lerp(color, PixelColors.card, 0.55)!;

    void body(double x, bool chosen) {
      canvas.drawRect(Rect.fromLTWH(x, top, carW, bodyH), chosen ? ink : outline);
      canvas.drawRect(Rect.fromLTWH(x + pu, top + pu, carW - 2 * pu, bodyH - 2 * pu), chosen ? pick : idle);
    }

    // Stepped nose on the front car.
    final frontChosen = order.first == car;
    canvas.drawRect(Rect.fromLTWH(nose - 2 * pu, top + 2 * pu, 3 * pu, bodyH - 4 * pu), frontChosen ? ink : outline);
    canvas.drawRect(Rect.fromLTWH(nose - pu, top + 3 * pu, 2 * pu, bodyH - 6 * pu), frontChosen ? pick : idle);

    for (var i = 0; i < order.length; i++) {
      final n = order[i];
      final x = nose + i * (carW + gap);
      final chosen = n == car;
      body(x, chosen);
      // Four doors per car; the recommended one dark, with a pointer above.
      final slot = (carW - 2 * pu) / layout.doorsPerCar;
      for (var d = 0; d < layout.doorsPerCar; d++) {
        final dx = snap(x + pu + slot * (d + 0.5));
        final isDoor = chosen && door != null && layout.doorSlot(door!) == d;
        if (isDoor) {
          canvas.drawRect(Rect.fromLTWH(dx - pu, top + 2 * pu, 3 * pu, bodyH - 2 * pu), ink);
          // ▼ pointer above the door.
          for (var r = 0; r < 3; r++) {
            canvas.drawRect(Rect.fromLTWH(dx - (2 - r) * pu, r * pu, (5 - 2 * r) * pu, pu), ink);
          }
        } else {
          canvas.drawRect(Rect.fromLTWH(dx, top + 3 * pu, pu, bodyH - 5 * pu), chosen ? pickDoor : idleDoor);
        }
      }
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(
            fontFamily: 'Galmuri11',
            fontSize: chosen ? 12 : 10,
            height: 1,
            fontWeight: chosen ? FontWeight.w700 : FontWeight.w400,
            color: chosen ? PixelColors.ink : PixelColors.muted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(snap(x + (carW - tp.width) / 2), top + bodyH + 4));
    }
  }

  @override
  bool shouldRepaint(_TrainPainter old) =>
      old.car != car || old.door != door || old.color != color || old.layout != layout;
}
