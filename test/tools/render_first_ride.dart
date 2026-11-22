// 「日本の電車はじめて」 and the first-visit welcome into docs/captures/first_ride/
// (review): the guide with a chapter open, the words chapter, and the welcome
// at 鳥取 (with the nearby dunes and the day's postcard).
//   flutter test test/tools/render_first_ride.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/core/services.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';
import 'package:tsugiwa_metro/features/album/postcard_book.dart';
import 'package:tsugiwa_metro/features/guide/first_ride_screen.dart';
import 'package:tsugiwa_metro/features/trip/widgets/first_visit_welcome.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

import '../tottori_city_test.dart' show loadTottori;

void main() {
  testWidgets('render', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final city = loadTottori();
    final store = Services.my = MyStore()..lines = {for (final l in city.lines) l.id: l.stations};
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
      await store.rewardTrip(['tottori.koyama', 'tottori.tottori']);
      await PostcardBook.instance.add(my: store, station: 'tottori.tottori', from: 'tottori.koyama');
    });
    final out = Directory('docs/captures/first_ride')..createSync(recursive: true);
    tester.view.physicalSize = const Size(780, 1690);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 300));
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
            child: const FirstRideGuideScreen(cityId: 'tottori'),
          ),
        ),
      );
      await settle();
      await tester.tap(find.byKey(const ValueKey('firstRide.country')));
      await settle();
      await shot(key, 'guide_country_$lang');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('firstRide.words')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('firstRide.words')));
      await settle();
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await settle();
      await shot(key, 'guide_words_$lang');

      final key2 = GlobalKey();
      await tester.pumpWidget(
        app(
          lang,
          RepaintBoundary(
            key: key2,
            child: Container(
              color: const Color(0xFF2A3040),
              child: FirstVisitWelcome(city: city, stationId: 'tottori.tottori', lineId: 'tottori.sanin'),
            ),
          ),
        ),
      );
      await settle();
      await tester.pump(const Duration(seconds: 2));
      await settle();
      await shot(key2, 'welcome_tottori_$lang');
    }
    // The sign swinging in, frame by frame (packed into a GIF by
    // tools/tottori/make_gifs.py-style code below).
    final key3 = GlobalKey();
    await tester.pumpWidget(
      app(
        'ja',
        RepaintBoundary(
          key: key3,
          child: Container(
            color: const Color(0xFF2A3040),
            child: FirstVisitWelcome(city: city, stationId: 'tottori.tottori', lineId: 'tottori.sanin'),
          ),
        ),
      ),
    );
    await settle();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 90));
      await shot(key3, 'welcome_frame_${i.toString().padLeft(2, '0')}');
    }
  });
}
