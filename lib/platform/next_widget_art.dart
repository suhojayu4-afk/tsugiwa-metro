import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/pixel/pixel_scene.dart';

/// The つぎの電車 widget, drawn whole as one pixel picture so the home screen
/// keeps the app's look (PixelLab art in assets/art/widget, made by
/// tools/make_widget_art.py; the dot font for every letter):
///
///   [東京]══🚃══[上野]      ☁ 13°
///   ┃約15分おき┃ 上野まで 約5分   10%
///                終電 00:30 🔔
///
/// 192×58 art pixels, drawn 4× so the letters stay sharp.
class NextWidgetData {
  const NextWidgetData({
    required this.fromName,
    required this.toName,
    required this.fromColor,
    required this.toColor,
    required this.lineColor,
    required this.trip,
    required this.last,
    required this.alarm,
    required this.sky,
    required this.temp,
    required this.rain,
    this.lineLabel = '',
    this.first = '',
    this.weather = '',
  });

  /// MY駅 band only: 「くもり 13.0°C」.
  final String weather;

  /// 地下鉄案内 only: 「宇都宮線 白岡方面」, 「始発 04:50」.
  final String lineLabel;
  final String first;

  final String fromName;
  final String toName;
  final Color fromColor;
  final Color toColor;
  final Color lineColor;

  /// 「上野まで 約5分」, 「終電 00:30」.
  final String trip;
  final String last;
  final bool alarm;

  /// clear, cloudy, rainsoon, rain, snowsoon or snow: picks the background
  /// (`assets/art/widget/bg_<part>_<sky>.png`) and the weather icon.
  final String sky;

  /// 「13°」, 「10%」 (or 「傘」).
  final String temp;
  final String rain;
}

const _w = 192.0, _h = 58.0, _k = 4.0;
const _a = 'assets/art/widget/';

/// The weather icon for [sky] at [part] (a moon at night).
String widgetIcon(String sky, DayPart part) {
  final night = part == DayPart.night;
  return switch (sky) {
    'cloudy' => night ? 'mooncloud' : 'cloud2',
    'rainsoon' => 'umbrella',
    'rain' => 'raincloud',
    'snowsoon' => 'snow',
    'snow' => 'snowcloud',
    _ => night ? 'moon' : 'sun',
  };
}

/// Draws the widget at [part] with [led] on the LED panel.
Future<Uint8List> renderNextWidget(NextWidgetData d, String led, DayPart part) async {
  Future<ui.Image> img(String n) => SceneArt.load('$_a$n.png');
  final bg = await img('bg_${part.name}_${d.sky}');
  final signBase = await img('sign_base'), signBand = await img('sign_band');
  final trainBase = await img('train_base'), trainBand = await img('train_band');
  final ledFrame = await img('led');
  final bell = d.alarm ? await img('icon_bell') : null;
  final icon = await img('icon_${widgetIcon(d.sky, part)}');

  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..scale(_k);
  final crisp = Paint()..filterQuality = FilterQuality.none;
  void put(ui.Image i, double x, double y, {Color? tint, double? w, double? h}) {
    final src = Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble());
    final dst = Rect.fromLTWH(x, y, w ?? i.width.toDouble(), h ?? i.height.toDouble());
    c.drawImageRect(
      i,
      src,
      dst,
      tint == null
          ? crisp
          : (Paint()
              ..filterQuality = FilterQuality.none
              ..colorFilter = ColorFilter.mode(tint, BlendMode.modulate)),
    );
  }

  void text(String s, double x, double y, double size, Color color, {bool center = false, double? maxW}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: 'DotGothic16', fontSize: size, color: color, height: 1),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final k = maxW != null && tp.width > maxW ? maxW / tp.width : 1.0;
    c.save();
    c.translate(center ? x - tp.width * k / 2 : x, y);
    c.scale(k, 1);
    tp.paint(c, Offset.zero);
    c.restore();
    tp.dispose();
  }

  // The platform for this hour and sky, kept bright enough to show the
  // weather; dark strips only behind the letters.
  put(bg, 0, 0);
  final veil = switch (part) {
    DayPart.day => 0x30,
    DayPart.evening => 0x28,
    DayPart.night => 0x10,
  };
  c.drawRect(const Rect.fromLTWH(0, 0, _w, _h), Paint()..color = Color.fromARGB(veil, 8, 8, 18));
  // Under the LED and the times, fading in from above.
  for (var i = 0; i < 4; i++) {
    c.drawRect(Rect.fromLTWH(0, 31.0 + i, _w - 34, 1), Paint()..color = Color.fromARGB(0x30 + i * 0x20, 8, 8, 18));
  }
  c.drawRect(const Rect.fromLTWH(0, 35, _w - 34, _h - 35), Paint()..color = const Color(0xB0080812));
  // Behind the weather.
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(_w - 32, 2, 30, 54), const Radius.circular(4)),
    Paint()..color = const Color(0x8C080812),
  );

  // [from] ══ train ══ [to]
  c.drawRect(const Rect.fromLTWH(46, 26, 68, 1), Paint()..color = const Color(0xFF50525C));
  put(signBase, 2, 0);
  put(signBand, 2, 0, tint: d.fromColor);
  // The board's white face is rows 13–23: the name sits inside it.
  text(d.fromName, 24, 14, 9, const Color(0xFF1E2030), center: true, maxW: 36);
  put(trainBase, 50, 9);
  put(trainBand, 50, 9, tint: d.lineColor);
  put(signBase, 114, 0);
  put(signBand, 114, 0, tint: d.toColor);
  text(d.toName, 136, 14, 9, const Color(0xFF1E2030), center: true, maxW: 36);

  // Weather, top right.
  put(icon, 164, 1);
  text(d.temp, 176, 27, 9, const Color(0xFFFFFFFF), center: true, maxW: 28);
  text(d.rain, 176, 38, 8, const Color(0xFF9FD3FF), center: true, maxW: 28);

  // LED: how often trains come now.
  put(ledFrame, 2, 35);
  paintLed(c, const Rect.fromLTWH(5, 38, 76, 14), led, ledOrange);

  // Ride time and the last train.
  text(d.trip, 88, 36, 9, const Color(0xFF8FE08F), maxW: 70);
  text(d.last, 88, 48, 8, const Color(0xFFFFBE6E), maxW: 52);
  if (bell != null) put(bell, 142, 46, w: 12, h: 12);

  final pic = await rec.endRecording().toImage((_w * _k).round(), (_h * _k).round());
  final bytes = await pic.toByteData(format: ui.ImageByteFormat.png);
  pic.dispose();
  return bytes!.buffer.asUint8List();
}

/// 地下鉄案内 (4x2): a departure board on the platform — the line, the route
/// as signs with the train, the last train big on the LED, the first train,
/// the ride time and the weather. 192×96 art pixels, drawn 4×; one picture
/// per time of day.
Future<Uint8List> renderBoardWidget(NextWidgetData d, DayPart part) async {
  Future<ui.Image> img(String n) => SceneArt.load('$_a$n.png');
  final bg = await img('board_${part.name}_${d.sky}');
  final signBase = await img('sign_base'), signBand = await img('sign_band');
  final trainBase = await img('train_base'), trainBand = await img('train_band');
  final ledFrame = await img('led');
  final bell = d.alarm ? await img('icon_bell') : null;
  final icon = await img('icon_${widgetIcon(d.sky, part)}');
  const w = 192.0, h = 96.0;

  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..scale(_k);
  final crisp = Paint()..filterQuality = FilterQuality.none;
  void put(ui.Image i, double x, double y, {Color? tint, double? sw, double? sh}) {
    final src = Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble());
    final dst = Rect.fromLTWH(x, y, sw ?? i.width.toDouble(), sh ?? i.height.toDouble());
    c.drawImageRect(
      i,
      src,
      dst,
      tint == null
          ? crisp
          : (Paint()
              ..filterQuality = FilterQuality.none
              ..colorFilter = ColorFilter.mode(tint, BlendMode.modulate)),
    );
  }

  double text(String s, double x, double y, double size, Color color, {bool center = false, double? maxW}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: 'DotGothic16', fontSize: size, color: color, height: 1),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final k = maxW != null && tp.width > maxW ? maxW / tp.width : 1.0;
    c.save();
    c.translate(center ? x - tp.width * k / 2 : x, y);
    c.scale(k, 1);
    tp.paint(c, Offset.zero);
    c.restore();
    final width = tp.width * k;
    tp.dispose();
    return width;
  }

  put(bg, 0, 0);
  final veil = switch (part) {
    DayPart.day => 0x30,
    DayPart.evening => 0x28,
    DayPart.night => 0x10,
  };
  c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = Color.fromARGB(veil, 8, 8, 18));

  // Line chip, top left; weather, top right.
  final chipW = text(d.lineLabel, -999, -999, 8, const Color(0x00000000)) + 6;
  c.drawRect(Rect.fromLTWH(4, 4, chipW.clamp(0, 140), 11), Paint()..color = d.lineColor);
  text(d.lineLabel, 7, 5.5, 8, const Color(0xFFFFFFFF), maxW: 134);
  c.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(w - 34, 3, 31, 40), const Radius.circular(4)),
    Paint()..color = const Color(0x8C080812),
  );
  put(icon, w - 30, 3);
  text(d.temp, w - 18.5, 27, 8, const Color(0xFFFFFFFF), center: true, maxW: 28);
  text(d.rain, w - 18.5, 35, 7, const Color(0xFF9FD3FF), center: true, maxW: 28);

  // [from] ══ train ══ [to]
  c.drawRect(const Rect.fromLTWH(48, 44, 66, 1), Paint()..color = const Color(0xFF50525C));
  put(signBase, 4, 18);
  put(signBand, 4, 18, tint: d.fromColor);
  text(d.fromName, 26, 32, 9, const Color(0xFF1E2030), center: true, maxW: 36);
  put(trainBase, 52, 27);
  put(trainBand, 52, 27, tint: d.lineColor);
  put(signBase, 113, 18);
  put(signBand, 113, 18, tint: d.toColor);
  text(d.toName, 135, 32, 9, const Color(0xFF1E2030), center: true, maxW: 36);

  // Dark strip with the last train on a big LED, the first train beside it.
  for (var i = 0; i < 4; i++) {
    c.drawRect(Rect.fromLTWH(0, 49.0 + i, w, 1), Paint()..color = Color.fromARGB(0x30 + i * 0x20, 8, 8, 18));
  }
  c.drawRect(const Rect.fromLTWH(0, 53, w, h - 53), Paint()..color = const Color(0xB4080812));
  put(ledFrame, 4, 56, sw: 104, sh: 25);
  paintLed(c, const Rect.fromLTWH(8, 60, 96, 17), d.last, ledOrange);
  if (bell != null) put(bell, 110, 59, sw: 14, sh: 14);
  text(d.first, 128, 62, 8, const Color(0xFF8FE08F), maxW: 60);
  text(d.trip, 6, 85, 8, const Color(0xFFE8E8EE), maxW: 180);

  final pic = await rec.endRecording().toImage((w * _k).round(), (h * _k).round());
  final bytes = await pic.toByteData(format: ui.ImageByteFormat.png);
  pic.dispose();
  return bytes!.buffer.asUint8List();
}

/// The MY駅 widget's info band, laid over the station picture at the bottom:
///
///   [date]  ☁ くもり 13.0°C              傘を忘れずに
///   ┃東京 → 上野              [終電 00:30] 🔔
///
/// 192×30 art pixels, drawn 4×. The date is left empty (x 4–44, rows 7–15):
/// the widget writes it itself in the same dot font so it stays right
/// between app launches (MyStationWidget.kt).
Future<Uint8List> renderMyBand(NextWidgetData d, String route, String rainText, DayPart part) async {
  Future<ui.Image> img(String n) => SceneArt.load('$_a$n.png');
  final ledFrame = await img('led');
  final bell = d.alarm ? await img('icon_bell') : null;
  final icon = await img('icon_${widgetIcon(d.sky, part)}');
  const w = 192.0, h = 30.0;

  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..scale(_k);
  final crisp = Paint()..filterQuality = FilterQuality.none;
  void put(ui.Image i, double x, double y, double sw, double sh) => c.drawImageRect(
    i,
    Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble()),
    Rect.fromLTWH(x, y, sw, sh),
    crisp,
  );

  /// Draws [s] from x (or ending at x when [right]); returns its width.
  double text(String s, double x, double y, double size, Color color, {bool right = false, double? maxW}) {
    if (s.isEmpty) return 0;
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: 'DotGothic16', fontSize: size, color: color, height: 1),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final k = maxW != null && tp.width > maxW ? maxW / tp.width : 1.0;
    final width = tp.width * k;
    c.save();
    c.translate(right ? x - width : x, y);
    c.scale(k, 1);
    tp.paint(c, Offset.zero);
    c.restore();
    tp.dispose();
    return width;
  }

  // Fades in from the picture above, then the dark band (pixel steps, no blur).
  for (var i = 0; i < 5; i++) {
    c.drawRect(Rect.fromLTWH(0, i.toDouble(), w, 1), Paint()..color = Color.fromARGB(0x20 + i * 0x22, 8, 8, 18));
  }
  c.drawRect(const Rect.fromLTWH(0, 5, w, h - 5), Paint()..color = const Color(0xCC080812));
  // A thin line-colour rule on top of the band, like a station sign.
  c.drawRect(const Rect.fromLTWH(0, 5, w, 1), Paint()..color = d.lineColor.withValues(alpha: 0.85));

  // Row 1: (date) · weather icon + text · rain on the right.
  put(icon, 46, 5, 12, 12);
  final wet = d.sky == 'rain' || d.sky == 'snow' || d.sky == 'rainsoon' || d.sky == 'snowsoon';
  final rainW = text(
    rainText,
    w - 4,
    8,
    7,
    wet ? const Color(0xFF9FD3FF) : const Color(0xFFB8C0D0),
    right: true,
    maxW: 64,
  );
  text(d.weather, 60, 8, 8, const Color(0xFFFFFFFF), maxW: w - 4 - rainW - 6 - 60);

  // Row 2: line chip + route · last train on the LED · bell.
  c.drawRect(Rect.fromLTWH(4, 19, 3, 9), Paint()..color = d.lineColor);
  text(route, 10, 20, 8, const Color(0xFFE8E8EE), maxW: 100);
  put(ledFrame, 114, 17, 62, 12);
  paintLed(c, const Rect.fromLTWH(116, 19, 58, 8), d.last, ledOrange);
  if (bell != null) put(bell, 178, 17, 11, 11);

  final pic = await rec.endRecording().toImage((w * _k).round(), (h * _k).round());
  final bytes = await pic.toByteData(format: ui.ImageByteFormat.png);
  pic.dispose();
  return bytes!.buffer.asUint8List();
}
