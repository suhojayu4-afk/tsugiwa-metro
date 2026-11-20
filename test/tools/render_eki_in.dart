// 駅印帳 sample pages for real Tokyo stations, into docs/captures/eki_in/
// (review).   flutter test test/tools/render_eki_in.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsugiwa_metro/features/my_room/eki_in_book.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

import '../platform_features_test.dart' show loadTokyo;

void main() {
  testWidgets('render', (tester) async {
    final city = loadTokyo();
    await tester.runAsync(() async {
      // Small text uses the system font: give the test one with kana and kanji.
      final sys = FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await sys.load();
      final dot = FontLoader('DotGothic16')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await dot.load();
      await EkiInArt.load();
    });

    EkiInEntry page(String id, String day, {String? line, EkiInMark mark = EkiInMark.ride, int n = 1}) {
      final s = city.station('tokyo.$id');
      return EkiInEntry(
        station: s,
        line: city.line(line ?? s.lines.first),
        day: DateTime.parse(day),
        number: n,
        mark: mark,
      );
    }

    final samples = <String, EkiInEntry>{
      'shibuya': page('shibuya', '2026-11-21', line: 'tokyo.yamanote', n: 12),
      'asakusa': page('asakusa', '2026-10-03', line: 'tokyo.ginza', mark: EkiInMark.alight, n: 8),
      'takanawa_gateway': page('takanawa_gateway', '2026-09-14', line: 'tokyo.yamanote', n: 5),
      'nihombashi': page('nihombashi', '2026-08-02', line: 'tokyo.ginza', n: 3),
      'sakuragicho': page('sakuragicho', '2026-04-05', line: 'tokyo.keihin_tohoku', mark: EkiInMark.alight, n: 1),
      'tokyo_skytree': page('tokyo_skytree', '2026-12-24', n: 31),
      'complete_yamanote': EkiInEntry(
        line: city.line('tokyo.yamanote'),
        day: DateTime(2026, 11, 21),
        mark: EkiInMark.complete,
      ),
    };

    final out = Directory('docs/captures/eki_in')..createSync(recursive: true);
    for (final MapEntry(key: name, value: entry) in samples.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Material(
            color: const Color(0xFF232A43),
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 300,
                  height: 440,
                  child: EkiInPage(entry: entry, city: city),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 3);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/${name}_ja.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    // The book screen with a few real stamps (Ginza line complete).
    final ginza = city.line('tokyo.ginza');
    final stamps = <String, String>{
      for (final (i, s) in ginza.stations.indexed) s: '2026-11-${(1 + i).toString().padLeft(2, '0')}',
      'tokyo.shibuya': '2026-10-30',
    };
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final screenKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('ja'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          home: EkiInBookScreen(city: city, stamps: stamps),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final b = screenKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/book_screen_ja.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
