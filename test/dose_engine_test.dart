import 'package:flutter_test/flutter_test.dart';
import 'package:dawacare/features/doses/domain/dose_engine.dart';
import 'package:dawacare/models/medication_schedule.dart';

void main() {
  group('DoseEngine.computeOccurrences', () {
    test('DAILY generates one occurrence per day in the window', () {
      final schedule = MedicationSchedule(
        id: 's1',
        medicationId: 'm1',
        type: ScheduleType.daily,
        time: '08:00',
        startDate: DateTime(2026, 1, 1),
        timezone: 'Africa/Casablanca',
        doseAmount: '1',
      );

      final occurrences = DoseEngine.computeOccurrences(
        schedule: schedule,
        windowStart: DateTime(2026, 1, 1),
        windowEnd: DateTime(2026, 1, 5, 23, 59, 59),
      );

      expect(occurrences.length, 5);
      expect(occurrences.first, DateTime(2026, 1, 1, 8, 0));
      expect(occurrences.last, DateTime(2026, 1, 5, 8, 0));
    });

    test('SPECIFIC_DAYS only generates on the chosen weekdays', () {
      // 1=Sunday .. 7=Saturday; 2026-01-05 is a Monday.
      final schedule = MedicationSchedule(
        id: 's2',
        medicationId: 'm1',
        type: ScheduleType.specificDays,
        time: '20:00',
        daysOfWeek: const [2, 5], // Monday, Thursday
        startDate: DateTime(2026, 1, 1),
        timezone: 'Africa/Casablanca',
        doseAmount: '1',
      );

      final occurrences = DoseEngine.computeOccurrences(
        schedule: schedule,
        windowStart: DateTime(2026, 1, 1),
        windowEnd: DateTime(2026, 1, 14),
      );

      expect(occurrences.every((d) => d.weekday == DateTime.monday || d.weekday == DateTime.thursday), isTrue);
      expect(occurrences.length, 4); // 2 Mondays + 2 Thursdays in that window
    });

    test('INTERVAL respects the start date and step size', () {
      final schedule = MedicationSchedule(
        id: 's3',
        medicationId: 'm1',
        type: ScheduleType.interval,
        time: '09:00',
        intervalDays: 3,
        startDate: DateTime(2026, 1, 1),
        timezone: 'Africa/Casablanca',
        doseAmount: '1',
      );

      final occurrences = DoseEngine.computeOccurrences(
        schedule: schedule,
        windowStart: DateTime(2026, 1, 1),
        windowEnd: DateTime(2026, 1, 10, 23, 59, 59),
      );

      expect(occurrences, [
        DateTime(2026, 1, 1, 9, 0),
        DateTime(2026, 1, 4, 9, 0),
        DateTime(2026, 1, 7, 9, 0),
        DateTime(2026, 1, 10, 9, 0),
      ]);
    });

    test('PRN never auto-generates occurrences', () {
      final schedule = MedicationSchedule(
        id: 's4',
        medicationId: 'm1',
        type: ScheduleType.prn,
        time: '08:00',
        startDate: DateTime(2026, 1, 1),
        timezone: 'Africa/Casablanca',
        doseAmount: '1',
      );

      final occurrences = DoseEngine.computeOccurrences(
        schedule: schedule,
        windowStart: DateTime(2026, 1, 1),
        windowEnd: DateTime(2026, 1, 30),
      );

      expect(occurrences, isEmpty);
    });

    test('respects endDate — no occurrences generated after it', () {
      final schedule = MedicationSchedule(
        id: 's5',
        medicationId: 'm1',
        type: ScheduleType.daily,
        time: '08:00',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 3),
        timezone: 'Africa/Casablanca',
        doseAmount: '1',
      );

      final occurrences = DoseEngine.computeOccurrences(
        schedule: schedule,
        windowStart: DateTime(2026, 1, 1),
        windowEnd: DateTime(2026, 1, 10),
      );

      expect(occurrences.length, 3);
    });
  });
}
