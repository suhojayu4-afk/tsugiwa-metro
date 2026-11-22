// One last train everywhere (card, tip, alarm, widget), and the alarm's
// notification permission.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsugiwa_metro/data/last_train_alarm.dart';
import 'package:tsugiwa_metro/data/models/timetable.dart';
import 'package:tsugiwa_metro/features/guide/guide_data.dart';
import 'package:tsugiwa_metro/features/guide/guide_tips.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';

import 'trip_logic_test.dart' show loadTokyo;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final city = loadTokyo();
  String id(String ja) => city.stations.values.firstWhere((s) => s.name.ja == ja).id;
  // A Tuesday at noon in Japan.
  final noon = DateTime.utc(2026, 11, 24, 12);
  RouteResult route(String a, String b) => RouteFinder(city).find(id(a), id(b), at: noon)!;

  /// The definition: leave at the answer and every line is still caught;
  /// one minute later one of them is gone.
  void expectLastDeparture(RouteResult r) {
    final dep = lastDepartureMin(city, r)!;
    expect(missedLines(city, r, dep), isEmpty, reason: 'leaving at the last departure works');
    expect(missedLines(city, r, dep + 1), isNotEmpty, reason: 'one minute later it does not');
    for (final leg in r.legs) {
      expect(dep, lessThanOrEqualTo(city.timetables[leg.lineId]!.lastTrainMin));
    }
    // The one function every screen uses gives the same time.
    expect(lastTrainMinOf(city, route: r), dep);
    final at = DateTime.utc(2026, 11, 24).add(Duration(minutes: dep - 30));
    expect(minutesToLast(city, at, route: r), 30);
    expect(minutesToLast(city, at.add(const Duration(minutes: 31)), route: r), isNull);
  }

  group('one last train', () {
    test('原宿 → 新宿御苑前: 00:09, not the 山手線\'s own 01:00', () {
      final r = route('原宿', '新宿御苑前');
      expect([for (final l in r.legs) l.lineId], ['tokyo.yamanote', 'tokyo.marunouchi']);
      final dep = lastDepartureMin(city, r)!;
      expect(LineTimetable.clock(city.timetables['tokyo.yamanote']!.lastTrainMin), '01:00');
      expect(LineTimetable.clock(dep), '00:09');
      expectLastDeparture(r);
      // What the alarm rings for.
      expect(LineTimetable.clock(dep - LastTrainAlarm.leadMin), '23:39');
    });

    test('渋谷 → 東陽町 and 上野 → 中野坂上 (with changes)', () {
      for (final (a, b) in [('渋谷', '東陽町'), ('上野', '中野坂上')]) {
        final r = route(a, b);
        expect(r.transferCount, greaterThan(0), reason: '$a → $b');
        expectLastDeparture(r);
      }
    });

    test('a station without a destination: that line\'s last train', () {
      final ginza = city.timetables['tokyo.ginza']!;
      expect(lastTrainMinOf(city, lineId: 'tokyo.ginza'), ginza.lastTrainMin);
      final at = DateTime.utc(2026, 11, 24).add(Duration(minutes: ginza.lastTrainMin - 20));
      expect(minutesToLast(city, at, lineId: 'tokyo.ginza'), 20);
      expect(lastTrainMinOf(city), isNull);
    });

    test('the attendant counts down to the same last train', () {
      final r = route('原宿', '新宿御苑前');
      final dep = lastDepartureMin(city, r)!;
      // 20 minutes before it, as an instant (Japan = UTC+9).
      final now = DateTime.utc(2026, 11, 24).add(Duration(minutes: dep - 20 - 9 * 60));
      Object read(String f) => jsonDecode(File('assets/cities/tokyo/$f').readAsStringSync()) as Object;
      final data = GuideData.fromJson(
        tips: read('tips.json') as Map<String, dynamic>,
        pool: read('attendant_tips.json') as List<dynamic>,
      );
      final tips = guideTips(
        city: city,
        data: data,
        now: now,
        lang: 'ja',
        route: r,
        fromId: id('原宿'),
        toId: id('新宿御苑前'),
      );
      expect(tips.first.text.ja, contains('あと20分'));
    });
  });

  test('03:00 in Japan (trains have stopped): no good-morning from the attendant', () {
    Object read(String f) => jsonDecode(File('assets/cities/tokyo/$f').readAsStringSync()) as Object;
    final data = GuideData.fromJson(
      tips: read('tips.json') as Map<String, dynamic>,
      pool: read('attendant_tips.json') as List<dynamic>,
    );
    for (final withData in [true, false]) {
      final tips = guideTips(
        city: city,
        data: withData ? data : const GuideData(),
        now: DateTime.utc(2026, 11, 21, 18), // 03:00 on the 22nd in Japan
        lang: 'ja',
        fromId: id('原宿'),
        toId: id('新宿御苑前'),
      );
      expect(tips, isNotEmpty);
      expect(tips.where((t) => t.text.ja.contains('おはよう')), isEmpty);
    }
  });

  group('a walk to the station next door', () {
    test('原宿 → 乃木坂: on foot to 明治神宮前, then the 千代田線', () {
      final r = route('原宿', '乃木坂');
      expect(r.legs.first.lineId, 'tokyo.chiyoda');
      // The train is boarded at 明治神宮前; 原宿 is where the walk starts.
      expect(r.fromId, id('明治神宮前'));
      expect(r.walkFromId, id('原宿'));
      expect(r.headWalkMin(city), city.walkMin(id('原宿'), id('明治神宮前')));
      expect(r.walkToId, isNull);
      // The walk comes off the last departure.
      final dep = lastDepartureMin(city, r)!;
      expect(dep, city.timetables['tokyo.chiyoda']!.lastTrainMin - r.headWalkMin(city));
      expectLastDeparture(r);
      // No walk on an ordinary route.
      expect(route('渋谷', '東陽町').walkFromId, isNull);
    });
  });

  group('alarm and the notification permission', () {
    const channel = MethodChannel('tsugiwa/live');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<String> calls;
    LastTrainTexts texts(int dep) => (title: 't', body: 'b', channel: 'c');

    /// The native side: [answers] by method name; a list gives one answer
    /// per call; a method that is not there answers null.
    void native(Map<String, Object?> answers) {
      final counts = <String, int>{};
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        final a = answers[call.method];
        if (a is List) {
          final n = counts.update(call.method, (v) => v + 1, ifAbsent: () => 0);
          return a[n.clamp(0, a.length - 1)];
        }
        return a;
      });
    }

    setUp(() {
      calls = [];
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    Future<AlarmNotice> turnOn(LastTrainAlarm alarm) async =>
        (await alarm.turnOn(city, id('原宿'), id('新宿御苑前'), texts))!.notice;

    test('already allowed: set, no waiting', () async {
      native({'ensureNotificationPermission': true});
      final alarm = LastTrainAlarm()..promptWait = () async => fail('no question, nothing to wait for');
      expect(await turnOn(alarm), AlarmNotice.on);
      expect(calls.take(2), ['ensureNotificationPermission', 'lastTrainAlarm']);
    });

    test('Android: waits for the question, then reads the answer', () async {
      var waited = false;
      native({'ensureNotificationPermission': false, 'notificationsAllowed': true});
      final alarm = LastTrainAlarm()
        ..promptWait = () async {
          // Not asked for the answer while the question is still open.
          expect(calls, isNot(contains('notificationsAllowed')));
          waited = true;
          return true;
        };
      expect(await turnOn(alarm), AlarmNotice.on);
      expect(waited, isTrue);

      // Refused in the question.
      native({'ensureNotificationPermission': false, 'notificationsAllowed': false});
      expect(await turnOn(LastTrainAlarm()..promptWait = () async => true), AlarmNotice.off);
    });

    test('Android without notificationsAllowed: refused for good = off, else not sure', () async {
      native({'ensureNotificationPermission': false});
      // The system did not even show the question.
      expect(await turnOn(LastTrainAlarm()..promptWait = () async => false), AlarmNotice.off);
      // It was shown, but nothing tells us the answer.
      expect(await turnOn(LastTrainAlarm()..promptWait = () async => true), AlarmNotice.unsure);
    });

    test('notifications turned off in the settings: off, even when the permission is there', () async {
      native({'ensureNotificationPermission': true, 'notificationsAllowed': false});
      expect(await turnOn(LastTrainAlarm()), AlarmNotice.off);
    });

    test('iPhone: the question comes with the alarm; the answer is read after it', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      native({
        'ensureNotificationPermission': [false, true],
      });
      final alarm = LastTrainAlarm()..promptWait = () async => fail('iPhone answers by itself');
      expect(await turnOn(alarm), AlarmNotice.on);
      expect(calls, [
        'ensureNotificationPermission',
        'lastTrainAlarm',
        'notificationsAllowed',
        'ensureNotificationPermission',
      ]);
      native({'ensureNotificationPermission': false});
      expect(await turnOn(LastTrainAlarm()), AlarmNotice.off);
      debugDefaultTargetPlatformOverride = null;
    });

    test('the first-train alarm reports the same way', () async {
      native({'ensureNotificationPermission': false, 'notificationsAllowed': false});
      final alarm = LastTrainAlarm()..promptWait = () async => true;
      final notice = await alarm.turnOnFirst(from: 'a', to: 'b', firstMin: 5 * 60, minutesAway: 120, texts: texts(0));
      expect(notice, AlarmNotice.off);
    });

    test('refresh at launch never asks for the permission', () async {
      native({'ensureNotificationPermission': false});
      SharedPreferences.setMockInitialValues({
        'lastTrainAlarm': [id('原宿'), id('新宿御苑前')],
      });
      final alarm = LastTrainAlarm()..promptWait = () async => fail('never asked at launch');
      await alarm.load();
      await alarm.refresh(city, texts);
      expect(calls, ['lastTrainAlarm']);
    });
  });
}
