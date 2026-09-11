import 'package:flutter_test/flutter_test.dart';

import 'package:dawacare/features/reminders/domain/reminder_rules.dart';
import 'package:dawacare/models/dose_instance.dart';

DoseInstance _dose(DoseStatus status, DateTime scheduledAt) => DoseInstance(
      id: 'dose-1',
      medicationId: 'med-1',
      scheduleId: 'schedule-1',
      patientId: 'patient-1',
      medicationName: 'Medicine',
      doseAmount: '1',
      scheduledAt: scheduledAt,
      status: status,
      updatedAt: scheduledAt,
    );

void main() {
  final now = DateTime(2026, 9, 11, 14);

  group('Reminder lifecycle scheduling rules', () {
    test('PENDING and REMINDER_SENT are schedulable within the horizon', () {
      expect(
        ReminderRules.shouldSchedule(
          dose: _dose(DoseStatus.pending, now.add(const Duration(hours: 1))),
          now: now,
        ),
        isTrue,
      );
      expect(
        ReminderRules.shouldSchedule(
          dose: _dose(DoseStatus.reminderSent, now.add(const Duration(hours: 1))),
          now: now,
        ),
        isTrue,
      );
    });

    test('SNOOZED owns its follow-up notification and is not rescheduled by normal sync', () {
      expect(
        ReminderRules.shouldSchedule(
          dose: _dose(DoseStatus.snoozed, now.add(const Duration(minutes: 10))),
          now: now,
        ),
        isFalse,
      );
    });

    test('TAKEN, SKIPPED, CANCELLED and MISSED never schedule normal reminders', () {
      for (final status in const [
        DoseStatus.taken,
        DoseStatus.skipped,
        DoseStatus.cancelled,
        DoseStatus.missed,
      ]) {
        expect(
          ReminderRules.shouldSchedule(
            dose: _dose(status, now.add(const Duration(hours: 1))),
            now: now,
          ),
          isFalse,
        );
      }
    });

    test('a dose more than 48 hours away is outside the scheduling horizon', () {
      expect(
        ReminderRules.shouldSchedule(
          dose: _dose(DoseStatus.pending, now.add(const Duration(hours: 49))),
          now: now,
        ),
        isFalse,
      );
    });

    test('a dose older than the late grace window is cancelled from local scheduling', () {
      expect(
        ReminderRules.shouldCancel(
          dose: _dose(DoseStatus.reminderSent, now.subtract(const Duration(minutes: 6))),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
