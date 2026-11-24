// 名所をさがす and the landmark card with 「ここへ行く」, as pictures:
//   MAP_CITY=osaka flutter test test/tools/render_sights.dart  ->  docs/captures/sights/
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsugiwa_metro/app.dart';
import 'package:tsugiwa_metro/core/localized_text.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_ui.dart';
import 'package:tsugiwa_metro/data/models/route_map.dart';
import 'package:tsugiwa_metro/features/route_map/landmark_sheet.dart';
import 'package:tsugiwa_metro/l10n/app_localizations.dart';

import '../new_cities_test.dart' show loadCity;

void main() {
  testWidgets('render', (tester) async {
    final id = Platform.environment['MAP_CITY'] ?? 'osaka';
    final city = loadCity(id);
    final map = RouteMapData.fromJson(
      jsonDecode(File('assets/cities/$id/map.json').readAsStringSync()) as Map<String, dynamic>,
      const {},
    );
    final raw = jsonDecode(File('assets/cities/$id/landmarks.json').readAsStringSync()) as Map<String, dynamic>;
    final info = <String, LandmarkInfo>{
      for (final e in raw.entries)
        e.key: (
          about: LocalizedText.fromJson((e.value as Map<String, dynamic>)['about'] as Map<String, dynamic>),
          stations: [for (final s in (e.value as Map<String, dynamic>)['stations'] as List) s as String],
        ),
    };
    final images = <String, ui.Image>{};
    await tester.runAsync(() async {
      for (final f in ['DotGothic16-Regular.ttf', 'Galmuri11.ttf']) {
        final font = FontLoader(f.startsWith('Dot') ? 'DotGothic16' : 'Galmuri11')
          ..addFont(rootBundle.load('assets/fonts/$f'));
        await font.load();
      }
      final sys = FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
      await sys.load();
      for (final lm in map.landmarks) {
        final codec = await ui.instantiateImageCodec(File(lm.image).readAsBytesSync());
        images[lm.image] = (await codec.getNextFrame()).image;
      }
    });
    final out = Directory('docs/captures/sights')..createSync(recursive: true);
    tester.view.physicalSize = const Size(780, 1500);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    Future<void> shot(String name) => tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
    Widget app(String lang, Widget body) {
      final theme = buildTheme();
      return RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(lang),
          theme: lang == 'ko' ? theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Galmuri11')) : theme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          home: Scaffold(
            backgroundColor: PixelColors.card,
            body: SafeArea(child: body),
          ),
        ),
      );
    }

    for (final lang in ['ko', 'ja']) {
      await tester.pumpWidget(app(lang, SightsSheet(city: city, landmarks: map.landmarks, images: images, info: info)));
      await tester.pump();
      await shot('${id}_list_$lang');
      final lm = map.landmarks.first;
      await tester.pumpWidget(
        app(lang, LandmarkSheet(city: city, landmark: lm, image: images[lm.image], info: info[landmarkKey(lm)])),
      );
      await tester.pump();
      await shot('${id}_card_$lang');
    }
  });
}
