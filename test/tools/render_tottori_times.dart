// Real Tottori timetables, as pictures: docs/captures/tottori_times/*.png
// (のりば情報, the departure board at 鳥取, a trip waiting for its train).
//   flutter test test/tools/render_tottori_times.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/app.dart';
import 'package:tsugiwa_metro/core/japan_time.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_ui.dart';
import 'package:tsugiwa_metro/core/services.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';
import 'package:tsugiwa_metro/features/platform/departure_board.dart';
import 'package:tsugiwa_metro/features/platform/platform_info_card.dart';
import 'package:tsugiwa_metro/features/trip/location_source.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';
import 'package:tsugiwa_metro/features/trip/train_sheet.dart';
import 'package:tsugiwa_metro/features/trip/trip_controller.dart';
import 'package:tsugiwa_metro/features/trip/trip_estimator.dart';
import 'package:tsugiwa_metro/features/trip/trip_plan.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/features/trip/trip_screen.dart';
import 'package:tsugiwa_metro/features/trip/widgets/layered_train_view.dart';
import 'package:tsugiwa_metro/features/trip/widgets/side_train_view.dart';
import 'package:tsugiwa_metro/features/trip/widgets/trip_props.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';
import 'package:tsugiwa_metro/platform/live_status_bridge.dart';

import '../tottori_city_test.dart' show loadTottori;
import '../trip_gps_test.dart' show FakeLocation;

void main() {
  final city = loadTottori();
  final out = Directory('docs/captures/tottori_times')..createSync(recursive: true);
  final shot = GlobalKey();
  // Tuesday 2026-11-24 10:05 in Japan.
  final jst = DateTime(2026, 11, 24, 10, 5);

  // The trip view's pictures, loaded for real before a trip is shown.
  Future<void> art(WidgetTester tester) => tester.runAsync(() async {
    await Train3dArt.load();
    await Train3dArt.load(electric: false);
    await Props3dArt.load(SceneArt.load);
    // Tottori's scenery sets, at the time of day the view shows (the phone's clock).
    final part = dayPartOf(DateTime.now().toUtc().add(const Duration(hours: 9)));
    for (final t in ['city', 'seaside', 'country', 'mountain', 'oldtown', 'river', 'flower']) {
      await SideTrainArt.loadWith(part, SceneArt.load, theme: t);
    }
  });

  Future<void> fonts(WidgetTester tester) => tester.runAsync(() async {
    final sys = FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
    await sys.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('C:/dev/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf').readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
    for (final f in ['DotGothic16-Regular.ttf', 'Galmuri11.ttf', 'Galmuri11-Bold.ttf']) {
      final font = FontLoader(f.startsWith('Dot') ? 'DotGothic16' : 'Galmuri11')
        ..addFont(rootBundle.load('assets/fonts/$f'));
      await font.load();
    }
  });

  Widget app(Widget home, String lang) {
    final theme = buildTheme();
    return RepaintBoundary(
      key: shot,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(lang),
        theme: lang == 'ko' ? theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Galmuri11')) : theme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: DefaultTextStyle.merge(
          style: TextStyle(fontFamily: lang == 'ko' ? 'Galmuri11' : null),
          child: home,
        ),
      ),
    );
  }

  Future<void> save(WidgetTester tester, String name) => tester.runAsync(() async {
    final b = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MyCatalog.resetCache();
    Services.my = MyStore();
    Services.live = const NoopLiveStatusBridge();
    Services.location = const NoLocationSource();
    japanClock = () => jst.subtract(const Duration(hours: 9)).copyWith(isUtc: true);
  });
  tearDown(() => japanClock = DateTime.now);

  for (final lang in ['ja', 'ko']) {
    testWidgets('cards $lang', (tester) async {
      tester.view.physicalSize = const Size(780, 900);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await fonts(tester);
      final route = RouteFinder(city).find('tottori.yonago', 'tottori.sakaiminato')!;
      await tester.pumpWidget(
        app(
          Scaffold(
            backgroundColor: const Color(0xFFF4F4F1),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  PlatformInfoCard(city: city, route: route),
                  const SizedBox(height: 16),
                  DepartureBoard(city: city, stationId: 'tottori.yonago'),
                ],
              ),
            ),
          ),
          lang,
        ),
      );
      await settle(tester);
      await save(tester, 'cards_$lang');
    });

    testWidgets('trip $lang', (tester) async {
      tester.view.physicalSize = const Size(780, 1690);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await fonts(tester);
      await art(tester);
      final route = RouteFinder(city).find('tottori.yonago', 'tottori.sakaiminato')!;
      final plan = TripPlan.build(city, route, jst);
      final start = DateTime.now();
      final c = TripController(
        city: city,
        plan: plan,
        lang: lang,
        location: const NoLocationSource(),
        bridge: const NoopLiveStatusBridge(),
        clock: () => start,
      );
      await tester.pumpWidget(app(TripScreen(controller: c), lang));
      await settle(tester);
      await save(tester, 'trip_$lang');
      await tester.pumpWidget(const SizedBox());
      await settle(tester, 2);
    });
  }

  // Walking to 鳥取 from 1 km away, then riding between two stations.
  for (final (name, onBoard) in [('walk_ko', false), ('ride_ko', true)]) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(780, 3400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await fonts(tester);
      await art(tester);
      final route = RouteFinder(city).find('tottori.tottori', 'tottori.yonago', at: jst)!;
      final plan = TripPlan.build(city, route, jst);
      final loc = FakeLocation();
      final c = TripController(city: city, plan: plan, lang: 'ko', location: loc, bridge: const NoopLiveStatusBridge());
      await tester.pumpWidget(app(TripScreen(controller: c), 'ko'));
      await settle(tester, 2);
      final o = city.station(plan.stops[onBoard ? 3 : 0].stationId);
      final b = city.station(plan.stops[4].stationId);
      loc.fixes.add(
        onBoard
            ? GpsFix(
                lat: o.lat * 0.4 + b.lat * 0.6,
                lng: o.lng * 0.4 + b.lng * 0.6,
                accuracyM: 20,
                time: DateTime.now(),
              )
            : GpsFix(lat: o.lat - 0.006, lng: o.lng + 0.004, accuracyM: 20, time: DateTime.now()),
      );
      await settle(tester);
      await save(tester, name);
      await tester.pumpWidget(const SizedBox());
      await settle(tester, 2);
    });
  }

  testWidgets('train sheet', (tester) async {
    tester.view.physicalSize = const Size(780, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await fonts(tester);
    // A 境線 train running at 10:05.
    final run = city.trains['tottori.sakai']!.weekday.firstWhere(
      (r) => r.stops.first.departMin <= 605 && r.stops.last.arriveMin > 605,
    );
    await tester.pumpWidget(
      app(
        Scaffold(
          backgroundColor: PixelColors.card,
          body: TrainSheet(city: city, lineId: 'tottori.sakai', run: run),
        ),
        'ko',
      ),
    );
    await settle(tester);
    await save(tester, 'train_sheet_ko');
    final route = RouteFinder(city).find('tottori.tottori', 'tottori.sakaiminato', at: jst)!;
    // ignore: avoid_print
    print([for (final l in route.legs) '${l.lineId} ${l.stationIds.first}→${l.stationIds.last}'].join(' | '));
  });
}
