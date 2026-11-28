// The real 路線図 of Tottori, as pictures: docs/captures/maps_tottori/app_*.png
// (as it opens, fitted to the whole region, and zoomed in with the buttons).
//   flutter test test/tools/render_tottori_map.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/features/route_map/route_map_screen.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

import '../tottori_city_test.dart' show loadTottori;

void main() {
  testWidgets('tottori map', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final out = Directory('docs/captures/maps_tottori')..createSync(recursive: true);
    await tester.runAsync(() async {
      for (final (family, file) in [('DotGothic16', 'DotGothic16-Regular.ttf'), ('Galmuri11', 'Galmuri11.ttf')]) {
        final font = FontLoader(family)..addFont(rootBundle.load('assets/fonts/$file'));
        await font.load();
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('C:/dev/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf').readAsBytesSync(),
            ),
          ),
        );
      await icons.load();
    });
    final shot = GlobalKey();
    Future<void> save(String name) => tester.runAsync(() async {
      final b = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/app_$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    Future<void> settle([int n = 400]) async {
      for (var i = 0; i < n; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 3)));
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ko'),
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: const [Locale('ja'), Locale('ko'), Locale('en')],
        home: Scaffold(
          body: RepaintBoundary(
            key: shot,
            child: RouteMapScreen(city: loadTottori()),
          ),
        ),
      ),
    );
    await settle();
    await save('0_open');
    // The buttons down the right edge: fit all, then zoom in on the middle.
    await tester.tap(find.byIcon(Icons.zoom_out_map_rounded));
    await settle(120);
    await save('1_out');
    await tester.tap(find.byIcon(Icons.remove));
    await settle(120);
    await save('2_region');
    await tester.tap(find.byIcon(Icons.zoom_out_map_rounded));
    await settle(80);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.add));
      await settle(60);
    }
    await save('3_closer');
  });
}
