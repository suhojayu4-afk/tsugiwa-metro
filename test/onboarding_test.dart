import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/features/onboarding/onboarding_screen.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

/// The gate around a stand-in for the app, in English (the test locale).
Widget _app() => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
  home: const OnboardingGate(child: Scaffold(body: Text('THE APP'))),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<bool?> _flag() async => (await SharedPreferences.getInstance()).getBool(OnboardingFlag.key);

/// Phone-sized screen (360×800).
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('first run: the tour shows; Skip marks it seen and opens the app', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    await _settle(tester);
    expect(find.text('Save your usual trips with ☆'), findsOneWidget);
    expect(find.text('THE APP'), findsNothing);

    await tester.tap(find.text('Skip'));
    await _settle(tester);
    expect(find.text('THE APP'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(await _flag(), isTrue);
  });

  testWidgets('Next walks the three pages (swipe too); Get started finishes', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    await _settle(tester);

    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(find.text('Never miss the last train'), findsOneWidget);

    // Swipe left to the last page.
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await _settle(tester);
    expect(find.text('Your station, everywhere'), findsOneWidget);
    expect(find.text('Next'), findsNothing);

    await tester.tap(find.text('Get started'));
    await _settle(tester);
    expect(find.text('THE APP'), findsOneWidget);
    expect(await _flag(), isTrue);
  });

  testWidgets('already seen: straight into the app', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({OnboardingFlag.key: true});
    await tester.pumpWidget(_app());
    await _settle(tester);
    expect(find.text('THE APP'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}
