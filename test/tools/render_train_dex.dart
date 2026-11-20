// 車両図鑑 previews into docs/captures/train_dex/ (review): the grid with a
// few kinds collected, and detail cards.
//   flutter test test/tools/render_train_dex.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';
import 'package:tsugiwa_metro/data/train_dex.dart';
import 'package:tsugiwa_metro/features/my_room/train_dex_screen.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

import '../platform_features_test.dart' show loadTokyo;

void main() {
  testWidgets('render', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final city = loadTokyo();
    final store = MyStore()..lines = {for (final l in city.lines) l.id: l.stations};
    final all = Platform.environment['DEX_ALL'] == '1';
    await tester.runAsync(() async {
      final sys = FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await sys.load();
      for (final f in ['DotGothic16-Regular.ttf', 'Galmuri11.ttf']) {
        final font = FontLoader(f.startsWith('Dot') ? 'DotGothic16' : 'Galmuri11')
          ..addFont(rootBundle.load('assets/fonts/$f'));
        await font.load();
      }
      // Material icons for the stars and symbols (from the Flutter SDK).
      var dir = File(Platform.resolvedExecutable).parent;
      while (dir.parent.path != dir.path && !dir.path.endsWith('artifacts')) {
        dir = dir.parent;
      }
      final otf = File('${dir.path}/material_fonts/materialicons-regular.otf');
      if (otf.existsSync()) {
        final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(otf.readAsBytesSync())));
        await icons.load();
      }
      await store.load(
        catalog: MyCatalog.fromJson(
          jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
        ),
      );
      final ride = all
          ? [for (final l in city.lines) l.id]
          : [
              'tokyo.yamanote',
              'tokyo.ginza',
              'tokyo.tozai',
              'tokyo.tokyu_toyoko',
              'tokyo.yurikamome',
              'tokyo.tokaido',
              'tokyo.hakone_tozan',
              'tokyo.chiba_monorail_2',
              'tokyo.toden_arakawa',
            ];
      for (final (i, id) in ride.indexed) {
        final line = city.line(id);
        await store.rewardTrip(line.stations.take(3).toList(), now: DateTime(2026, 10, 1 + i % 28, 8), ridden: [id]);
      }
    });
    final out = Directory('docs/captures/train_dex')..createSync(recursive: true);
    tester.view.physicalSize = const Size(780, 3400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shot(GlobalKey key, String name) => tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    Widget app(String lang, Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      home: home,
    );

    for (final lang in ['ja', 'ko']) {
      final key = GlobalKey();
      await tester.pumpWidget(
        app(
          lang,
          RepaintBoundary(
            key: key,
            child: TrainDexScreen(city: city, store: store, yellow: all),
          ),
        ),
      );
      await settle();
      await shot(key, 'grid_${all ? 'all_' : ''}$lang');
    }

    final got = collected(store, city, yellow: all);
    final lines = linesByType(city);
    final ridden = {for (final t in store.trips) ...t.lines};
    for (final id in ['mountain', 'jr_commuter', 'private_commuter', 'yellow', 'hanging_monorail']) {
      final key = GlobalKey();
      await tester.pumpWidget(
        app(
          'ja',
          Material(
            color: const Color(0xFF8A8F98),
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 360,
                  child: TrainDexDetail(
                    type: trainType(id),
                    lines: lines[id]!,
                    ridden: ridden,
                    firstDay: got[id],
                    lang: 'ja',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settle();
      await shot(key, 'detail_${all ? 'all_' : ''}$id');
    }
  });
}
