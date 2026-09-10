import 'package:flutter_test/flutter_test.dart';
import 'package:dawacare/features/doses/domain/dose_engine.dart';
import 'package:dawacare/models/medication_schedule.dart';

MedicationSchedule _schedule({
  required String id,
  required ScheduleType type,
  required String time,
  required DateTime startDate,
  DateTime? endDate,
  int? intervalDays,
  List<int> daysOfWeek = const [],
}) {
  return MedicationSchedule(
    id: id,
    medicationId: 'm1',
    type: type,
    time: time,
    daysOfWeek: daysOfWeek,
    intervalDays: intervalDays,
    startDate: startDate,
    endDate: endDate,
    timezone: 'Africa/Casablanca',
    doseAmount: '1',
  );
}

void main() {
  group('DoseEngine.computeOccurrences', () {
    test('DAILY generates one occurrence per day in the window', () {
      final schedule = _schedule(
        id: 's1',
        type: ScheduleType.daily,
        time: '08:00',
        startDate: DateTime(2026, 1, 1),
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
      final schedule = _schedule(
        id: 's2',
        type: ScheduleType.specificDays,
        time: '20:00',
        daysOfWeek: const [2, 5],
        startDate: DateTime(2026, 1, 1),
      );

      final occurrences = DoseEngine.computeOccurrences(
        schedule: schedule,
        windowStart: DateTime(2026, 1, 1),
        windowEnd: DateTime(2026, 1, 14),
      );

      expect(
        occurrences.every((d) =>
            d.weekday == DateTime.monday || d.weekday == DateTime.thursday),
        isTrue,
      );
      expect(occurrences.length, 4);
    });

    test('INTERVAL respects the start date and step size', () {
      final schedule = _schedule(
        id: 's3',
        type: ScheduleType.interval,
        time: '09:00',
        intervalDays: 3,
        startDate: DateTime(2026, 1, 1),
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
      final schedule = _schedule(
        id: 's4',
        type: ScheduleType.prn,
        time: '08:00',
        startDate: DateTime(2026, 1, 1),
      );

      final occurrences = DoseEngine.computeOccurrences(
        schedule: schedule,
        windowStart: DateTime(2026, 1, 1),
        windowEnd: DateTime(2026, 1, 30),
      );

      expect(occurrences, isEmpty);
    });

    test('respects endDate — no occurrences generated after it', () {
      final schedule = _schedule(
        id: 's5',
        type: ScheduleType.daily,
        time: '08:00',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 3),
      );

      final occurrences = DoseEngine.computeOccurrences(
        schedule: schedule,
        windowStart: DateTime(2026, 1, 1),
        windowEnd: DateTime(2026, 1, 10),
      );

      expect(occurrences.length, 3);
      expect(occurrences.last, DateTime(2026, 1, 3, 8));
    });

    test('handles midnight without shifting to the next calendar day', () {
      final schedule = _schedule(
        id: 's6',
        type: ScheduleType.daily,
        time: '00:00',
        startDate: DateTime(2026, 1, 10),
      );

      final occurrences = DoseEngine.computeOccurrences(
        schedule: schedule,
        windowStart: DateTime(2026, 1, 10),
        windowEnd: DateTime(2026, 1, 12, 23, 59),
      );

      expect(occurrences, [
        DateTime(2026, 1, 10),
        DateTime(2026, 1, 11),
        DateTime(2026, 1, 12),
      ]);
    });

    test('does not generate a dose before the schedule start time', () {
      final schedule = _schedule(
        id: 's7',
        type: ScheduleType.daily,
        time: '08:30',
        startDate: DateTime(2026, 1, 10, 12),
      );

      final occurrences = DoseEngine.computeOccurrences(
        schedule: schedule,
        windowStart: DateTime(2026, 1, 10),
        windowEnd: DateTime(2026, 1, 12, 23, 59),
      );

      expect(occurrences, [
        DateTime(2026, 1, 11, 8, 30),
        DateTime(2026, 1, 12, 8, 30),
      ]);
    });
  });
}
