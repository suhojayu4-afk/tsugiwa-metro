import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/app.dart';
import 'package:tsugiwa_metro/features/onboarding/onboarding_screen.dart';
import 'package:tsugiwa_metro/features/settings/app_language.dart';
import 'package:tsugiwa_metro/features/settings/font_licenses.dart';
import 'package:tsugiwa_metro/features/settings/legal_texts.dart';
import 'package:tsugiwa_metro/features/settings/settings_screen.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

/// A small phone (360×640) with large text (×1.3), in [lang].
Widget _app(String lang, Widget home) => MaterialApp(
  locale: Locale(lang),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
    child: child!,
  ),
  home: home,
);

void _smallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Lets real file reads (licence texts) finish, then draws.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls the page on top to its end and back, so every part is laid out.
Future<void> _scrollThrough(WidgetTester tester) async {
  final list = find.byType(Scrollable).last;
  for (var i = 0; i < 60; i++) {
    final position = tester.state<ScrollableState>(list).position;
    if (position.pixels >= position.maxScrollExtent) break;
    position.jumpTo((position.pixels + 400).clamp(0, position.maxScrollExtent));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
  tester.state<ScrollableState>(list).position.jumpTo(0);
  await tester.pump();
}

/// The app bar's back arrow.
void _back(WidgetTester tester) {
  expect(find.byType(BackButton), findsOneWidget);
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLanguage.override.value = null;
    // As main() does at startup. (Without the packages' own licences: their
    // NOTICES file is not readable in a widget test.)
    LicenseRegistry.reset();
    registerFontLicenses();
  });

  for (final lang in ['ja', 'ko', 'en']) {
    testWidgets('settings ($lang): every row opens its page, nothing overflows on a small phone', (tester) async {
      _smallPhone(tester);
      await tester.pumpWidget(_app(lang, const Scaffold(body: Center(child: SettingsGearButton()))));
      await tester.tap(find.byType(SettingsGearButton));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text(settingsTitle.of(lang)), findsOneWidget);
      expect(find.text(appVersion), findsOneWidget);
      await _scrollThrough(tester);
      expect(tester.takeException(), isNull);

      // The three text pages.
      for (final (key, doc) in [
        ('settings.privacy', privacyDoc),
        ('settings.terms', termsDoc),
        ('settings.credits', creditsDoc),
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(find.byType(LegalPage), findsOneWidget);
        expect(find.widgetWithText(AppBar, doc.title.of(lang)), findsOneWidget);
        expect(find.text(doc.sections.first.heading.of(lang)), findsOneWidget);
        await _scrollThrough(tester);
        expect(tester.takeException(), isNull);
        _back(tester);
        await tester.pumpAndSettle();
      }

      // Licences: the fonts lead the list and open their OFL text.
      await tester.ensureVisible(find.byKey(const ValueKey('settings.licenses')));
      await tester.tap(find.byKey(const ValueKey('settings.licenses')));
      await _settle(tester);
      expect(find.byType(LicensesPage), findsOneWidget);
      for (final font in fontLicenses.keys) {
        expect(find.text(font), findsOneWidget);
      }
      await _scrollThrough(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(fontLicenses.keys.first));
      await tester.pumpAndSettle();
      expect(find.byType(LicenseTextPage), findsOneWidget);
      expect(find.textContaining('SIL Open Font License'), findsWidgets);
      await _scrollThrough(tester);
      expect(tester.takeException(), isNull);
      _back(tester);
      await tester.pumpAndSettle();
      _back(tester);
      await tester.pumpAndSettle();

      // Language: the sheet opens with the four choices.
      await tester.ensureVisible(find.byKey(const ValueKey('settings.language')));
      await tester.tap(find.byKey(const ValueKey('settings.language')));
      await tester.pumpAndSettle();
      for (final code in ['device', 'ja', 'ko', 'en']) {
        expect(find.byKey(ValueKey('settings.lang.$code')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('settings.lang.ko')));
      await tester.pumpAndSettle();
      expect(AppLanguage.override.value, 'ko');
      expect((await SharedPreferences.getInstance()).getString(AppLanguage.key), 'ko');
      expect(find.text('한국어'), findsOneWidget);
    });
  }

  testWidgets('the picked language is saved and the whole app follows it', (tester) async {
    await tester.pumpWidget(const TsugiwaApp());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    Locale shown() => Localizations.localeOf(tester.element(find.byType(OnboardingScreen)));
    expect(shown().languageCode, 'en'); // the test device's language

    await AppLanguage.set('ko');
    await tester.pump();
    expect(shown().languageCode, 'ko');

    // Read back as on the next start.
    AppLanguage.override.value = null;
    await AppLanguage.load();
    expect(AppLanguage.override.value, 'ko');
    await tester.pump();

    await AppLanguage.set(null);
    await tester.pump();
    expect(shown().languageCode, 'en');
    expect((await SharedPreferences.getInstance()).getString(AppLanguage.key), isNull);
  });

  testWidgets('the OFL texts of the bundled fonts are in the LicenseRegistry', (tester) async {
    final found = <String, int>{};
    await tester.runAsync(() async {
      await for (final entry in LicenseRegistry.licenses) {
        for (final package in entry.packages) {
          if (!fontLicenses.containsKey(package)) continue;
          final text = entry.paragraphs.map((p) => p.text).join('\n');
          expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
          expect(text, contains('Copyright'));
          expect(text, isNot(contains('&copy;')));
          found[package] = (found[package] ?? 0) + 1;
        }
      }
    });
    expect(found, {for (final font in fontLicenses.keys) font: 1});
  });

  test('every font in the app has its licence file', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/fonts/licenses/'));
    for (final family in RegExp(r'- family: (\w+)').allMatches(pubspec).map((m) => m[1]!)) {
      expect(fontLicenses.keys.any((k) => k.startsWith(family)), isTrue, reason: '$family has no licence entry');
    }
    for (final path in fontLicenses.values) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('the version shown is the one in pubspec.yaml', () {
    final version = RegExp(r'^version: ([\d.]+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(appVersion, version![1]);
  });

  test('credits name every site the car guide was taken from', () {
    final hosts = <String>{};
    for (final file in Directory('assets/cities').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('cars.json')) continue;
      for (final m in RegExp(r'"source":\s*"([^"]+)"').allMatches(file.readAsStringSync())) {
        hosts.add(Uri.tryParse(m[1]!)?.host ?? m[1]!);
      }
    }
    expect(hosts, isNotEmpty);
    expect(hosts.difference(carGuideSources.toSet()), isEmpty);
    final section = creditsDoc.sections.firstWhere((s) => s.body.ja.contains(carGuideSources.first));
    for (final lang in ['ja', 'ko', 'en']) {
      for (final host in hosts) {
        expect(section.body.of(lang), contains(host));
      }
    }
  });

  test('every text exists in ja, ko and en; the contact is never blank', () {
    for (final doc in [privacyDoc, termsDoc, creditsDoc]) {
      for (final text in [
        doc.title,
        doc.lead,
        for (final s in doc.sections) ...[s.heading, s.body],
      ]) {
        expect(text.values.keys.toSet(), {'ja', 'ko', 'en'});
      }
    }
    for (final lang in ['ja', 'ko', 'en']) {
      expect(contactFor(lang).trim(), isNotEmpty);
    }
  });
}
