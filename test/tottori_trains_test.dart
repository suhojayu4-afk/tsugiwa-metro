import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/last_train_alarm.dart';
import 'package:tsugiwa_metro/data/realtime/jrwest_live.dart';
import 'package:tsugiwa_metro/features/trip/train_sheet.dart';
import 'package:tsugiwa_metro/features/platform/departure_board.dart';
import 'package:tsugiwa_metro/features/trip/route_finder.dart';
import 'package:tsugiwa_metro/features/trip/trip_estimator.dart';
import 'package:tsugiwa_metro/features/trip/trip_plan.dart';

import 'tottori_city_test.dart' show loadTottori;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final city = loadTottori();
  // Tuesday 2026-11-24 (平日) and Sunday 2026-11-29 (土休日), Japan time.
  final tue10 = DateTime(2026, 11, 24, 10);
  final sun10 = DateTime(2026, 11, 29, 10);

  test('every Tottori line has real trains on weekdays and holidays', () {
    for (final line in city.lines) {
      final t = city.trains[line.id];
      expect(t, isNotNull, reason: line.id);
      expect(t!.weekday, isNotEmpty, reason: line.id);
      expect(t.holiday, isNotEmpty, reason: line.id);
      for (final r in [...t.weekday, ...t.holiday]) {
        for (var i = 1; i < r.stops.length; i++) {
          expect(r.stops[i].arriveMin, greaterThanOrEqualTo(r.stops[i - 1].departMin), reason: '${line.id} ${r.no}');
          expect(r.stops[i].departMin, greaterThanOrEqualTo(r.stops[i].arriveMin));
        }
      }
    }
  });

  test('the next 境線 train from 米子 to 境港 is the printed one', () {
    final next = city.trains['tottori.sakai']!.next('tottori.yonago', 'tottori.sakaiminato', tue10);
    expect(next.single.departMin, greaterThanOrEqualTo(600));
    expect(next.single.run.to, '境港');
    // Late at night: tomorrow's first train.
    final late = city.trains['tottori.sakai']!.next(
      'tottori.yonago',
      'tottori.sakaiminato',
      DateTime(2026, 11, 24, 23, 50),
    );
    expect(late.single.dayOffsetMin, 1440);
  });

  test('a trip waits for the real train and arrives at the printed time', () {
    final route = RouteFinder(city).find('tottori.yonago', 'tottori.sakaiminato')!;
    final plan = TripPlan.build(city, route, tue10);
    expect(plan.timetabled, isTrue);
    final train = plan.trains.single!;
    final waitSec = train.departMin * 60 - 600 * 60;
    expect(plan.stops.first.departSec, waitSec);
    expect(plan.totalSec, (train.arriveMinAt('tottori.sakaiminato')! - 600) * 60);
    expect(plan.rideSec, plan.totalSec - waitSec);
    expect(plan.trainLeaving(0), same(train));
    // While waiting: still at 米子.
    final s = estimateTrip(plan, waitSec ~/ 2, tue10);
    expect(s.currentIndex, 0);
    expect(s.atStation, isTrue);
  });

  test('a change catches the next real train after the walk', () {
    final route = RouteFinder(city).find('tottori.tottori', 'tottori.sakaiminato')!;
    expect(route.legs.length, greaterThan(1));
    final plan = TripPlan.build(city, route, sun10);
    for (var li = 1; li < route.legs.length; li++) {
      final before = plan.trains[li - 1], after = plan.trains[li];
      if (before == null || after == null) continue;
      expect(after.departMin, greaterThanOrEqualTo(before.arriveMinAt(route.legs[li - 1].stationIds.last)!));
    }
    for (var i = 1; i < plan.stops.length; i++) {
      expect(plan.stops[i].arriveSec, greaterThanOrEqualTo(plan.stops[i - 1].departSec));
    }
  });

  test('the departure board lists real trains at 鳥取', () {
    final rows = nextDepartures(city, 'tottori.tottori', DateTime.utc(2026, 11, 24, 1), count: 8);
    expect(rows, isNotEmpty);
    expect(rows.every((d) => d.run != null), isTrue);
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].sec, greaterThanOrEqualTo(rows[i - 1].sec));
    }
  });

  test('route search rides the real trains: earliest arrival, changes that work', () {
    final finder = RouteFinder(city);
    final r = finder.findOnTrains('tottori.tottori', 'tottori.sakaiminato', tue10)!;
    expect(r.legs.first.stationIds.first, 'tottori.tottori');
    expect(r.legs.last.stationIds.last, 'tottori.sakaiminato');
    expect(r.legs.last.lineId, 'tottori.sakai');
    // find() takes the same way on Tottori.
    expect(finder.find('tottori.tottori', 'tottori.sakaiminato', at: tue10)!.key, r.key);
    final plan = TripPlan.build(city, r, tue10);
    expect(plan.timetabled, isTrue);
    // Each leg's stations are the line's own, in a row.
    for (final leg in r.legs) {
      final st = city.line(leg.lineId).stations;
      for (var i = 1; i < leg.stationIds.length; i++) {
        expect((st.indexOf(leg.stationIds[i]) - st.indexOf(leg.stationIds[i - 1])).abs(), 1);
      }
    }
  });

  test('the last train is the last real one that still connects', () {
    final finder = RouteFinder(city);
    final direct = finder.findOnTrains('tottori.yonago', 'tottori.sakaiminato', tue10)!;
    final last = lastRealDepartureMin(city, direct, tue10)!;
    final lastRun = city.trains['tottori.sakai']!.weekday
        .where((r) => r.indexOf('tottori.yonago') == 0)
        .map((r) => r.stops.first.departMin)
        .reduce((a, b) => a > b ? a : b);
    expect(last, lastRun);
    expect(missedLines(city, direct, last + 1), {'tottori.sakai'});
    expect(missedLines(city, direct, last - 30), isEmpty);
  });

  test('JR西日本 运行情報 and 走行位置 are read', () {
    final status = parseJrWestTraffic({
      'areaTrafficInfos': [
        {
          'dailyData': [
            {
              'placeTrafficInfos': [
                {
                  'conventionalLineTrafficInfos': [
                    {
                      'lineName': '境線',
                      'conventionalLineTrafficInfoDetails': [
                        {
                          'conditionName': '遅れ',
                          'cause': '強風',
                          'versionDetail': [
                            {'title': '【境線】遅れ', 'body': '境線は強風のため遅れています。'},
                          ],
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    });
    expect(status['tottori.sakai']!.normal, isFalse);
    expect(status['tottori.sakai']!.text.ja, contains('強風'));
    expect(status['tottori.sanin']!.normal, isTrue);
    final names = parseGuideStations({
      'stations': [
        {
          'info': {'code': '0029', 'name': '米子'},
        },
        {
          'info': {'code': '0031', 'name': '安来'},
        },
      ],
    });
    final trains = parseTrainGuide({
      'trains': [
        {'no': '155D', 'pos': '0029_0031', 'delayMinutes': 4, 'dest': '出雲市'},
        {'no': '150D', 'pos': '0031_####', 'delayMinutes': 0, 'dest': '米子'},
      ],
    }, names);
    expect(trains.first.at, '米子');
    expect(trains.first.next, '安来');
    expect(trains.first.delayMin, 4);
    expect(trains.last.next, isNull);
  });

  test('where a train is by the timetable', () {
    final r = city.trains['tottori.sakai']!.weekday.first;
    final st = r.stops;
    expect(trainPosition(r, st.first.departMin - 5.0), isNull);
    expect(trainPosition(r, st[2].arriveMin.toDouble()), (index: 2, standing: true));
    expect(trainPosition(r, (st[2].departMin + st[3].arriveMin) / 2 + 0.01)?.index, 2);
  });
}
