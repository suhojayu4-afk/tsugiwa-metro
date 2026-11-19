import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/features/platform/departure_board.dart';

import 'trip_logic_test.dart' show loadTokyo;

void main() {
  final city = loadTokyo();

  test('next trains from Shibuya at noon: soonest first, all in the future, both Yamanote ways', () {
    final noon = DateTime.utc(2026, 11, 18, 3); // 12:00 in Japan
    final list = nextDepartures(city, 'tokyo.shibuya', noon, count: 20, perWay: 2);
    expect(list.length, greaterThanOrEqualTo(8));
    final nowSec = (12 * 60 - 240) * 60;
    for (var i = 0; i < list.length; i++) {
      expect(list[i].sec, greaterThanOrEqualTo(nowSec));
      if (i > 0) expect(list[i].sec, greaterThanOrEqualTo(list[i - 1].sec));
    }
    final yamanote = list.where((d) => d.line.id == 'tokyo.yamanote').toList();
    expect(yamanote.map((d) => d.forward).toSet(), {true, false});
    // A loop line shows its direction, not a last station.
    expect(yamanote.every((d) => d.terminusId == null), isTrue);
    // Every few minutes at noon.
    expect(yamanote.first.sec - nowSec, lessThan(6 * 60));
  });

  test('no trains after the last one; the end of a line only runs one way', () {
    final night = DateTime.utc(2026, 11, 18, 17, 30); // 02:30 in Japan
    expect(nextDepartures(city, 'tokyo.shibuya', night), isEmpty);
    final noon = DateTime.utc(2026, 11, 18, 3);
    // Asakusa is the end of the Ginza Line: Ginza trains leave only for Shibuya.
    final ginza = nextDepartures(city, 'tokyo.asakusa', noon, count: 20).where((d) => d.line.id == 'tokyo.ginza');
    expect(ginza, isNotEmpty);
    expect(ginza.every((d) => d.terminusId == 'tokyo.shibuya'), isTrue);
  });
}
