// 旅のアルバム previews into docs/captures/album/ (review): the album page,
// a postcard front and back.
//   flutter test test/tools/render_album.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/core/japan_time.dart';
import 'package:tsugiwa_metro/core/services.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';
import 'package:tsugiwa_metro/features/album/album_screen.dart';
import 'package:tsugiwa_metro/features/album/postcard_book.dart';
import 'package:tsugiwa_metro/features/album/postcard_view.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

import '../platform_features_test.dart' show loadTokyo;

String _id(dynamic city, String ja) => city.stations.entries.firstWhere((e) => e.value.name.ja == ja).key as String;

void main() {
  testWidgets('render', (tester) async {
    SharedPreferences.setMockInitialValues({});
    japanClock = () => DateTime.utc(2026, 11, 23, 3);
    final city = loadTokyo();
    final store = Services.my = MyStore()..lines = {for (final l in city.lines) l.id: l.stations};
    final book = PostcardBook.instance;
    await tester.runAsync(() async {
      final sys = FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await sys.load();
      for (final f in ['DotGothic16-Regular.ttf', 'Galmuri11.ttf']) {
        final font = FontLoader(f.startsWith('Dot') ? 'DotGothic16' : 'Galmuri11')
          ..addFont(rootBundle.load('assets/fonts/$f'));
        await font.load();
      }
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
      await book.load(store);
      final cards = [
        ('渋谷', '新宿', WeatherKind.sunny, DateTime(2026, 11, 22, 13, 20), false),
        ('浅草', '上野', WeatherKind.rain, DateTime(2026, 11, 20, 17, 40), false),
        ('東京', '品川', WeatherKind.cloudy, DateTime(2026, 11, 3, 21, 5), true),
        ('秋葉原', '東京', WeatherKind.sunny, DateTime(2026, 10, 12, 8, 30), false),
        ('銀座', '渋谷', WeatherKind.snow, DateTime(2026, 1, 15, 11, 0), false),
        ('上野', '池袋', WeatherKind.sunny, DateTime(2025, 11, 23, 15, 10), false),
      ];
      for (final (st, from, w, at, gold) in cards) {
        await store.rewardTrip([_id(city, from), _id(city, st)], now: at);
        await book.add(my: store, station: _id(city, st), from: _id(city, from), weather: w, gold: gold, now: at);
      }
      await book.setMemo(book.cards[1].id, '雷門の前でおだんご食べた！');
    });
    final out = Directory('docs/captures/album')..createSync(recursive: true);
    tester.view.physicalSize = const Size(780, 1690);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
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
            child: AlbumScreen(city: city),
          ),
        ),
      );
      await settle();
      await shot(key, 'album_$lang');
    }
    for (final (i, c) in book.cards.take(3).indexed) {
      for (final back in [false, true]) {
        final key = GlobalKey();
        await tester.pumpWidget(
          app(
            'ja',
            Material(
              color: const Color(0xFF2A2F3A),
              child: Center(
                child: RepaintBoundary(
                  key: key,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 366,
                      child: back ? PostcardBack(city: city, card: c) : PostcardFront(city: city, card: c, my: store),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await settle();
        await shot(key, 'card${i}_${back ? 'back' : 'front'}');
      }
    }
  });
}
