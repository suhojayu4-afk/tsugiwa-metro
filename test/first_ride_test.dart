import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/core/services.dart';
import 'package:tsugiwa_metro/data/my_catalog.dart';
import 'package:tsugiwa_metro/data/my_store.dart';
import 'package:tsugiwa_metro/features/guide/first_ride_data.dart';
import 'package:tsugiwa_metro/features/guide/first_ride_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every chapter has its words in three languages', () {
    for (final c in firstRideChapters) {
      for (final lang in ['ja', 'ko', 'en']) {
        expect(c.title.values[lang], isNotEmpty, reason: '${c.id} $lang');
        expect(c.lead.values[lang], isNotEmpty, reason: '${c.id} $lang');
        for (final s in c.steps) {
          expect(s.values[lang], isNotEmpty, reason: '${c.id} $lang');
        }
      }
      expect(c.steps.isNotEmpty || c.phrases.isNotEmpty, isTrue, reason: c.id);
    }
  });

  test('country trains come early in Tottori, late in Tokyo', () {
    final tottori = firstRideChaptersFor('tottori').map((c) => c.id).toList();
    final tokyo = firstRideChaptersFor('tokyo').map((c) => c.id).toList();
    expect(tottori.indexOf('country'), lessThan(tokyo.indexOf('country')));
    expect(tottori.toSet(), tokyo.toSet());
    expect(tokyo.last, 'words');
  });

  test('reading every chapter finishes the guide once, with coins', () async {
    SharedPreferences.setMockInitialValues({});
    final my = Services.my = MyStore(unlimited: false);
    await my.load(
      catalog: MyCatalog.fromJson(
        jsonDecode(File('assets/my/catalog.json').readAsStringSync()) as Map<String, dynamic>,
      ),
    );
    await FirstRideProgress.load();
    var finished = 0;
    for (final c in firstRideChapters) {
      if (await FirstRideProgress.markRead(c.id)) finished++;
    }
    expect(finished, 1);
    expect(FirstRideProgress.done.value, isTrue);
    expect(my.coins, FirstRideProgress.coins);
    expect(await FirstRideProgress.markRead(firstRideChapters.first.id), isFalse);
  });
}
