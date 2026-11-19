// The three share cards with sample rides, into docs/captures/share_cards/
// (review).   flutter test test/tools/render_share_cards.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/core/services.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';
import 'package:tsugiwa_metro/features/my_room/share_card.dart';
import 'package:tsugiwa_metro/features/my_room/station_plate.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

import '../platform_features_test.dart' show loadTokyo;

void main() {
  testWidgets('render', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final city = loadTokyo();
    late final List<(ShareStyle, String, GlobalKey)> cards;
    await tester.runAsync(() async {
      // Small text uses the system font: give the test one with kana and kanji.
      final sys = FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await sys.load();
      for (final f in ['DotGothic16-Regular.ttf', 'Galmuri11.ttf']) {
        final font = FontLoader(f.startsWith('Dot') ? 'DotGothic16' : 'Galmuri11')
          ..addFont(rootBundle.load('assets/fonts/$f'));
        await font.load();
      }
      final catalog = MyCatalog.fromJson(
        jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
      );
      final store = MyStore()..lines = {for (final l in city.lines) l.id: l.stations};
      await store.load(catalog: catalog);
      final yamanote = city.line('tokyo.yamanote');
      final ginza = city.line('tokyo.ginza');
      for (var d = 1; d <= 18; d++) {
        await store.rewardTrip(
          yamanote.stations.skip(d % 10).take(6).toList(),
          now: DateTime(2026, 11, d, 7, 30 + d),
          ridden: [yamanote.id],
        );
        if (d.isEven) {
          await store.rewardTrip(
            ginza.stations.take(5).toList(),
            now: DateTime(2026, 11, d, 23, 50),
            ridden: [ginza.id],
          );
        }
      }
      Services.my = store;
      cards = [for (final s in ShareStyle.values) (s, s.name, GlobalKey())];
    });
    for (final lang in ['ja', 'ko']) {
      for (final (style, name, key) in cards) {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
            home: Material(
              child: Center(
                child: RepaintBoundary(
                  key: key,
                  child: ShareCard(
                    city: city,
                    plate: const PlateData(name: '桜坂', kana: 'さくらざか'),
                    lineColor: const Color(0xFF80C241),
                    style: style,
                    now: DateTime(2026, 11, 19, 12),
                  ),
                ),
              ),
            ),
          ),
        );
        // Let the pixel scene and pictures load.
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.runAsync(() async {
          final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 2);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          final out = Directory('docs/captures/share_cards')..createSync(recursive: true);
          File('${out.path}/${name}_$lang.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
    }
  });
}
