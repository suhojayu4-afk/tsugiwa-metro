// のりば fixes, as pictures: docs/captures/platform_fix/*.png
//   flutter test test/tools/render_platform_fix.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/app.dart';
import 'package:tsugiwa_metro/core/japan_time.dart';
import 'package:tsugiwa_metro/core/localized_text.dart';
import 'package:tsugiwa_metro/core/services.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';
import 'package:tsugiwa_metro/data/route_store.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';
import 'package:tsugiwa_metro/features/guide/guide_card.dart';
import 'package:tsugiwa_metro/features/guide/guide_data.dart';
import 'package:tsugiwa_metro/features/platform/platform_screen.dart';
import 'package:tsugiwa_metro/features/platform/station_picker.dart';
import 'package:tsugiwa_metro/features/trip/location_source.dart';
import 'package:tsugiwa_metro/features/trip/trip_estimator.dart' show GpsFix;
import 'package:tsugiwa_metro/l10n/app_localizations.dart';
import 'package:tsugiwa_metro/platform/home_widget_bridge.dart';
import 'package:tsugiwa_metro/platform/live_status_bridge.dart';

import '../trip_logic_test.dart' show loadTokyo;

class _FakeWeather implements WeatherSource {
  @override
  Future<WeatherNow> fetch(WeatherArea area) async =>
      const WeatherNow(kind: WeatherKind.sunny, tempC: 6.1, humidity: 56, rainChance: 0);
}

class _FixedLocation implements LocationSource {
  const _FixedLocation(this.fix);
  final GpsFix fix;
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Stream<GpsFix> watch({GpsPower power = GpsPower.precise, bool background = false}) => const Stream.empty();
  @override
  Future<GpsFix?> currentFix() async => fix;

  @override
  Stream<double> heading() => const Stream.empty();
}

void main() {
  final city = loadTokyo();
  final out = Directory('docs/captures/platform_fix')..createSync(recursive: true);
  final shot = GlobalKey();
  const harajuku = 'tokyo.harajuku';
  String id(String ja) => city.stations.values.firstWhere((s) => s.name.ja == ja).id;

  Future<void> fonts(WidgetTester tester) => tester.runAsync(() async {
    final sys = FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
    await sys.load();
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
        // DotGothic16 has no Hangul: Galmuri11 stands in for the system font.
        theme: lang == 'ko' ? theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Galmuri11')) : theme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: Scaffold(
          backgroundColor: const Color(0xFFF4F4F1),
          body: DefaultTextStyle.merge(
            style: TextStyle(fontFamily: lang == 'ko' ? 'Galmuri11' : null),
            child: SafeArea(child: home),
          ),
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

  /// Lets real I/O (pictures, preferences) finish, then draws.
  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  void size(WidgetTester tester, double w, double h, {double scale = 1}) {
    tester.view.physicalSize = Size(w * 2, h * 2);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    rootBundle.clear();
    MyCatalog.resetCache();
    Services.routes = RouteStore();
    Services.my = MyStore();
    Services.homeWidget = const NoHomeWidget();
    Services.weather = _FakeWeather();
    Services.live = const NoopLiveStatusBridge();
    Services.location = const NoLocationSource();
    japanClock = () => DateTime.utc(2026, 11, 24, 3); // Tuesday noon in Japan
  });
  tearDown(() => japanClock = DateTime.now);

  testWidgets('guide bubble: one tip at a time', (tester) async {
    size(tester, 360, 130);
    await fonts(tester);
    GuideTip tip(String s) => GuideTip(TipKind.help, LocalizedText({'ja': s}));
    await tester.pumpWidget(
      app(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GuideCard(
            tips: [tip('原宿のスタンプはまだです。乗って集めよう'), tip('新宿での乗り換えは 歩いて約5分。時間に余裕をもってね。丸ノ内線のホームは地下です。案内にそって進んでください')],
          ),
        ),
        'ja',
      ),
    );
    await settle(tester, 4);
    await save(tester, 'guide_0_before');
    await tester.tap(find.byType(GuideCard));
    await tester.pump();
    var at = 0;
    for (final ms in [80, 160, 240, 320, 420]) {
      await tester.pump(Duration(milliseconds: ms - at));
      at = ms;
      await save(tester, 'guide_${ms}ms');
    }
    await tester.pumpWidget(const SizedBox());
  });

  for (final (lang, w, scale) in [('en', 320.0, 1.3), ('en', 360.0, 1.0), ('ko', 320.0, 1.3), ('ja', 412.0, 1.3)]) {
    testWidgets('screen $lang ${w.round()} × $scale: header, names, route', (tester) async {
      size(tester, w, 760, scale: scale);
      await fonts(tester);
      SharedPreferences.setMockInitialValues({
        'routes.favourites': '[{"from":"$harajuku","to":"${id('新宿御苑前')}","kind":"home"}]',
        'routes.recents': '[{"from":"tokyo.shibuya","to":"${id('表参道')}"},{"from":"tokyo.tokyo","to":"${id('秋葉原')}"}]',
      });
      await tester.pumpWidget(app(PlatformScreen(key: UniqueKey(), city: city), lang));
      await settle(tester);
      await save(tester, 'screen_${lang}_${w.round()}_x${(scale * 10).round()}');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('route kept from the last launch, last train 00:09, walk leg', (tester) async {
    size(tester, 360, 1100);
    await fonts(tester);
    for (final (name, to) in [('route_harajuku_gyoemmae', '新宿御苑前'), ('route_harajuku_nogizaka_walk', '乃木坂')]) {
      SharedPreferences.setMockInitialValues({'routes.last': '{"from":"$harajuku","to":"${id(to)}"}'});
      Services.routes = RouteStore();
      await tester.pumpWidget(app(PlatformScreen(key: UniqueKey(), city: city), 'ja'));
      await settle(tester);
      await save(tester, name);
      // The panel pulled up: the route preview.
      await tester.drag(find.text('追跡スタート'), const Offset(0, -700));
      await settle(tester, 4);
      await save(tester, '${name}_panel');
      await tester.pump(const Duration(seconds: 5)); // the arrival melody's timer
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('03:00 in Japan: moon, no good-morning', (tester) async {
    size(tester, 360, 760);
    await fonts(tester);
    japanClock = () => DateTime.utc(2026, 11, 21, 18);
    SharedPreferences.setMockInitialValues({'routes.last': '{"from":"$harajuku","to":"${id('新宿御苑前')}"}'});
    await tester.pumpWidget(app(PlatformScreen(key: UniqueKey(), city: city), 'ja'));
    await settle(tester);
    await save(tester, 'night_0300');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nearest station note', (tester) async {
    size(tester, 360, 760);
    await fonts(tester);
    final tokyo = city.station('tokyo.tokyo');
    Services.location = _FixedLocation(GpsFix(lat: tokyo.lat, lng: tokyo.lng, accuracyM: 10, time: DateTime.now()));
    await tester.pumpWidget(app(PlatformScreen(key: UniqueKey(), city: city), 'ja'));
    await settle(tester, 4);
    await tester.tap(find.bySemanticsLabel(RegExp('現在地')).first);
    await settle(tester, 3);
    await save(tester, 'nearest_note');
    // Another departure: the note goes away.
    tester.state<PlatformScreenState>(find.byType(PlatformScreen)).setStation('tokyo.shibuya', from: true);
    await settle(tester, 2);
    await save(tester, 'nearest_note_gone');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('station search: no match', (tester) async {
    size(tester, 360, 640);
    await fonts(tester);
    for (final lang in ['ja', 'ko', 'en']) {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(onPressed: () => pickStation(context, city), child: const Text('open')),
          ),
          lang,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      await save(tester, 'picker_empty_$lang');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
