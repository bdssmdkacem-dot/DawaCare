import 'package:dawacare/features/medications/data/medication_repository.dart';
import 'package:dawacare/models/medication.dart';
import 'package:dawacare/models/medication_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Medication edit lifecycle regressions', () {
    test('prescription serialization never carries stock quantity', () {
      final medication = Medication(
        id: 'med-1',
        patientId: 'patient-1',
        name: 'Medication',
        genericName: 'Generic',
        strength: '500 mg',
        dosageForm: 'Tablet',
        instructions: 'Take as prescribed',
        startDate: DateTime(2026, 9, 1),
        endDate: null,
        active: true,
        createdBy: 'user-1',
        createdAt: DateTime(2026, 9, 1),
        stockEnabled: true,
        stockQuantity: 42,
        stockUnit: 'tablet',
      );

      final data = medication.toInsertMap();

      expect(data['stock_quantity'], 0);
      expect(medication.stockQuantity, 42);
    });

    test('schedule edit payload preserves lifecycle fields', () {
      final schedule = MedicationSchedule(
        id: 'schedule-1',
        medicationId: 'med-1',
        type: ScheduleType.specificDays,
        time: '08:30',
        daysOfWeek: const [1, 3, 5],
        intervalDays: null,
        doseAmount: '2',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 10, 1),
        timezone: 'Africa/Casablanca',
      );

      final data = schedule.toInsertMap('med-1');

      expect(data['type'], 'SPECIFIC_DAYS');
      expect(data['time'], '08:30');
      expect(data['days_of_week'], [1, 3, 5]);
      expect(data['dose_amount'], '2');
      expect(data['start_date'], '2026-09-01');
      expect(data['end_date'], '2026-10-01');
      expect(data['timezone'], 'Africa/Casablanca');
    });

    test('weekly schedule remains distinguishable from specific-days schedule', () {
      final weekly = MedicationSchedule(
        id: 'weekly-1',
        medicationId: 'med-1',
        type: ScheduleType.weekly,
        time: '09:00',
        daysOfWeek: const [2, 6],
        doseAmount: '1',
        startDate: DateTime(2026, 9, 1),
        timezone: 'Africa/Casablanca',
      );

      final data = weekly.toInsertMap('med-1');

      expect(data['type'], 'WEEKLY');
      expect(data['days_of_week'], [2, 6]);
    });

    test('schedule replacement targets only unresolved future doses', () {
      expect(
        MedicationRepository.futureUnresolvedDoseStatuses,
        containsAll(<String>['PENDING', 'REMINDER_SENT', 'SNOOZED', 'MISSED']),
      );
      expect(
        MedicationRepository.futureUnresolvedDoseStatuses,
        isNot(contains('TAKEN')),
      );
      expect(
        MedicationRepository.futureUnresolvedDoseStatuses,
        isNot(contains('SKIPPED')),
      );
      expect(
        MedicationRepository.futureUnresolvedDoseStatuses,
        isNot(contains('CANCELLED')),
      );
    });
  });
}
