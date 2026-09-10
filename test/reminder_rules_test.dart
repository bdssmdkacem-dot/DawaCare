import 'package:flutter_test/flutter_test.dart';
import 'package:dawacare/features/reminders/domain/reminder_rules.dart';
import 'package:dawacare/models/dose_instance.dart';

DoseInstance _dose({
  required DateTime scheduledAt,
  DoseStatus status = DoseStatus.pending,
}) {
  return DoseInstance(
    id: 'd1',
    medicationId: 'm1',
    scheduleId: 's1',
    patientId: 'p1',
    medicationName: 'Test medication',
    doseAmount: '1',
    scheduledAt: scheduledAt,
    status: status,
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('ReminderRules', () {
    final now = DateTime(2026, 9, 10, 12, 0);

    test('schedules a pending dose inside the 48-hour horizon', () {
      final dose = _dose(scheduledAt: now.add(const Duration(hours: 12)));
      expect(ReminderRules.shouldSchedule(dose: dose, now: now), isTrue);
      expect(ReminderRules.shouldCancel(dose: dose, now: now), isFalse);
    });

    test('does not schedule a dose beyond the 48-hour horizon', () {
      final dose = _dose(scheduledAt: now.add(const Duration(hours: 48)));
      expect(ReminderRules.shouldSchedule(dose: dose, now: now), isFalse);
      expect(ReminderRules.shouldCancel(dose: dose, now: now), isTrue);
    });

    test('allows a dose up to five minutes late', () {
      final dose = _dose(scheduledAt: now.subtract(const Duration(minutes: 5)));
      expect(ReminderRules.shouldSchedule(dose: dose, now: now), isTrue);
    });

    test('cancels resolved taken, skipped and cancelled doses', () {
      for (final status in [
        DoseStatus.taken,
        DoseStatus.skipped,
        DoseStatus.cancelled,
      ]) {
        final dose = _dose(
          scheduledAt: now.add(const Duration(hours: 1)),
          status: status,
        );
        expect(ReminderRules.shouldSchedule(dose: dose, now: now), isFalse);
        expect(ReminderRules.shouldCancel(dose: dose, now: now), isTrue);
      }
    });

    test('never lets normal sync replace a snooze reminder', () {
      final dose = _dose(
        scheduledAt: now.add(const Duration(hours: 1)),
        status: DoseStatus.snoozed,
      );
      expect(ReminderRules.shouldSchedule(dose: dose, now: now), isFalse);
      expect(ReminderRules.shouldCancel(dose: dose, now: now), isFalse);
    });

    test('does not schedule a dose more than five minutes in the past', () {
      final dose = _dose(scheduledAt: now.subtract(const Duration(minutes: 6)));
      expect(ReminderRules.shouldSchedule(dose: dose, now: now), isFalse);
      expect(ReminderRules.shouldCancel(dose: dose, now: now), isTrue);
    });

    test('never reschedules a missed dose, even if its timestamp is future', () {
      final dose = _dose(
        scheduledAt: now.add(const Duration(hours: 1)),
        status: DoseStatus.missed,
      );
      expect(ReminderRules.shouldSchedule(dose: dose, now: now), isFalse);
      expect(ReminderRules.shouldCancel(dose: dose, now: now), isTrue);
    });
  });
}
