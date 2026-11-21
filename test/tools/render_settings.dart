// 設定 previews into docs/captures/settings/ (review): the settings list,
// the privacy policy, the data credits and the licences.
//   flutter test test/tools/render_settings.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/app.dart';
import 'package:tsugiwa_metro/features/settings/app_language.dart';
import 'package:tsugiwa_metro/features/settings/font_licenses.dart';
import 'package:tsugiwa_metro/features/settings/legal_texts.dart';
import 'package:tsugiwa_metro/features/settings/settings_screen.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

void main() {
  testWidgets('render', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppLanguage.override.value = null;
    await tester.runAsync(() async {
      // The pixel font stands in for the system font too (it has ja + Latin;
      // Galmuri covers Korean).
      for (final family in ['Roboto', 'DotGothic16', 'Galmuri11']) {
        final font = FontLoader(family)
          ..addFont(
            rootBundle.load(
              family == 'Galmuri11' ? 'assets/fonts/Galmuri11.ttf' : 'assets/fonts/DotGothic16-Regular.ttf',
            ),
          );
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
    });
    final out = Directory('docs/captures/settings')..createSync(recursive: true);

    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shot(String lang, Widget page, String name, {double height = 760, double scale = 1}) async {
      tester.view.physicalSize = Size(720, height * 2);
      tester.view.devicePixelRatio = 2;
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(name),
          debugShowCheckedModeBanner: false,
          // Stand-in for the phone's own font, which has every language.
          theme: buildTheme().copyWith(
            textTheme: buildTheme().textTheme.apply(fontFamily: 'DotGothic16', fontFamilyFallback: ['Galmuri11']),
          ),
          locale: Locale(lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(key: key, child: page),
        ),
      );
      await settle();
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 2);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    addTearDown(tester.view.reset);
    LicenseRegistry.reset();
    registerFontLicenses();
    for (final lang in ['ja', 'ko', 'en']) {
      await shot(lang, const SettingsScreen(), 'settings_$lang', height: 640);
    }
    await shot('en', const SettingsScreen(), 'settings_en_large_text', height: 640, scale: 1.3);
    await shot('ja', const LegalPage(doc: privacyDoc), 'privacy_ja', height: 2500);
    await shot('en', const LegalPage(doc: privacyDoc), 'privacy_en', height: 2500);
    await shot('ja', const LegalPage(doc: termsDoc), 'terms_ja', height: 1300);
    await shot('ko', const LegalPage(doc: creditsDoc), 'credits_ko', height: 1700);
    await shot('en', const LicensesPage(), 'licences_en', height: 420);
    late final List<LicenseEntry> ofl;
    await tester.runAsync(() async {
      ofl = [
        await for (final e in LicenseRegistry.licenses)
          if (e.packages.contains(fontLicenses.keys.first)) e,
      ];
    });
    await shot('en', LicenseTextPage(name: fontLicenses.keys.first, entries: ofl), 'licence_text_en', height: 900);
  });
}
