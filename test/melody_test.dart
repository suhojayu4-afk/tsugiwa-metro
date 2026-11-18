import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';

void main() {
  test('melodies: every one has its sound file, さくら is the free default', () {
    final cat = MyCatalog.fromJson(jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>);
    final melodies = cat.inSlot(MySlot.melody);
    expect(melodies.length, greaterThanOrEqualTo(4));
    expect(cat.defaultFor(MySlot.melody), 'melody.sakura');
    for (final m in melodies) {
      if (m.id == 'melody.off') {
        expect(m.sound, isNull);
        continue;
      }
      expect(File(m.sound!).existsSync(), isTrue, reason: m.id);
    }
  });
}
