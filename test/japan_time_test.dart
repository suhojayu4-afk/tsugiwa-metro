// Japan time and holidays: the app follows Tokyo's clock and calendar even
// on a phone set to another time zone.
import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/core/japan_time.dart';
import 'package:tsugiwa_metro/data/models/timetable.dart';

import 'trip_logic_test.dart' show loadTokyo;

void main() {
  tearDown(() => japanClock = DateTime.now);

  test('an instant becomes the clock time in Japan, whatever the zone', () {
    // 18:00 UTC on the 21st = 03:00 on the 22nd in Japan.
    final j = toJapanTime(DateTime.utc(2026, 11, 21, 18));
    expect([j.year, j.month, j.day, j.hour, j.minute], [2026, 11, 22, 3, 0]);
    // The same instant as the phone's local time gives the same answer.
    final local = DateTime.utc(2026, 11, 21, 18).toLocal();
    expect(toJapanTime(local), j);
    // New York, 10:30 on a Friday morning = 00:30 on Saturday in Japan.
    final ny = DateTime.utc(2026, 11, 20, 15, 30);
    expect(toJapanTime(ny).weekday, DateTime.saturday);
    expect(toJapanTime(ny).hour, 0);
  });

  test('japanNow follows the clock that is set', () {
    japanClock = () => DateTime.utc(2026, 12, 31, 15, 5);
    final j = japanNow();
    expect([j.year, j.month, j.day, j.hour, j.minute], [2027, 1, 1, 0, 5]);
  });

  test('public holidays 2026 – 2030', () {
    bool h(int y, int m, int d) => isJapanHoliday(DateTime.utc(y, m, d));
    const holidays2026 = [
      (1, 1), (1, 12), (2, 11), (2, 23), (3, 20), (4, 29), (5, 3), (5, 4), (5, 5), //
      (5, 6), // 振替休日: 5/3 is a Sunday
      (7, 20), (8, 11), (9, 21),
      (9, 22), // 国民の休日 between 敬老の日 and 秋分の日
      (9, 23), (10, 12), (11, 3), (11, 23),
    ];
    final found = [
      for (var d = DateTime.utc(2026); d.year == 2026; d = d.add(const Duration(days: 1)))
        if (isJapanHoliday(d)) (d.month, d.day),
    ];
    expect(found, holidays2026);
    // Equinoxes and Happy Mondays of the other years.
    expect(h(2027, 3, 21), isTrue);
    expect(h(2027, 3, 22), isTrue, reason: '振替休日 (3/21 is a Sunday)');
    expect(h(2027, 9, 23), isTrue);
    expect(h(2028, 3, 20), isTrue);
    expect(h(2028, 9, 22), isTrue);
    expect(h(2028, 9, 23), isFalse);
    expect(h(2029, 3, 20), isTrue);
    expect(h(2029, 9, 23), isTrue);
    expect(h(2029, 9, 24), isTrue, reason: '振替休日 (9/23 is a Sunday)');
    expect(h(2030, 3, 20), isTrue);
    expect(h(2030, 9, 23), isTrue);
    expect(h(2030, 1, 14), isTrue, reason: '成人の日');
    expect(h(2030, 10, 14), isTrue, reason: 'スポーツの日');
    // Ordinary days.
    expect(h(2026, 11, 24), isFalse);
    expect(h(2026, 5, 7), isFalse);
    expect(h(2027, 1, 4), isFalse);
  });

  test('holiday timetable: weekends, holidays, New Year; the service day starts at 04:00', () {
    bool hol(int y, int m, int d, [int h = 12]) => LineTimetable.isHolidayService(DateTime.utc(y, m, d, h));
    expect(hol(2026, 11, 24), isFalse); // Tuesday
    expect(hol(2026, 11, 23), isTrue); // 勤労感謝の日, a Monday
    expect(hol(2026, 11, 22), isTrue); // Sunday
    expect(hol(2026, 12, 31), isTrue); // New Year days
    expect(hol(2027, 1, 4), isFalse);
    // 00:30 on Saturday is still Friday's service; 00:30 on Monday is Sunday's.
    expect(hol(2026, 11, 21, 0), isFalse);
    expect(hol(2026, 11, 23 + 1, 0), isTrue, reason: 'the night of the holiday Monday');
    expect(hol(2026, 11, 16, 0), isTrue, reason: 'the night of Sunday');
  });

  test('a holiday Monday uses the weekend intervals of the real timetables', () {
    final city = loadTokyo();
    // A line whose rush hour differs between weekdays and holidays.
    final tuesday = DateTime.utc(2026, 11, 24, 8), sunday = DateTime.utc(2026, 11, 22, 8);
    final holidayMonday = DateTime.utc(2026, 11, 23, 8);
    final differs = [
      for (final tt in city.timetables.values)
        if (tt.headwayMinAt(tuesday) != tt.headwayMinAt(sunday)) tt,
    ];
    expect(differs, isNotEmpty);
    for (final tt in differs) {
      expect(tt.headwayMinAt(holidayMonday), tt.headwayMinAt(sunday));
    }
  });
}
