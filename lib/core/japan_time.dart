/// Japan time for everything that follows the trains: timetables, last
/// trains, rush hours, greetings. Tourists' phones may be in another time
/// zone, so the phone's own clock time is never used for these.
library;

/// The clock behind [japanNow]; tests put a fixed instant here.
DateTime Function() japanClock = DateTime.now;

/// [instant] as the clock time in Japan (UTC+9, no summer time). The result's
/// own fields (year … second, weekday) are Japan's; its zone flag is not used.
DateTime toJapanTime(DateTime instant) => instant.toUtc().add(const Duration(hours: 9));

/// The clock time in Japan now.
DateTime japanNow() => toJapanTime(japanClock());

/// Whether the calendar day of [date] (its year / month / day fields) is a
/// Japanese public holiday: the fixed days, the Happy Monday ones, the two
/// equinoxes, 振替休日 (the weekday after a holiday on a Sunday) and 国民の休日
/// (a weekday between two holidays).
bool isJapanHoliday(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  if (_named(d)) return true;
  // 振替休日: the first day that is not a holiday after a holiday on a Sunday.
  var back = d.subtract(const Duration(days: 1));
  while (_named(back)) {
    if (back.weekday == DateTime.sunday) return true;
    back = back.subtract(const Duration(days: 1));
  }
  // 国民の休日: between two holidays (September in some years).
  return d.weekday != DateTime.sunday &&
      _named(d.subtract(const Duration(days: 1))) &&
      _named(d.add(const Duration(days: 1)));
}

/// Days the railways run their 土休日 timetable: Saturdays, Sundays, public
/// holidays and the New Year days (12/30 – 1/3).
bool isHolidayTimetableDay(DateTime date) {
  if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) return true;
  if ((date.month == 12 && date.day >= 30) || (date.month == 1 && date.day <= 3)) return true;
  return isJapanHoliday(date);
}

/// A holiday with a name of its own (no 振替休日 / 国民の休日).
bool _named(DateTime d) {
  final y = d.year, m = d.month, day = d.day;
  bool monday(int nth) => d.weekday == DateTime.monday && (day - 1) ~/ 7 == nth - 1;
  return switch (m) {
    1 => day == 1 || monday(2), // 元日, 成人の日
    2 => day == 11 || day == 23, // 建国記念の日, 天皇誕生日
    3 => day == _equinox(y, 20.8431), // 春分の日
    4 => day == 29, // 昭和の日
    5 => day >= 3 && day <= 5, // 憲法記念日, みどりの日, こどもの日
    7 => monday(3), // 海の日
    8 => day == 11, // 山の日
    9 => monday(3) || day == _equinox(y, 23.2488), // 敬老の日, 秋分の日
    10 => monday(2), // スポーツの日
    11 => day == 3 || day == 23, // 文化の日, 勤労感謝の日
    _ => false,
  };
}

/// Day of the month of an equinox (good for 1980 – 2099).
int _equinox(int year, double base) => (base + 0.242194 * (year - 1980)).floor() - (year - 1980) ~/ 4;
