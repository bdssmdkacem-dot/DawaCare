import '../../../core/utils/date_time_utils.dart';
import '../../../models/medication.dart';
import '../../../models/medication_schedule.dart';

/// Turns a [MedicationSchedule] (a *rule*, e.g. "every day at 08:00") into
/// concrete [DateTime] occurrences within a window. This is intentionally
/// pure/stateless — no I/O — so it's trivial to unit test.
///
/// Callers (see [DoseRepository.ensureDosesGenerated]) upsert the resulting
/// timestamps as `dose_instances` rows; the DB's
/// `unique (schedule_id, scheduled_at)` constraint makes re-running this for
/// an overlapping window a safe no-op.
class DoseEngine {
  DoseEngine._();

  static List<DateTime> computeOccurrences({
    required MedicationSchedule schedule,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    if (schedule.type == ScheduleType.prn) return const [];

    final occurrences = <DateTime>[];
    final scheduleStartDay = DateTime(schedule.startDate.year, schedule.startDate.month, schedule.startDate.day);
    final windowStartDay = DateTime(windowStart.year, windowStart.month, windowStart.day);
    var day = scheduleStartDay.isAfter(windowStartDay) ? scheduleStartDay : windowStartDay;

    while (!day.isAfter(windowEnd)) {
      final candidate = DateTime(day.year, day.month, day.day, schedule.hour, schedule.minute);

      final afterStart = !candidate.isBefore(schedule.startDate);
      final beforeEnd = schedule.endDate == null || !day.isAfter(schedule.endDate!);
      final withinWindow = !candidate.isBefore(windowStart) && !candidate.isAfter(windowEnd);

      if (afterStart && beforeEnd && withinWindow) {
        switch (schedule.type) {
          case ScheduleType.daily:
            occurrences.add(candidate);
            break;

          case ScheduleType.weekly:
          case ScheduleType.specificDays:
            final appWeekday = DateTimeUtils.toAppWeekday(day.weekday);
            if (schedule.daysOfWeek.contains(appWeekday)) occurrences.add(candidate);
            break;

          case ScheduleType.interval:
            final step = schedule.intervalDays ?? 1;
            final diffDays = day.difference(scheduleStartDay).inDays;
            if (step > 0 && diffDays % step == 0) occurrences.add(candidate);
            break;

          case ScheduleType.once:
            if (DateTimeUtils.isSameDate(day, schedule.startDate)) occurrences.add(candidate);
            break;

          case ScheduleType.prn:
            break; // handled above
        }
      }

      day = day.add(const Duration(days: 1));
    }

    return occurrences;
  }

  /// Convenience label used on medication cards, e.g. "يوميًا 08:00" or
  /// "الإثنين، الأربعاء، الجمعة — 20:00".
  static String describeSchedule(MedicationSchedule schedule) {
    final time = schedule.time;
    switch (schedule.type) {
      case ScheduleType.daily:
        return 'يوميًا — $time';
      case ScheduleType.weekly:
      case ScheduleType.specificDays:
        final days = schedule.daysOfWeek.map((d) => DateTimeUtils.appWeekdayNamesAr[d]).join('، ');
        return '$days — $time';
      case ScheduleType.interval:
        return 'كل ${schedule.intervalDays ?? 1} يوم — $time';
      case ScheduleType.once:
        return 'مرة واحدة — ${DateTimeUtils.formatShortDate(schedule.startDate)} $time';
      case ScheduleType.prn:
        return 'عند الحاجة';
    }
  }
}

/// Not persisted directly — kept here so [DoseRepository] can build a
/// denormalized dose row without importing [Medication] itself.
extension MedicationDoseLabel on Medication {
  String get displayLabel => strength != null && strength!.isNotEmpty ? '$name ($strength)' : name;
}
