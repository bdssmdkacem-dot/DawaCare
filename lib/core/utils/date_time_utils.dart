import 'package:intl/intl.dart';

class DateTimeUtils {
  DateTimeUtils._();

  static bool isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Converts Dart's DateTime.weekday (1=Mon..7=Sun) to the app/calendar-tool
  /// convention used in medication_schedules.days_of_week (1=Sun..7=Sat).
  static int toAppWeekday(int dartWeekday) => (dartWeekday % 7) + 1;

  static const List<String> appWeekdayNamesAr = [
    '', // unused index 0
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  static String formatTime(DateTime dt) => DateFormat('HH:mm').format(dt);

  static String formatDay(DateTime dt) => DateFormat('EEEE d MMMM', 'ar').format(dt);

  static String formatShortDate(DateTime dt) => DateFormat('d/M/yyyy').format(dt);

  static String relativeDayLabel(DateTime dt) {
    final now = DateTime.now();
    if (isSameDate(dt, now)) return 'اليوم';
    if (isSameDate(dt, now.add(const Duration(days: 1)))) return 'غدًا';
    if (isSameDate(dt, now.subtract(const Duration(days: 1)))) return 'أمس';
    return formatDay(dt);
  }
}
