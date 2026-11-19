// The three first-run tour pages, into docs/captures/onboarding/ (review).
//   flutter test test/tools/render_onboarding.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsugiwa_metro/app.dart';
import 'package:tsugiwa_metro/features/onboarding/onboarding_screen.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

void main() {
  testWidgets('render', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      // Small text uses the system font: give the test one with kana and kanji.
      final sys = FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await sys.load();
      for (final f in ['DotGothic16-Regular.ttf', 'Galmuri11.ttf', 'Galmuri11-Bold.ttf']) {
        final font = FontLoader(f.startsWith('Dot') ? 'DotGothic16' : 'Galmuri11')
          ..addFont(rootBundle.load('assets/fonts/$f'));
        await font.load();
      }
      // Material icons for the little symbols.
      // (flutter_tester lives under <flutter>/bin/cache/artifacts/engine/...).
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
    final out = Directory('docs/captures/onboarding')..createSync(recursive: true);
    for (final lang in ['ja', 'ko']) {
      // DotGothic16 has no Hangul: Galmuri11 stands in for the system font.
      final theme = buildTheme();
      final themed = lang == 'ko' ? theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Galmuri11')) : theme;
      for (var page = 0; page < 3; page++) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            theme: themed,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
            home: RepaintBoundary(
              key: key,
              child: OnboardingScreen(initialPage: page, onDone: () {}),
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.runAsync(() async {
          final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 2);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/page${page + 1}_$lang.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
    }
  });
}
