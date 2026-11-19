// Each platform easter egg (lib/core/pixel/scene_events.dart) forced on and
// rendered frame by frame, for review GIFs:
//   flutter test test/tools/render_scene_events.dart [--dart-define=only=cat]
//   python tools/events_gif.py   -> docs/captures/events/<event>.gif, all.gif
// Frames go to build/event_frames/<event>/NNN.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/core/pixel/scene_events.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';

typedef Shot = ({
  String name,
  SceneEventKind? kind,
  String station,
  DayPart part,
  double seconds,
  double fps,
  WeatherKind weather,
  // Seconds into the event when a train starts pulling in (null = none).
  double? trainAt,
  bool yellow,
});

const _shots = <Shot>[
  (
    name: 'cat',
    kind: SceneEventKind.cat,
    station: 'tokyo',
    part: DayPart.day,
    seconds: 17,
    fps: 8,
    weather: WeatherKind.sunny,
    trainAt: null,
    yellow: false,
  ),
  (
    name: 'pigeons',
    kind: SceneEventKind.pigeons,
    station: 'asakusa',
    part: DayPart.day,
    seconds: 15,
    fps: 8,
    weather: WeatherKind.sunny,
    trainAt: 8,
    yellow: false,
  ),
  (
    name: 'staff',
    kind: SceneEventKind.staff,
    station: 'shinjuku',
    part: DayPart.evening,
    seconds: 10,
    fps: 8,
    weather: WeatherKind.sunny,
    trainAt: 0,
    yellow: false,
  ),
  (
    name: 'shooting_star',
    kind: SceneEventKind.shootingStar,
    station: 'ginza',
    part: DayPart.night,
    seconds: 5,
    fps: 12,
    weather: WeatherKind.sunny,
    trainAt: null,
    yellow: false,
  ),
  (
    name: 'rainbow',
    kind: SceneEventKind.rainbow,
    station: 'asakusa',
    part: DayPart.day,
    seconds: 24,
    fps: 2,
    weather: WeatherKind.cloudy,
    trainAt: null,
    yellow: false,
  ),
  (
    name: 'blimp',
    kind: SceneEventKind.blimp,
    station: 'shibuya',
    part: DayPart.day,
    seconds: 40,
    fps: 2,
    weather: WeatherKind.sunny,
    trainAt: null,
    yellow: false,
  ),
  (
    name: 'dragonflies',
    kind: SceneEventKind.dragonflies,
    station: 'tokyo',
    part: DayPart.evening,
    seconds: 12,
    fps: 10,
    weather: WeatherKind.sunny,
    // The track empty (the train comes later).
    trainAt: 100,
    yellow: false,
  ),
  (
    name: 'yellow_train',
    kind: SceneEventKind.staff,
    station: 'standard',
    part: DayPart.day,
    seconds: 10,
    fps: 8,
    weather: WeatherKind.sunny,
    trainAt: 0,
    yellow: true,
  ),
];

void main() {
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('DotGothic16')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await font.load();
      const only = String.fromEnvironment('only');
      for (final s in _shots) {
        if (only.isNotEmpty && only != s.name) continue;
        final out = Directory('build/event_frames/${s.name}');
        if (out.existsSync()) out.deleteSync(recursive: true);
        out.createSync(recursive: true);
        final look = s.station == 'standard'
            ? SceneLook(trainArt: s.yellow ? yellowTrainArt : null)
            : SceneLook(
                images: {for (final p in DayPart.values) p: 'assets/art/scenes/${s.station}_${p.name}.png'},
                trainArt: s.yellow ? yellowTrainArt : null,
              ).withLed(s.yellow ? const [] : const ['快速 東京'], const [ledOrange]);
        final n = (s.seconds * s.fps).round();
        for (var i = 0; i <= n; i++) {
          final t = i / s.fps;
          final events = s.kind == null
              ? null
              : SceneEventDirector.preview(s.kind!, t, scareAt: s.trainAt == null ? null : s.trainAt! + 2.2);
          // The train: away (track empty) until it is due, then pulling in and boarding.
          double? arrive, platform, depart;
          if (s.trainAt != null) {
            final since = t - s.trainAt!;
            if (since < 0) {
              arrive = 1;
              platform = 1;
              depart = 1;
            } else {
              arrive = (since / 4.6).clamp(0.0, 1.0);
              platform = ((since - 4.6) / 3.6).clamp(0.0, 1.0);
              depart = 0;
            }
          }
          final img = await renderSceneImage(
            look: look,
            part: s.part,
            lineColor: const Color(0xFF80C241),
            weather: s.weather,
            scale: 2,
            arrive: arrive,
            platform: platform,
            depart: depart,
            tick: (t / 0.32).floor(),
            events: events,
          );
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/${i.toString().padLeft(3, '0')}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
          events?.dispose();
        }
      }
    });
  }, timeout: const Timeout(Duration(minutes: 20)));
}
