import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/features/platform/led_destination.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';

import 'trip_logic_test.dart' as t;

void main() {
  final city = t.loadTokyo();
  RouteResult route(String a, String b) => RouteFinder(city).find('tokyo.$a', 'tokyo.$b')!;

  test('normal line: local train and its last stop, then English', () {
    // Shibuya → Ginza on the Ginza Line runs towards Asakusa.
    expect(destinationLed(city, route('shibuya', 'ginza').legs.first), ['各停 浅草', 'for Asakusa']);
    // The other way runs towards Shibuya.
    expect(destinationLed(city, route('ginza', 'shibuya').legs.first).first, '各停 渋谷');
  });

  test('loop line: line name and the way round', () {
    final pages = destinationLed(city, route('tokyo', 'yurakucho').legs.first);
    expect(pages.first, '山手線');
    expect(pages.last, anyOf('内回り', '外回り'));
    final oedo = city.line('tokyo.toei_oedo');
    final leg = RouteLeg(lineId: oedo.id, forward: true, stationIds: [oedo.stations[0], oedo.stations[1]]);
    expect(destinationLed(city, leg), ['大江戸線', '飯田橋方面']);
  });

  test('airport express shows its own name', () {
    expect(destinationLed(city, route('nippori', 'narita_airport').legs.first), ['スカイライナー', '成田空港']);
  });

  test('long English names are left out rather than squeezed unreadably', () {
    for (final line in city.lines) {
      for (final forward in [true, false]) {
        final leg = RouteLeg(
          lineId: line.id,
          forward: forward,
          stationIds: [line.stations.first, line.stations[1]],
        );
        for (final p in destinationLed(city, leg)) {
          expect(p.isNotEmpty, isTrue);
          if (p.startsWith('for ')) expect(p.length, lessThanOrEqualTo(16), reason: p);
        }
      }
    }
  });
}
