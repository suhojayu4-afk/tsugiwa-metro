import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';

void main() {
  final cat = MyCatalog.fromJson(jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>);

  test('流星号 is sold for 5,000 coins and has all its pictures', () {
    final item = cat.item('train.ryusei');
    expect(item.slot, MySlot.train);
    expect(item.price, 5000);
    expect(item.priceYen, isNull);
    expect(item.art, 'assets/art/shinkansen');
  });

  test('every train with its own shape has every picture the scene needs', () {
    for (final item in cat.inSlot(MySlot.train).where((i) => i.art != null)) {
      final art = item.art!;
      for (final f in [
        for (final p in DayPart.values) SceneArt.trainBase(p, art),
        SceneArt.trainStripeOf(art),
        SceneArt.trainWeatherOf('rain', art),
        SceneArt.trainWeatherOf('snow', art),
        '$art/side_base.webp',
        '$art/side_stripe.webp',
      ]) {
        expect(File(f).existsSync(), isTrue, reason: f);
      }
      expect(SceneArt.lampsOf(art), hasLength(2));
    }
  });
}
