import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/my_store.dart';
import 'package:tsugiwa_metro/platform/monthly_report.dart';

TripLog _trip(String day) => TripLog(day: day, minute: 600, stations: const ['a', 'b']);

void main() {
  test('months with rides, sorted and once each', () {
    final trips = [_trip('2026-11-03'), _trip('2026-10-30'), _trip('2026-11-20'), _trip('bad')];
    expect(MonthlyReport.rideMonths(trips), ['2026-10', '2026-11']);
    expect(MonthlyReport.rideMonths(const []), isEmpty);
  });

  test('next notice: the 1st at 9:00 Japan time', () {
    // 2026-11-19 12:00 JST -> 2026-12-01 09:00 JST (= 00:00 UTC).
    expect(MonthlyReport.nextNotice(DateTime.utc(2026, 11, 19, 3)), DateTime.utc(2026, 12, 1));
    // The 1st, 8:59 JST: still today.
    expect(MonthlyReport.nextNotice(DateTime.utc(2026, 11, 30, 23, 59)), DateTime.utc(2026, 12, 1));
    // The 1st, 9:00 JST exactly: next month.
    expect(MonthlyReport.nextNotice(DateTime.utc(2026, 12, 1)), DateTime.utc(2027, 1, 1));
    // New Year's Eve in Japan (still the 31st in UTC terms too).
    expect(MonthlyReport.nextNotice(DateTime.utc(2026, 12, 31, 20)), DateTime.utc(2027, 1, 1));
  });

  test('a notice on the 1st reports on the month before', () {
    expect(MonthlyReport.reportMonth(DateTime.utc(2026, 12, 1)), '2026-11');
    expect(MonthlyReport.reportMonth(DateTime.utc(2027, 1, 1)), '2026-12');
    // A few minutes early (inexact alarm window) is still the 1st in Japan.
    expect(MonthlyReport.reportMonth(DateTime.utc(2026, 11, 30, 23, 55)), '2026-11');
  });

  test('shows only when the user rode that month', () {
    final dec1 = DateTime.utc(2026, 12, 1);
    expect(MonthlyReport.shows([_trip('2026-11-30')], dec1), isTrue);
    expect(MonthlyReport.shows([_trip('2026-10-31'), _trip('2026-12-01')], dec1), isFalse);
    expect(MonthlyReport.shows(const [], dec1), isFalse);
  });

  test('titles in each language', () {
    expect(MonthlyReport.title('ja', 11), '11月の乗車レポートができました 🚃');
    expect(MonthlyReport.title('ko', 11), '11월 승차 리포트가 나왔어요 🚃');
    expect(MonthlyReport.title('en', 11), 'Your November ride report is ready 🚃');
    expect(MonthlyReport.title('fr', 1), '1月の乗車レポートができました 🚃');
  });
}
