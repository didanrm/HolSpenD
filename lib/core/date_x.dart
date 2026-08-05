/// Date helpers. Every wallet calculation works on *calendar days*, never on
/// timestamps, so a purchase at 23:59 and one at 00:01 land on different days.
class DateX {
  /// Strips the time component, keeping the local calendar date.
  static DateTime dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Whole calendar days between two dates (b - a). Ignores DST/time-of-day.
  static int daysBetween(DateTime a, DateTime b) {
    final from = dayOnly(a);
    final to = dayOnly(b);
    return to.difference(from).inDays;
  }

  /// Inclusive day count of a budget period: 5 Aug .. 31 Aug = 27 days.
  static int inclusiveDayCount(DateTime start, DateTime end) =>
      daysBetween(start, end) + 1;

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
