// The layered train diorama, as pictures: docs/captures/layered_train/*.png
// (day, evening, night, tunnel, a stop at a platform, turned by a finger).
//   flutter test test/tools/render_layered_train.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/features/trip/widgets/layered_train_view.dart';
import 'package:tsugiwa_metro/features/trip/widgets/side_train_view.dart';
import 'package:tsugiwa_metro/features/trip/widgets/trip_props.dart';

void main() {
  // Load the pictures for real first (the widget then finds them ready).
  final out = Directory('docs/captures/layered_train')..createSync(recursive: true);
  final shot = GlobalKey();

  Future<void> save(WidgetTester tester, String name) => tester.runAsync(() async {
    final b = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });

  Future<void> show(
    WidgetTester tester,
    String name, {
    required int hour,
    bool underground = false,
    bool moving = true,
    Offset drag = Offset.zero,
    (double, double)? camera,
  }) async {
    tester.view.physicalSize = const Size(780, 380);
    await tester.runAsync(() async {
      await Train3dArt.load();
      for (final p in DayPart.values) {
        await SideTrainArt.loadWith(p, SceneArt.load);
      }
    });

    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF4F4F1),
          body: Center(
            child: RepaintBoundary(
              key: shot,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: LayeredTrainView(
                  underground: underground,
                  moving: moving,
                  lineColor: const Color(0xFF1F78C8),
                  now: DateTime(2026, 11, 24, hour),
                  camera: camera,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Let the pictures load and decode, then run the scene a little.
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (drag != Offset.zero) {
      final g = await tester.startGesture(tester.getCenter(find.byType(LayeredTrainView)));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(drag / 10);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await save(tester, name);
      await g.up();
    } else {
      await save(tester, name);
    }
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('day', (t) => show(t, 'day', hour: 11));
  testWidgets('evening', (t) => show(t, 'evening', hour: 17));
  testWidgets('night', (t) => show(t, 'night', hour: 22));
  testWidgets('tunnel', (t) => show(t, 'tunnel', hour: 11, underground: true));
  testWidgets('platform', (t) => show(t, 'platform', hour: 11, moving: false));
  testWidgets('turned left', (t) => show(t, 'turned_left', hour: 11, camera: (-0.45, -0.12)));
  testWidgets('turned right', (t) => show(t, 'turned_right', hour: 17, camera: (0.45, 0.1)));

  // Every scene and several camera turns on one sheet.
  testWidgets('sheet', (tester) async {
    tester.view.physicalSize = const Size(1600, 1800);
    await tester.runAsync(() async {
      await Train3dArt.load();
      for (final p in DayPart.values) {
        await SideTrainArt.loadWith(p, SceneArt.load);
      }
    });

    await tester.runAsync(() async {
      final f = FontLoader('Galmuri11')..addFont(rootBundle.load('assets/fonts/Galmuri11.ttf'));
      await f.load();
    });
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final cells = <(String, int, bool, bool, (double, double))>[
      ('낮 · 정면', 11, false, true, (0, 0)),
      ('낮 · 왼쪽에서', 11, false, true, (-0.45, -0.1)),
      ('저녁 · 오른쪽 위에서', 17, false, true, (0.4, 0.12)),
      ('밤 · 왼쪽 위에서', 22, false, true, (-0.3, 0.12)),
      ('터널 · 정면', 11, true, true, (0, 0)),
      ('터널 · 오른쪽에서', 11, true, true, (0.4, 0)),
      ('역 정차 · 낮', 11, false, false, (0.2, 0.05)),
      ('역 정차 · 밤', 22, false, false, (-0.25, 0.05)),
    ];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF4F4F1),
          body: RepaintBoundary(
            key: shot,
            child: Container(
              color: const Color(0xFFF4F4F1),
              padding: const EdgeInsets.all(12),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 12,
                childAspectRatio: 1.95,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final (label, hour, under, moving, cam) in cells)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(fontFamily: 'Galmuri11', fontSize: 14, color: Color(0xFF555555)),
                        ),
                        const SizedBox(height: 4),
                        LayeredTrainView(
                          underground: under,
                          moving: moving,
                          lineColor: under ? const Color(0xFFE85298) : const Color(0xFF1F78C8),
                          now: DateTime(2026, 11, 24, hour),
                          camera: cam,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // Let the pictures load and decode, then run the scene a little.
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await save(tester, 'sheet');
    await tester.pumpWidget(const SizedBox());
  });

  // Every scenery set made so far, by day, evening and night: docs/captures/layered_train/themes.png
  testWidgets('themes', (tester) async {
    final themes = [
      for (final t in SideTrainArt.themes)
        if (File(SideTrainArt.farAsset(DayPart.day, t)).existsSync()) t,
    ];
    await tester.runAsync(() async {
      await Train3dArt.load();
      await Train3dArt.load(electric: false);
      await Props3dArt.load(SceneArt.load);
      for (final t in themes) {
        for (final p in DayPart.values) {
          await SideTrainArt.loadWith(p, SceneArt.load, theme: t);
        }
      }
      final f = FontLoader('Galmuri11')..addFont(rootBundle.load('assets/fonts/Galmuri11.ttf'));
      await f.load();
    });
    // The diesel railcar too, on two sets without overhead wires.
    final rows = [for (final t in themes) (t, true), ('seaside', false), ('country', false)];
    tester.view.physicalSize = Size(2400, 60.0 + rows.length * 300);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const hours = [11, 17, 22];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: RepaintBoundary(
            key: shot,
            child: Container(
              color: const Color(0xFFF4F4F1),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final (i, (t, electric)) in rows.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text(
                              electric ? t : '$t diesel',
                              style: const TextStyle(fontFamily: 'Galmuri11', fontSize: 14),
                            ),
                          ),
                          for (final h in hours)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: LayeredTrainView(
                                  underground: false,
                                  moving: true,
                                  theme: t,
                                  electric: electric,
                                  lineColor: const [Color(0xFF1F78C8), Color(0xFFE8892A), Color(0xFF3FA66B)][i % 3],
                                  now: DateTime(2026, 11, 24, h),
                                  camera: (0.12 * (h - 17) / 6, 0.03),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await save(tester, 'themes');
    await tester.pumpWidget(const SizedBox());
  });
}
