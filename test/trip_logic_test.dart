import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_art.dart';
import 'package:tsugiwa_metro/core/pixel/pixel_scene.dart';
import 'package:tsugiwa_metro/data/models/city.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';
import 'package:tsugiwa_metro/features/trip/trip_estimator.dart';
import 'package:tsugiwa_metro/features/trip/trip_plan.dart';

CityData loadTokyo() {
  dynamic read(String f) => jsonDecode(File('assets/cities/tokyo/$f').readAsStringSync());
  return CityData.fromJson(
    city: read('city.json') as Map<String, dynamic>,
    stations: read('stations.json') as List<dynamic>,
    lines: read('lines.json') as List<dynamic>,
    timetables: read('timetables.json') as Map<String, dynamic>,
    walks: read('walks.json') as List<dynamic>,
  );
}

void main() {
  final city = loadTokyo();
  final noon = DateTime(2026, 11, 17, 12); // a Tuesday
  RouteResult route(String a, String b) => RouteFinder(city).find('tokyo.$a', 'tokyo.$b', at: noon)!;
  // Shinjuku → Shibuya on the Yamanote Line (the fastest way is now the Saikyo Line).
  const yamanoteRide = RouteResult([
    RouteLeg(
      lineId: 'tokyo.yamanote',
      forward: true,
      stationIds: ['tokyo.shinjuku', 'tokyo.yoyogi', 'tokyo.harajuku', 'tokyo.shibuya'],
    ),
  ]);

  group('city data', () {
    test('Tokyo has both MVP lines with the right station counts', () {
      expect(city.line('tokyo.yamanote').stations, hasLength(30));
      expect(city.line('tokyo.ginza').stations, hasLength(19));
    });

    test('all nine Tokyo Metro lines are there, end-to-end times look real', () {
      // Every line from Yokohama to Saitama and Narita (tools/build_rail.py).
      expect(city.lines.length, greaterThan(100));
      for (final id in ['hibiya', 'tozai', 'chiyoda', 'yurakucho', 'hanzomon', 'namboku', 'fukutoshin']) {
        expect(city.line('tokyo.$id').stations.length, greaterThan(10), reason: id);
      }
      // Ogikubo → Ikebukuro end to end is about 55 minutes on the Marunouchi Line.
      final m = city.line('tokyo.marunouchi');
      final sec = m.runSec.reduce((a, b) => a + b) + m.dwellSec * (m.stations.length - 2);
      expect(sec / 60, inInclusiveRange(45, 65));
      // …and the route finder changes at Shinjuku for the Yamanote Line (the Chuo Line gets there first).
      expect(route('ogikubo', 'ikebukuro').legs.last.lineId, 'tokyo.yamanote');
    });

    test('Yamanote loop takes about an hour, Ginza end to end about 30 min', () {
      final y = city.line('tokyo.yamanote');
      final loopSec = y.runSec.reduce((a, b) => a + b) + y.dwellSec * y.stations.length;
      expect(loopSec / 60, inInclusiveRange(55, 65));
      final plan = TripPlan.build(city, route('shibuya', 'asakusa'), noon);
      expect(plan.totalSec / 60, inInclusiveRange(27, 35));
    });
  });

  group('route finder', () {
    test('Shibuya → Asakusa is a direct Ginza Line ride of 18 stops', () {
      final r = route('shibuya', 'asakusa');
      expect(r.legs, hasLength(1));
      expect(r.legs.single.lineId, 'tokyo.ginza');
      expect(r.legs.single.forward, isTrue);
      expect(r.stopCount, 18);
    });

    test('Yamanote picks the shorter way round the loop', () {
      final r = route('tokyo', 'yurakucho');
      expect(r.stopCount, 1);
      expect(r.legs.single.forward, isFalse); // 外回り
    });

    test('Harajuku → Gaiemmae changes trains at Shibuya', () {
      final r = route('harajuku', 'gaiemmae');
      expect(r.legs.map((l) => l.lineId), ['tokyo.yamanote', 'tokyo.ginza']);
      expect(r.legs.first.stationIds.last, 'tokyo.shibuya');
      expect(r.transferCount, 1);
    });

    test('Tokyo Metro: Shinjuku → Ginza is one Marunouchi Line ride', () {
      final r = route('shinjuku', 'ginza');
      expect(r.legs.map((l) => l.lineId), ['tokyo.marunouchi']);
    });

    test('Nakano → Kita-senju needs at most two changes', () {
      final r = route('nakano', 'kita_senju');
      expect(r.transferCount, lessThanOrEqualTo(2));
    });

    test('Toei and through lines: Haneda Airport, the Oedo loop, Keio to Hachioji', () {
      final haneda = route('shinjuku', 'haneda_airport_terminal_12');
      expect(haneda.legs.last.lineId, 'tokyo.keikyu_airport');
      final oedo = city.line('tokyo.toei_oedo');
      expect(oedo.loop, isTrue);
      expect(oedo.stations.first, 'tokyo.tochomae');
      expect(city.line('tokyo.toei_oedo_branch').stations.first, 'tokyo.tochomae');
      // Shinjuku → Keio Hachioji is one Keio Line ride of about an hour.
      final keio = route('shinjuku', 'keio_hachioji');
      expect(keio.legs.single.lineId, 'tokyo.keio');
      final plan = TripPlan.build(city, keio, noon);
      expect(plan.totalSec / 60, inInclusiveRange(55, 85));
    });

    test('Narita Airport: Skyliner from Nippori, NEX from Tokyo, about 40 to 60 minutes', () {
      final sky = route('nippori', 'narita_airport');
      expect(sky.legs.single.lineId, 'tokyo.skyliner');
      expect(TripPlan.build(city, sky, noon).totalSec / 60, inInclusiveRange(35, 50));
      final nex = route('tokyo', 'narita_airport');
      expect(nex.legs.single.lineId, 'tokyo.narita_express');
      expect(TripPlan.build(city, nex, noon).totalSec / 60, inInclusiveRange(48, 65));
    });

    test('walking transfers: Ueno → Narita walks to Keisei Ueno for the Skyliner', () {
      expect(city.walkMin('tokyo.ueno', 'tokyo.keisei_ueno'), 5);
      final r = route('ueno', 'narita_airport');
      expect(r.legs.single.lineId, 'tokyo.skyliner');
      expect(r.legs.single.stationIds.first, 'tokyo.keisei_ueno');
    });

    test('walking transfers: the trip shows where to walk', () {
      // Shimbashi (Yamanote) → Shiodome on foot → Oedo Line to Tsukijishijo.
      final r = RouteFinder(city).find('tokyo.yurakucho', 'tokyo.tsukijishijo', at: noon)!;
      final plan = TripPlan.build(city, r, noon);
      final walk = plan.stops.where((s) => s.walkToStationId != null).toList();
      expect(walk, isNotEmpty);
      final w = walk.first;
      expect(city.walkMin(w.stationId, w.walkToStationId!), isNotNull);
    });

    test('same station gives no route', () {
      expect(RouteFinder(city).find('tokyo.ueno', 'tokyo.ueno'), isNull);
    });
  });

  group('trip estimate', () {
    test('timeline moves from station to station and arrives', () {
      final plan = TripPlan.build(city, yamanoteRide, noon);
      expect(plan.stops.map((s) => s.stationId), [
        'tokyo.shinjuku',
        'tokyo.yoyogi',
        'tokyo.harajuku',
        'tokyo.shibuya',
      ]);
      var s = estimateTrip(plan, 0, noon);
      expect(s.currentIndex, 0);
      expect(s.remainingStops, 3);
      expect(s.atStation, isFalse);

      s = estimateTrip(plan, 75, noon); // just arrived at Yoyogi (70s run)
      expect(s.currentIndex, 1);
      expect(s.atStation, isTrue);

      s = estimateTrip(plan, plan.totalSec, noon);
      expect(s.arrived, isTrue);
      expect(s.progress, 1);
    });

    test('transfer stop includes walking and waiting time', () {
      final plan = TripPlan.build(city, route('harajuku', 'gaiemmae'), noon);
      final shibuya = plan.stops.firstWhere((s) => s.stationId == 'tokyo.shibuya');
      expect(shibuya.transferToLineId, 'tokyo.ginza');
      expect(shibuya.departSec - shibuya.arriveSec, greaterThanOrEqualTo(6 * 60));
    });

    test('GPS near the next station pulls the estimate forward', () {
      final plan = TripPlan.build(city, yamanoteRide, noon);
      final harajuku = city.station('tokyo.harajuku');
      final fix = GpsFix(lat: harajuku.lat, lng: harajuku.lng, accuracyM: 15, time: noon);
      final delta = gpsCorrection(plan, city, fix, 0)!;
      expect(delta, plan.stops[2].arriveSec);
    });

    test('GPS is ignored underground and when inaccurate', () {
      final metro = TripPlan.build(city, route('ginza', 'kyobashi'), noon);
      final ginza = city.station('tokyo.ginza');
      expect(
        gpsCorrection(metro, city, GpsFix(lat: ginza.lat, lng: ginza.lng, accuracyM: 10, time: noon), 0),
        isNull,
      );

      final jr = TripPlan.build(city, yamanoteRide, noon);
      final yoyogi = city.station('tokyo.yoyogi');
      expect(
        gpsCorrection(jr, city, GpsFix(lat: yoyogi.lat, lng: yoyogi.lng, accuracyM: 800, time: noon), 0),
        isNull,
      );
    });
  });

  test('starter train sprite is 128×56 and frames differ (turning wheels)', () {
    final s = Sprites.starterTrain;
    expect(s.width, 128);
    expect(s.height, 56);
    expect(s.frames, hasLength(2));
    for (final f in s.frames) {
      expect(f, hasLength(56));
      expect(f.every((row) => row.length == 128), isTrue);
    }
    expect(s.frames[0].join(), isNot(s.frames[1].join()));
  });

  test('scene art exists for every time of day, and the view keeps pixels whole', () {
    for (final part in DayPart.values) {
      expect(File(SceneArt.background(part)).existsSync(), isTrue, reason: part.name);
      expect(File(SceneArt.trainBase(part)).existsSync(), isTrue, reason: part.name);
    }
    expect(File(SceneArt.trainStripe).existsSync(), isTrue);
    // 320 logical px wide at 3x: 3 device px per art pixel, 320 columns shown.
    final v = SceneView.fit(320, 3);
    expect(v.scale * 3, 3);
    expect(v.src.width, 320);
    expect(v.src.height, 160);
    expect(dayPartOf(DateTime(2026, 11, 17, 12)), DayPart.day);
    expect(dayPartOf(DateTime(2026, 11, 17, 17)), DayPart.evening);
    expect(dayPartOf(DateTime(2026, 11, 17, 23)), DayPart.night);
  });

  test('palette has 64 colours and one character per colour', () {
    expect(PixelPalette.colors, hasLength(64));
    expect(PixelPalette.chars.length, 64);
    expect(PixelPalette.chars.split('').toSet(), hasLength(64));
  });

  test('every sprite only uses palette characters', () {
    final allowed = RegExp(r'^[0-9A-Za-z#$.*+\-]+$');
    for (final s in [
      Sprites.starterTrain,
      Sprites.navPlatform,
      Sprites.navMap,
      Sprites.navMy,
      Sprites.pin,
      Sprites.weatherSunny,
      Sprites.weatherCloudy,
      Sprites.weatherRain,
      Sprites.weatherSnow,
    ]) {
      for (final f in s.frames) {
        for (final row in f) {
          expect(allowed.hasMatch(row), isTrue, reason: row);
        }
      }
    }
  });
}
