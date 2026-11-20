// 乗換便利号車 card for a few routes, for review: docs/captures/car_guide/*.png
//   flutter test test/tools/render_car_guide.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsugiwa_metro/app.dart';
import 'package:tsugiwa_metro/data/car_guide.dart';
import 'package:tsugiwa_metro/data/models/city.dart';
import 'package:tsugiwa_metro/features/platform/car_guide_card.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

CityData _tokyo() {
  dynamic read(String f) => jsonDecode(File('assets/cities/tokyo/$f').readAsStringSync());
  return CityData.fromJson(
    city: read('city.json') as Map<String, dynamic>,
    stations: read('stations.json') as List<dynamic>,
    lines: read('lines.json') as List<dynamic>,
    timetables: read('timetables.json') as Map<String, dynamic>,
    walks: read('walks.json') as List<dynamic>,
    throughs: read('through.json') as List<dynamic>,
  );
}

void main() {
  testWidgets('render', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
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
    final city = _tokyo();
    final guide = CarGuide.fromJson(
      jsonDecode(File('assets/cities/tokyo/cars.json').readAsStringSync()) as Map<String, dynamic>,
    );
    final routes = <String, RouteResult>{
      // 外回り 渋谷 → 新宿, then Keio: change + (no Keio data) nothing more.
      'shibuya_shinjuku_keio': const RouteResult([
        RouteLeg(
          lineId: 'tokyo.yamanote',
          forward: false,
          stationIds: ['tokyo.shibuya', 'tokyo.harajuku', 'tokyo.yoyogi', 'tokyo.shinjuku'],
        ),
        RouteLeg(lineId: 'tokyo.keio', forward: true, stationIds: ['tokyo.shinjuku', 'tokyo.sasazuka']),
      ]),
      // 内回り 池袋 → 新宿 (arrival gate).
      'ikebukuro_shinjuku': const RouteResult([
        RouteLeg(
          lineId: 'tokyo.yamanote',
          forward: true,
          stationIds: ['tokyo.ikebukuro', 'tokyo.mejiro', 'tokyo.takadanobaba', 'tokyo.shin_okubo', 'tokyo.shinjuku'],
        ),
      ]),
      // 内回り 上野 → 秋葉原, 総武線 to 千葉方面, plus Ginza Line arrival at 渋谷.
      'two_changes': const RouteResult([
        RouteLeg(
          lineId: 'tokyo.yamanote',
          forward: true,
          stationIds: ['tokyo.ueno', 'tokyo.okachimachi', 'tokyo.akihabara'],
        ),
        RouteLeg(lineId: 'tokyo.chuo_sobu', forward: true, stationIds: ['tokyo.akihabara', 'tokyo.asakusabashi']),
      ]),
      'ginza_shibuya': const RouteResult([
        RouteLeg(lineId: 'tokyo.ginza', forward: false, stationIds: ['tokyo.omotesando', 'tokyo.shibuya']),
      ]),
    };
    final out = Directory('docs/captures/car_guide')..createSync(recursive: true);
    for (final lang in ['ja', 'ko', 'en']) {
      final theme = buildTheme();
      final themed = lang == 'ko' ? theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Galmuri11')) : theme;
      for (final r in routes.entries) {
        if (lang != 'ja' && r.key != 'shibuya_shinjuku_keio') continue;
        final advice = guide.forRoute(r.value);
        expect(advice, isNotEmpty, reason: r.key);
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
                    width: 360,
                    color: const Color(0xFFF4F4F1),
                    padding: const EdgeInsets.all(12),
                    // DotGothic16 has no Hangul: Galmuri11 stands in for the system font.
                    child: DefaultTextStyle.merge(
                      style: TextStyle(fontFamily: lang == 'ko' ? 'Galmuri11' : null),
                      child: CarGuideCard(city: city, advice: advice),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(() async {
          final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 2);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/${r.key}_$lang.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
    }
  });
}
