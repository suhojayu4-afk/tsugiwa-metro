import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/app.dart';
import 'package:tsugiwa_metro/core/services.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/features/my_room/my_room_screen.dart';
import 'package:tsugiwa_metro/features/onboarding/onboarding_screen.dart';
import 'package:tsugiwa_metro/data/my_store.dart';
import 'package:tsugiwa_metro/platform/home_widget_bridge.dart';
import 'package:tsugiwa_metro/data/route_store.dart';
import 'package:tsugiwa_metro/platform/live_status_bridge.dart';
import 'package:tsugiwa_metro/data/weather/weather_source.dart';
import 'package:tsugiwa_metro/features/trip/location_source.dart';

class _FakeWeather implements WeatherSource {
  @override
  Future<WeatherNow> fetch(WeatherArea area) async =>
      const WeatherNow(kind: WeatherKind.sunny, tempC: 18.5, humidity: 55, rainChance: 10);
}

void main() {
  setUp(() {
    // A returning user: the first-run tour (test/onboarding_test.dart) is done.
    SharedPreferences.setMockInitialValues({OnboardingFlag.key: true});
    Services.routes = RouteStore();
    // Each test has its own fake async zone: start with empty asset caches.
    rootBundle.clear();
    MyCatalog.resetCache();
    Services.my = MyStore();
    Services.homeWidget = const NoHomeWidget();
    Services.weather = _FakeWeather();
    Services.live = const NoopLiveStatusBridge();
    Services.location = const NoLocationSource();
  });

  testWidgets('platform tab: weather, location button and three bottom tabs', (tester) async {
    // Phone-sized screen (360×800) so the whole platform tab is visible.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TsugiwaApp());
    // City JSON loads with real I/O; let it finish, then draw the frame.
    // (pumpAndSettle can't be used: the pixel train animates forever.)
    final title = find.text('Tsugiwa Metro', findRichText: true);
    for (var i = 0; i < 100 && title.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 50)); // weather card result
    // Test locale is en-US, so the English strings appear.
    expect(title, findsOneWidget);
    expect(find.text('18.5℃'), findsOneWidget);
    expect(find.text('55%'), findsOneWidget);
    expect(find.text('Platform'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('MY'), findsOneWidget);
    // The station attendant's tip sits under the picture: first, the
    // first-ride guide for someone new.
    expect(find.textContaining('New to Japanese trains?'), findsOneWidget);
    // No saved routes yet: the card explains how to add one (further down).
    final hint = find.text('Pick a route and tap ☆ to save it here');
    await tester.scrollUntilVisible(hint, 120, scrollable: find.byType(Scrollable).first);
    expect(hint, findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pump();

    // Location refused → a friendly message instead of a crash.
    // The route panel sits at the bottom: pin button, then the start button.
    await tester.tap(find.bySemanticsLabel('From my location'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Location is off. Please allow it in Settings'), findsOneWidget);

    expect(find.text('Start tracking'), findsOneWidget);

    await tester.tap(find.text('Map'));
    // The route map loads its data and pictures, then shows the line legend.
    final legend = find.text('Tokyo Metro'); // company chips (each opens its lines)
    final fit = find.bySemanticsLabel('Whole map');
    for (var i = 0; i < 100 && fit.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(legend, findsOneWidget);
    expect(fit, findsOneWidget);
  });

  testWidgets('のりば → MY: the coin chip opens the coin shop', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TsugiwaApp());
    final title = find.text('Tsugiwa Metro', findRichText: true);
    for (var i = 0; i < 100 && title.evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    // The MY store loads its catalog from assets.
    for (var i = 0; i < 40 && !Services.my.loaded; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Coins (0 for a new user) sit in the header; tapping opens the shop in MY.
    await tester.tap(find.byType(CoinIcon).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('MY Station'), findsOneWidget);
    expect(find.text('Get coins'), findsWidgets);
  });
}
