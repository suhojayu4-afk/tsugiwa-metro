import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/platform/melody_player.dart';

void main() {
  test('melodies: every one has its sound file, さくら is the free default', () {
    final cat = MyCatalog.fromJson(
      jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
    );
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

  test('the arrival sound exists and the melody waits for the train to stop', () {
    expect(File(MelodyPlayer.arrivalSound).existsSync(), isTrue);
    // The arrival animation is 4.6 s; the train stops at 0.86 of it.
    expect(MelodyPlayer.melodyAfterArrival.inMilliseconds, inInclusiveRange(3900, 4600));
  });
}
