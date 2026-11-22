// How long the 路線図 tab takes to show after a cold start: the real
// RouteMapScreen pumped with nothing cached, timed from the first pump to
//   - the first frame (what is on screen while the map loads),
//   - the first frame with the map on it (ground, lines, stations, names),
//   - everything loaded (landmark and scenery pictures, seasonal spots),
// with a picture of each into docs/captures/map_fix/ (MAP_LOAD_PREFIX goes in
// front of the file names, e.g. before_ / after_; MAP_LOAD_SIZE=360x560 for
// another screen; MAP_LOAD_LANG=en):
//   flutter test test/tools/render_map_load.dart
// Times are of this machine's test run, not a phone's: compare, do not quote.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/features/route_map/route_map_screen.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

import '../trip_logic_test.dart' show loadTokyo;

void main() {
  testWidgets('load', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final env = Platform.environment;
    final wh = (env['MAP_LOAD_SIZE'] ?? '412x860').split('x').map(double.parse).toList();
    tester.view.physicalSize = Size(wh[0], wh[1]);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefix = env['MAP_LOAD_PREFIX'] ?? '';
    final out = Directory('docs/captures/map_fix')..createSync(recursive: true);
    await tester.runAsync(() async {
      for (final (family, file) in [('DotGothic16', 'DotGothic16-Regular.ttf'), ('Galmuri11', 'Galmuri11.ttf')]) {
        final font = FontLoader(family)..addFont(rootBundle.load('assets/fonts/$file'));
        await font.load();
      }
    });
    final city = loadTokyo();
    final shot = GlobalKey();
    Future<void> save(String name) => tester.runAsync(() async {
      final boundary = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await boundary.toImage();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$prefix$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    bool painted(String painter) => find
        .byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == painter)
        .evaluate()
        .isNotEmpty;

    final sw = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(env['MAP_LOAD_LANG'] ?? 'ja'),
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: const [Locale('ja'), Locale('ko'), Locale('en')],
        home: Scaffold(
          body: RepaintBoundary(
            key: shot,
            child: RouteMapScreen(city: city),
          ),
        ),
      ),
    );
    final first = sw.elapsedMilliseconds;
    await save('load_0_first_frame');
    sw.reset();
    int? mapAt, allAt;
    var pictures = 0, stable = 0;
    // Real time passes in runAsync (asset reads, picture decoding, isolates); then a frame.
    for (var i = 0; i < 3000 && allAt == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
      await tester.pump(const Duration(milliseconds: 16));
      if (mapAt == null && painted('_TerrainPainter')) {
        mapAt = sw.elapsedMilliseconds;
        final frame = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 16));
        // ignore: avoid_print
        print('MAP_LOAD frame after the map came: ${frame.elapsedMilliseconds} ms');
        sw.stop();
        await save('load_1_map');
        sw.start();
      }
      if (mapAt != null) {
        // Everything is in when no more pictures arrive for a while.
        final now = debugMapPictureCount(tester.state(find.byType(RouteMapScreen)));
        stable = now == pictures ? stable + 1 : 0;
        pictures = now;
        if (stable > 60 && now > 0) allAt = sw.elapsedMilliseconds - 60 * 18;
      }
    }
    await save('load_2_all');
    // ignore: avoid_print
    print(
      'MAP_LOAD ${prefix}first frame $first ms; map on screen +$mapAt ms; all $pictures pictures by about +$allAt ms',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
