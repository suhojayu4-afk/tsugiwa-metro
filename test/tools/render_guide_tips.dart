// The attendant's bubble with the longest tips of each language, to look
// for clipping: docs/captures/guide_tips/*.png
//   flutter test test/tools/render_guide_tips.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsugiwa_metro/app.dart';
import 'package:tsugiwa_metro/core/localized_text.dart';
import 'package:tsugiwa_metro/features/guide/guide_card.dart';
import 'package:tsugiwa_metro/features/guide/guide_data.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

import '../trip_logic_test.dart' show loadTokyo;

int _halfWidths(String s) => s.runes.fold(0, (n, r) => n + (r < 0x2000 ? 1 : 2));

void main() {
  testWidgets('render', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final sys = FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await sys.load();
      for (final f in ['DotGothic16-Regular.ttf', 'Galmuri11.ttf', 'Galmuri11-Bold.ttf']) {
        final font = FontLoader(f.startsWith('Dot') ? 'DotGothic16' : 'Galmuri11')
          ..addFont(rootBundle.load('assets/fonts/$f'));
        await font.load();
      }
    });
    final city = loadTokyo();
    Object read(String f) => jsonDecode(File('assets/cities/tokyo/$f').readAsStringSync()) as Object;
    final data = GuideData.fromJson(
      tips: read('tips.json') as Map<String, dynamic>,
      pool: read('attendant_tips.json') as List<dynamic>,
    );
    final station = <GuideTip>[
      for (final e in data.stationTips.entries)
        for (final t in e.value)
          GuideTip(
            TipKind.help,
            LocalizedText({
              'ja': '${city.station(e.key).name.of('ja')}：${t.of('ja')}',
              'ko': '${city.station(e.key).name.of('ko')}: ${t.of('ko')}',
              'en': '${city.station(e.key).name.of('en')}: ${t.of('en')}',
            }),
          ),
    ];
    final out = Directory('docs/captures/guide_tips')..createSync(recursive: true);
    for (final lang in ['ja', 'ko', 'en']) {
      List<GuideTip> longest(Iterable<GuideTip> of, int n) =>
          (of.toList()..sort((a, b) => _halfWidths(b.text.of(lang)) - _halfWidths(a.text.of(lang)))).take(n).toList();
      final shown = [
        ...longest(station, 4),
        ...longest(data.pool.where((p) => p.kind != TipKind.warn), 3),
        ...longest(data.pool.where((p) => p.kind == TipKind.warn), 2),
      ];
      final theme = buildTheme();
      final themed = lang == 'ko' ? theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Galmuri11')) : theme;
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          theme: themed,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          home: Scaffold(
            backgroundColor: const Color(0xFFF4F4F1),
            body: Align(
              alignment: Alignment.topCenter,
              child: RepaintBoundary(
                key: key,
                child: Container(
                  // The platform screen on a 360dp phone: 20 at each side.
                  width: 360,
                  color: const Color(0xFFF4F4F1),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  // DotGothic16 has no Hangul: Galmuri11 stands in for the system font.
                  child: DefaultTextStyle.merge(
                    style: TextStyle(fontFamily: lang == 'ko' ? 'Galmuri11' : null),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final t in shown) GuideCard(key: ValueKey('$lang${t.key}'), tips: [t]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // The attendant's picture.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 2);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/longest_$lang.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    // The cards' timers.
    await tester.pumpWidget(const SizedBox());
  });
}
