import 'package:flutter_test/flutter_test.dart';

import 'package:dawacare/features/medications/domain/medication_schedule_calculator.dart';
import 'package:dawacare/models/medication.dart';
import 'package:dawacare/models/medication_schedule.dart';

MedicationSchedule schedule({
  ScheduleType type = ScheduleType.daily,
  String time = '08:00',
  String dose = '1',
  List<int> days = const [],
  int? intervalDays,
  DateTime? start,
  DateTime? end,
}) {
  return MedicationSchedule(
    id: 'schedule-1',
    medicationId: 'med-1',
    type: type,
    time: time,
    daysOfWeek: days,
    intervalDays: intervalDays,
    doseAmount: dose,
    startDate: start ?? DateTime(2026, 9, 10),
    endDate: end,
    timezone: 'Africa/Casablanca',
  );
}

Medication medication({
  bool active = true,
  bool stockEnabled = true,
  double stock = 30,
  DateTime? end,
}) {
  return Medication(
    id: 'med-1',
    patientId: 'patient-1',
    name: 'Test medicine',
    startDate: DateTime(2026, 9, 10),
    endDate: end,
    active: active,
    createdBy: 'user-1',
    createdAt: DateTime(2026, 9, 10),
    stockEnabled: stockEnabled,
    stockQuantity: stock,
    stockUnit: 'tablet',
  );
}

void main() {
  final now = DateTime(2026, 9, 10, 7, 30);

  group('nextDose', () {
    test('uses DoseEngine rules for daily schedules', () {
      final next = MedicationScheduleCalculator.nextDose([schedule()], now);
      expect(next, DateTime(2026, 9, 10, 8));
    });

    test('returns null for PRN', () {
      final next = MedicationScheduleCalculator.nextDose([
        schedule(type: ScheduleType.prn),
      ], now);
      expect(next, isNull);
    });

    test('respects specific weekdays', () {
      // 10 Sep 2026 is Thursday; app weekday convention is Sunday=1.
      final next = MedicationScheduleCalculator.nextDose([
        schedule(type: ScheduleType.specificDays, days: [6], time: '09:00'),
      ], now);
      expect(next, DateTime(2026, 9, 11, 9));
    });
  });

  group('dailyConsumption', () {
    test('counts multiple daily schedules', () {
      expect(
        MedicationScheduleCalculator.dailyConsumption([
          schedule(time: '08:00', dose: '1'),
          schedule(time: '20:00', dose: '1'),
        ]),
        2,
      );
    });

    test('supports decimal doses', () {
      expect(
        MedicationScheduleCalculator.dailyConsumption([schedule(dose: '2.5 ml')]),
        2.5,
      );
    });

    test('averages specific days over seven days', () {
      expect(
        MedicationScheduleCalculator.dailyConsumption([
          schedule(type: ScheduleType.specificDays, days: [1, 3, 5], dose: '2'),
        ]),
        closeTo(6 / 7, 0.000001),
      );
    });

    test('uses interval days as the denominator', () {
      expect(
        MedicationScheduleCalculator.dailyConsumption([
          schedule(type: ScheduleType.interval, intervalDays: 8, dose: '1'),
        ]),
        0.125,
      );
    });

    test('does not turn once or PRN into daily consumption', () {
      expect(
        MedicationScheduleCalculator.dailyConsumption([
          schedule(type: ScheduleType.once, dose: '5'),
          schedule(type: ScheduleType.prn, dose: '2'),
        ]),
        0,
      );
    });
  });

  group('daysRemaining', () {
    test('calculates stock divided by daily consumption', () {
      final days = MedicationScheduleCalculator.daysRemaining(
        medication(stock: 30),
        [schedule(dose: '3')],
        now,
      );
      expect(days, 10);
    });

    test('returns null for PRN/once-only regimens', () {
      expect(
        MedicationScheduleCalculator.daysRemaining(
          medication(stock: 30),
          [schedule(type: ScheduleType.prn)],
          now,
        ),
        isNull,
      );
      expect(
        MedicationScheduleCalculator.daysRemaining(
          medication(stock: 30),
          [schedule(type: ScheduleType.once)],
          now,
        ),
        isNull,
      );
    });

    test('returns zero when stock is empty', () {
      expect(
        MedicationScheduleCalculator.daysRemaining(
          medication(stock: 0),
          [schedule()],
          now,
        ),
        0,
      );
    });
  });

  group('status', () {
    test('inactive is not reported as ending soon', () {
      expect(
        MedicationScheduleCalculator.status(
          medication(active: false),
          [schedule()],
          now,
        ),
        MedicationStatus.inactive,
      );
    });

    test('empty stock has priority over low stock', () {
      expect(
        MedicationScheduleCalculator.status(
          medication(stock: 0),
          [schedule()],
          now,
        ),
        MedicationStatus.outOfStock,
      );
    });

    test('all-PRN medication gets PRN status', () {
      expect(
        MedicationScheduleCalculator.status(
          medication(),
          [schedule(type: ScheduleType.prn)],
          now,
        ),
        MedicationStatus.prn,
      );
    });
  });
}
