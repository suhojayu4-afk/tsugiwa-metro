import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/pixel/pixel_scene.dart';
import '../../data/my_catalog.dart';
import '../../data/my_store.dart';
import '../../data/weather/weather_source.dart';

/// The user's station name, shown on the train's destination LED.
@immutable
class PlateData {
  const PlateData({required this.name, this.kana = '', this.style = PlateStyle.basic});

  /// From the saved name; [fallbackName] (the scene's name) when none.
  factory PlateData.of(MyStore store, {required String fallbackName}) {
    final p = store.plate;
    return PlateData(name: p.name.isEmpty ? fallbackName : p.name, kana: p.kana, style: store.plateStyle);
  }

  final String name;
  final String kana;
  final PlateStyle style;

  /// What the LED shows in turn: the name, then its reading.
  List<String> get pages => [if (name.isNotEmpty) name, if (kana.isNotEmpty) kana];

  @override
  bool operator ==(Object other) =>
      other is PlateData &&
      other.name == name &&
      other.kana == kana &&
      other.style.colors.join() == style.colors.join();

  @override
  int get hashCode => Object.hash(name, kana, style.colors.join());
}

/// Look of the scene with the name on the train's LED.
SceneLook lookWithLed(SceneLook look, PlateData plate) => look.withLed(plate.pages, plate.style.colors);

/// A destination LED on its own (previews, item cards). [page] picks the
/// colour for multi-colour LEDs.
class LedSign extends StatelessWidget {
  const LedSign({super.key, required this.text, required this.colors, this.width = 160, this.page = 0});

  final String text;
  final List<Color> colors;
  final double width;
  final int page;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(width * 0.03),
    decoration: BoxDecoration(color: const Color(0xFF2A2833), borderRadius: BorderRadius.circular(width * 0.03)),
    child: SizedBox(
      width: width,
      height: width * 7 / 43,
      child: CustomPaint(painter: _LedPainter(text, colors[page % colors.length])),
    ),
  );
}

class _LedPainter extends CustomPainter {
  _LedPainter(this.text, this.color);
  final String text;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => paintLed(canvas, Offset.zero & size, text, color);

  @override
  bool shouldRepaint(_LedPainter old) => old.text != text || old.color != color;
}

/// The MY station: the scene with the name running on the train's LED.
class MyStationView extends StatelessWidget {
  const MyStationView({
    super.key,
    required this.look,
    required this.plate,
    required this.lineColor,
    this.weather,
    this.aspect = 1.8,
    this.onTap,
    this.led,
    this.arrivalKey,
    this.sky,
    this.sign,
    this.onArrive,
  });

  /// See [PixelSceneBanner.onArrive].
  final VoidCallback? onArrive;

  final SceneLook look;
  final PlateData plate;
  final Color lineColor;
  final WeatherKind? weather;
  final double aspect;
  final VoidCallback? onTap;

  /// Pages for the train's LED instead of the station name (e.g. the
  /// destination of the chosen route: 「各停 浅草」).
  final List<String>? led;

  /// See [PixelSceneBanner.arrivalKey] / [PixelSceneBanner.sky].
  final Object? arrivalKey;
  final String? sky;

  /// The hanging station sign; null = the MY station's own name.
  final StationSign? sign;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: PixelSceneBanner(
      lineColor: lineColor,
      weather: weather,
      look: (led == null ? lookWithLed(look, plate) : look.withLed(led!, plate.style.colors)).withSign(
        sign ?? StationSign(name: plate.name, sub: plate.kana, band: look.trainColor ?? lineColor),
      ),
      aspect: aspect,
      arrivalKey: arrivalKey,
      sky: sky,
      onArrive: onArrive,
    ),
  );
}

/// The MY station as a PNG: the whole scene at [part], name on the LED,
/// each art pixel [scale]×[scale]. Used by the home screen widget.
Future<Uint8List> renderMyStationPng({
  required SceneLook look,
  required PlateData plate,
  required DayPart part,
  required Color lineColor,
  WeatherKind weather = WeatherKind.sunny,
  int scale = 2,
  String? sky,
}) async {
  // A still picture shows the name only (no reading page).
  final image = await renderSceneImage(
    look: look.withLed([plate.name], plate.style.colors),
    part: part,
    lineColor: lineColor,
    weather: weather,
    scale: scale,
    sky: sky,
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
