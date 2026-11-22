// のりば fixes: the attendant's bubble shows one tip at a time, names follow
// the app's language, the title never touches the coins, the station search
// says when it finds nothing, and the chosen stations come back at launch.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/app.dart';
import 'package:tsugiwa_metro/core/japan_time.dart';
import 'package:tsugiwa_metro/core/localized_text.dart';
import 'package:tsugiwa_metro/core/services.dart';
import 'package:tsugiwa_metro/data/models/city.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';
import 'package:tsugiwa_metro/data/route_store.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';
import 'package:tsugiwa_metro/features/guide/guide_card.dart';
import 'package:tsugiwa_metro/features/guide/guide_data.dart';
import 'package:tsugiwa_metro/features/my_room/my_room_screen.dart' show CoinIcon;
import 'package:tsugiwa_metro/features/platform/context_card.dart';
import 'package:tsugiwa_metro/features/platform/platform_screen.dart';
import 'package:tsugiwa_metro/features/platform/platform_texts.dart';
import 'package:tsugiwa_metro/features/platform/station_picker.dart';
import 'package:tsugiwa_metro/features/platform/weather_card.dart';
import 'package:tsugiwa_metro/features/trip/location_source.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';
import 'package:tsugiwa_metro/platform/home_widget_bridge.dart';
import 'package:tsugiwa_metro/platform/live_status_bridge.dart';

import 'trip_logic_test.dart' show loadTokyo;

class _FakeWeather implements WeatherSource {
  @override
  Future<WeatherNow> fetch(WeatherArea area) async =>
      const WeatherNow(kind: WeatherKind.sunny, tempC: 6.1, humidity: 56, rainChance: 0);
}

Widget _app(Widget home, {String lang = 'en', bool still = false}) => MaterialApp(
  locale: Locale(lang),
  theme: buildTheme(),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: Scaffold(body: home),
);

Future<void> _fonts(WidgetTester tester) => tester.runAsync(() async {
  final sys = FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
  await sys.load();
  for (final f in ['DotGothic16-Regular.ttf', 'Galmuri11.ttf', 'Galmuri11-Bold.ttf']) {
    final font = FontLoader(f.startsWith('Dot') ? 'DotGothic16' : 'Galmuri11')
      ..addFont(rootBundle.load('assets/fonts/$f'));
    await font.load();
  }
});

GuideTip _tip(String text) => GuideTip(TipKind.help, LocalizedText({'ja': text, 'ko': text, 'en': text}));

void main() {
  final CityData city = loadTokyo();
  const harajuku = 'tokyo.harajuku';
  final gyoemmae = city.stations.values.firstWhere((s) => s.name.ja == '新宿御苑前').id;

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
    // A Tuesday at noon in Japan.
    japanClock = () => DateTime.utc(2026, 11, 24, 3);
  });
  tearDown(() => japanClock = DateTime.now);

  group('the attendant\'s bubble', () {
    const short = 'Short tip.';
    const long =
        'A much longer tip that needs three lines in the bubble, so that the bubble has to grow '
        'while the old text goes away and the new one comes.';

    /// Texts of the bubble that can be seen right now (opacity above 2%).
    List<String> visible(WidgetTester tester) => [
      for (final e in find.descendant(of: find.byType(GuideCard), matching: find.byType(FadeTransition)).evaluate())
        if ((e.widget as FadeTransition).opacity.value > 0.02)
          tester.widget<Text>(find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text))).data!,
    ];

    double bubbleHeight(WidgetTester tester) => tester.getSize(find.byKey(const ValueKey('guideBubble'))).height;

    testWidgets('the old tip fades out before the new one fades in; the bubble grows smoothly', (tester) async {
      await tester.pumpWidget(_app(SizedBox(width: 320, child: GuideCard(tips: [_tip(short), _tip(long)]))));
      await tester.pump();
      expect(visible(tester), [short]);
      final small = bubbleHeight(tester);

      await tester.tap(find.byType(GuideCard));
      await tester.pump();
      final heights = <double>[];
      var sawBoth = false, sawOldOnly = false;
      for (var ms = 0; ms < 600; ms += 20) {
        await tester.pump(const Duration(milliseconds: 20));
        final now = visible(tester);
        // Never two texts over each other.
        expect(now.length, lessThanOrEqualTo(1), reason: 'at ${ms + 20} ms: $now');
        sawBoth |= find.text(short).evaluate().isNotEmpty && find.text(long).evaluate().isNotEmpty;
        sawOldOnly |= now.length == 1 && now.single == short;
        heights.add(bubbleHeight(tester));
      }
      expect(sawBoth, isTrue, reason: 'both are in the tree during the change (one of them invisible)');
      expect(sawOldOnly, isTrue, reason: 'the old tip is the one that is seen first');
      expect(visible(tester), [long]);
      expect(find.text(short), findsNothing);
      // The bubble grew step by step, not in one jump.
      final big = bubbleHeight(tester);
      expect(big, greaterThan(small + 20));
      expect(heights.where((h) => h > small + 1 && h < big - 1), isNotEmpty);
      for (var i = 1; i < heights.length; i++) {
        expect(heights[i], greaterThanOrEqualTo(heights[i - 1]));
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduce motion: the new tip replaces the old one at once', (tester) async {
      await tester.pumpWidget(
        _app(SizedBox(width: 320, child: GuideCard(tips: [_tip(short), _tip(long)])), still: true),
      );
      await tester.pump();
      final small = bubbleHeight(tester);
      await tester.tap(find.byType(GuideCard));
      await tester.pump();
      await tester.pump();
      expect(find.text(short), findsNothing);
      expect(find.text(long), findsOneWidget);
      expect(find.descendant(of: find.byType(GuideCard), matching: find.byType(FadeTransition)), findsNothing);
      expect(bubbleHeight(tester), greaterThan(small + 20));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('favourites and recent routes', () {
    testWidgets('station names follow the app language, and change with it', (tester) async {
      final store = RouteStore();
      await tester.runAsync(() async {
        await store.addFavourite(SavedRoute(harajuku, gyoemmae, kind: FavouriteKind.home));
        await store.addRecent('tokyo.shibuya', 'tokyo.ueno');
      });
      Widget card(String lang) => _app(
        ContextCard(
          city: city,
          route: null,
          fromId: null,
          toId: null,
          store: store,
          onPick: (_) {},
          onToggleFavourite: () {},
          onRemoveFavourite: (_) {},
        ),
        lang: lang,
      );
      await tester.pumpWidget(card('en'));
      await tester.pump();
      expect(find.text('Harajuku → Shinjuku-gyoemmae'), findsOneWidget);
      expect(find.text('Shibuya → Ueno'), findsOneWidget);
      expect(find.textContaining('原宿'), findsNothing);
      // The language is changed in the settings: the same card, redrawn.
      await tester.pumpWidget(card('ko'));
      await tester.pump();
      expect(find.text('하라주쿠 → 신주쿠교엔마에'), findsOneWidget);
      expect(find.text('시부야 → 우에노'), findsOneWidget);
      await tester.pumpWidget(card('ja'));
      await tester.pump();
      expect(find.text('原宿 → 新宿御苑前'), findsOneWidget);
    });

    testWidgets('the next-train card shows the route\'s last departure (00:09)', (tester) async {
      final route = RouteFinder(city).find(harajuku, gyoemmae)!;
      await tester.pumpWidget(
        _app(
          ContextCard(
            city: city,
            route: route,
            fromId: harajuku,
            toId: gyoemmae,
            store: RouteStore(),
            onPick: (_) {},
            onToggleFavourite: () {},
            onRemoveFavourite: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Last train around 00:09'), findsOneWidget);
      expect(find.textContaining('01:00'), findsNothing);
    });
  });

  group('header', () {
    for (final lang in ['en', 'ja', 'ko']) {
      for (final (width, scale) in [(320.0, 1.3), (320.0, 1.0), (412.0, 1.3)]) {
        testWidgets('$lang: the title keeps clear of the coins at ${width.round()} px × $scale', (tester) async {
          tester.view.physicalSize = Size(width * 2, 1600);
          tester.view.devicePixelRatio = 2;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          // The app's own fonts: the test font is far wider than they are.
          await _fonts(tester);
          await tester.pumpWidget(_app(PlatformScreen(city: city), lang: lang));
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull);
          final title = tester.getRect(find.byType(AppTitle));
          final coins = tester.getRect(
            find.ancestor(of: find.byType(CoinIcon), matching: find.byType(GestureDetector)).first,
          );
          expect(title.left, greaterThanOrEqualTo(20));
          expect(title.right, lessThanOrEqualTo(coins.left - 8), reason: 'title $title, coins $coins');
          expect(coins.right, lessThanOrEqualTo(width - 20));
          // One line, whole (shrunk when it has to be).
          expect(title.height, lessThan(30 * scale * 1.9));
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  });

  group('station search', () {
    Future<void> open(WidgetTester tester, String lang) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(onPressed: () => pickStation(context, city), child: const Text('open')),
          ),
          lang: lang,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('no match: a friendly line with a hint, in every language', (tester) async {
      const texts = {'ja': ('見つかりませんでした', 'ひらがな'), 'ko': ('찾지 못했어요', '로마자'), 'en': ('No stations found', 'romaji')};
      for (final lang in texts.keys) {
        await open(tester, lang);
        expect(find.byKey(const ValueKey('searchNoMatch')), findsNothing);
        await tester.enterText(find.byType(TextField), 'zzzzqq');
        await tester.pump();
        expect(find.text(texts[lang]!.$1), findsOneWidget);
        expect(searchNoMatchHint.of(lang), contains(texts[lang]!.$2));
        expect(find.text(searchNoMatchHint.of(lang)), findsOneWidget);
        // A real name: the list is back.
        await tester.enterText(find.byType(TextField), 'shibuya');
        await tester.pump();
        expect(find.byKey(const ValueKey('searchNoMatch')), findsNothing);
        expect(find.text('渋谷'), findsWidgets);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('the chosen stations', () {
    Future<void> launch(WidgetTester tester, {String lang = 'ja'}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          PlatformScreen(key: UniqueKey(), city: city),
          lang: lang,
        ),
      );
      // The store reads the phone's preferences.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('come back after a restart', (tester) async {
      SharedPreferences.setMockInitialValues({'routes.last': '{"from":"$harajuku","to":"$gyoemmae"}'});
      await launch(tester);
      expect(find.text('駅をえらぶ'), findsNothing);
      expect(find.text('原宿'), findsWidgets);
      expect(find.text('新宿御苑前'), findsWidgets);
      // The train pulled in: its melody comes a few seconds later.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('nothing chosen last time: nothing chosen now', (tester) async {
      await launch(tester);
      expect(find.text('駅をえらぶ'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a choice is remembered, and so is clearing the destination by a swap', (tester) async {
      await launch(tester);
      final state = tester.state<PlatformScreenState>(find.byType(PlatformScreen));
      state.setStation(harajuku, from: true);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      final again = RouteStore();
      await tester.runAsync(again.load);
      expect(again.lastFromId, harajuku);
      expect(again.lastToId, isNull);
      // A station that no longer exists is not put back.
      await tester.pumpWidget(const SizedBox());
      SharedPreferences.setMockInitialValues({'routes.last': '{"from":"tokyo.gone","to":"$gyoemmae"}'});
      Services.routes = RouteStore();
      await launch(tester);
      expect(find.text('駅をえらぶ'), findsOneWidget);
      expect(find.text('新宿御苑前'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('原宿 → 乃木坂: the preview says to walk to 明治神宮前', (tester) async {
      final nogizaka = city.stations.values.firstWhere((s) => s.name.ja == '乃木坂').id;
      SharedPreferences.setMockInitialValues({'routes.last': '{"from":"$harajuku","to":"$nogizaka"}'});
      await launch(tester);
      // The preview is in the panel, under the start button.
      final walk = find.textContaining('明治神宮前まで歩く', skipOffstage: false);
      expect(walk, findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('weather icon', () {
    test('a moon after dark for clear and cloudy skies', () {
      expect(WeatherIcon.assetFor('sunny', night: false).$1, 'assets/art/weather_sunny.webp');
      expect(WeatherIcon.assetFor('sunny', night: true).$1, 'assets/art/widget/icon_moon.webp');
      expect(WeatherIcon.assetFor('cloudy', night: true).$1, 'assets/art/widget/icon_mooncloud.webp');
      expect(WeatherIcon.assetFor('rain', night: true).$1, 'assets/art/weather_rain.webp');
    });

    testWidgets('03:00 in Japan: the card shows the moon', (tester) async {
      japanClock = () => DateTime.utc(2026, 11, 21, 18); // 03:00 on the 22nd in Japan
      await tester.pumpWidget(_app(WeatherCard(area: city.weather!)));
      await tester.pump(const Duration(milliseconds: 50));
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, 'assets/art/widget/icon_moon.webp');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
