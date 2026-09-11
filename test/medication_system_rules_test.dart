import 'package:dawacare/features/doses/domain/dose_engine.dart';
import 'package:dawacare/features/medications/domain/medication_schedule_calculator.dart';
import 'package:dawacare/features/medications/domain/stock_intelligence.dart';
import 'package:dawacare/models/medication.dart';
import 'package:dawacare/models/medication_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

Medication _medication({
  bool stockEnabled = true,
  double stockQuantity = 30,
  double threshold = 5,
  DateTime? endDate,
}) {
  final now = DateTime(2026, 9, 11, 10);
  return Medication(
    id: 'med-1',
    patientId: 'patient-1',
    name: 'Test medicine',
    startDate: DateTime(2026, 9, 1),
    endDate: endDate,
    active: true,
    createdBy: 'patient-1',
    createdAt: now,
    stockEnabled: stockEnabled,
    stockQuantity: stockQuantity,
    stockUnit: 'tablet',
    lowStockThreshold: threshold,
  );
}

MedicationSchedule _schedule({
  ScheduleType type = ScheduleType.daily,
  String time = '08:00',
  List<int> days = const [],
  int? intervalDays,
  String dose = '1 tablet',
  DateTime? startDate,
  DateTime? endDate,
}) {
  return MedicationSchedule(
    id: 'schedule-1',
    medicationId: 'med-1',
    type: type,
    time: time,
    daysOfWeek: days,
    intervalDays: intervalDays,
    doseAmount: dose,
    startDate: startDate ?? DateTime(2026, 9, 1),
    endDate: endDate,
    timezone: 'Africa/Casablanca',
  );
}

void main() {
  group('Medication schedule rules', () {
    test('daily schedule generates one occurrence per day', () {
      final occurrences = DoseEngine.computeOccurrences(
        schedule: _schedule(),
        windowStart: DateTime(2026, 9, 10),
        windowEnd: DateTime(2026, 9, 12, 23, 59),
      );

      expect(occurrences, [
        DateTime(2026, 9, 10, 8),
        DateTime(2026, 9, 11, 8),
        DateTime(2026, 9, 12, 8),
      ]);
    });

    test('specific days only generates selected weekdays', () {
      // App convention: 1 = Sunday ... 7 = Saturday.
      final occurrences = DoseEngine.computeOccurrences(
        schedule: _schedule(
          type: ScheduleType.specificDays,
          days: const [2, 4, 6],
        ),
        windowStart: DateTime(2026, 9, 6),
        windowEnd: DateTime(2026, 9, 12, 23, 59),
      );

      expect(occurrences, [
        DateTime(2026, 9, 7, 8),
        DateTime(2026, 9, 9, 8),
        DateTime(2026, 9, 11, 8),
      ]);
    });

    test('interval schedule follows its start date cadence', () {
      final occurrences = DoseEngine.computeOccurrences(
        schedule: _schedule(
          type: ScheduleType.interval,
          intervalDays: 2,
          startDate: DateTime(2026, 9, 1),
        ),
        windowStart: DateTime(2026, 9, 1),
        windowEnd: DateTime(2026, 9, 6, 23, 59),
      );

      expect(occurrences, [
        DateTime(2026, 9, 1, 8),
        DateTime(2026, 9, 3, 8),
        DateTime(2026, 9, 5, 8),
      ]);
    });

    test('once schedule produces exactly one occurrence', () {
      final occurrences = DoseEngine.computeOccurrences(
        schedule: _schedule(
          type: ScheduleType.once,
          startDate: DateTime(2026, 9, 15),
        ),
        windowStart: DateTime(2026, 9, 1),
        windowEnd: DateTime(2026, 9, 30, 23, 59),
      );

      expect(occurrences, [DateTime(2026, 9, 15, 8)]);
    });

    test('PRN never generates scheduled dose instances', () {
      final occurrences = DoseEngine.computeOccurrences(
        schedule: _schedule(type: ScheduleType.prn),
        windowStart: DateTime(2026, 9, 1),
        windowEnd: DateTime(2026, 9, 30),
      );

      expect(occurrences, isEmpty);
    });

    test('end date is inclusive', () {
      final occurrences = DoseEngine.computeOccurrences(
        schedule: _schedule(endDate: DateTime(2026, 9, 3)),
        windowStart: DateTime(2026, 9, 1),
        windowEnd: DateTime(2026, 9, 5, 23, 59),
      );

      expect(occurrences.length, 3);
      expect(occurrences.last, DateTime(2026, 9, 3, 8));
    });
  });

  group('Medication stock rules', () {
    test('parses decimal quantities using the configured stock unit', () {
      expect(
        StockIntelligence.parseDoseQuantity('500 mg, 2.5 tablets', 'tablet'),
        2.5,
      );
      expect(
        StockIntelligence.parseDoseQuantity('1,5 tablet', 'tablet'),
        1.5,
      );
    });

    test('PRN and once schedules do not reduce projected daily stock', () {
      final schedules = [
        _schedule(type: ScheduleType.daily, dose: '2 tablets'),
        _schedule(type: ScheduleType.prn, dose: '1 tablet'),
        _schedule(type: ScheduleType.once, dose: '10 tablets'),
      ];

      expect(
        StockIntelligence.dailyConsumption(
          medication: _medication(),
          schedules: schedules,
        ),
        2,
      );
    });

    test('specific weekdays are averaged over seven calendar days', () {
      final schedules = [
        _schedule(
          type: ScheduleType.specificDays,
          days: const [1, 3, 5],
          dose: '2 tablets',
        ),
      ];

      expect(
        StockIntelligence.dailyConsumption(
          medication: _medication(),
          schedules: schedules,
        ),
        closeTo(6 / 7, 0.000001),
      );
    });

    test('days remaining is stock divided by projected daily consumption', () {
      final schedules = [_schedule(dose: '2 tablets')];
      final days = StockIntelligence.daysRemaining(
        medication: _medication(stockQuantity: 10),
        schedules: schedules,
      );

      expect(days, 5);
    });

    test('disabled stock tracking does not report days remaining', () {
      final days = StockIntelligence.daysRemaining(
        medication: _medication(stockEnabled: false),
        schedules: [_schedule()],
      );

      expect(days, isNull);
    });

    test('status distinguishes out-of-stock and low-stock states', () {
      final schedules = [_schedule()];

      expect(
        MedicationScheduleCalculator.status(
          _medication(stockQuantity: 0),
          schedules,
          DateTime(2026, 9, 11),
        ),
        MedicationStatus.outOfStock,
      );

      expect(
        MedicationScheduleCalculator.status(
          _medication(stockQuantity: 5),
          schedules,
          DateTime(2026, 9, 11),
        ),
        MedicationStatus.lowStock,
      );
    });

    test('treatment end date caps days remaining coverage', () {
      final medication = _medication(
        stockQuantity: 100,
        endDate: DateTime(2026, 9, 16),
      );
      final days = MedicationScheduleCalculator.daysRemaining(
        medication,
        [_schedule(dose: '1 tablet')],
        DateTime(2026, 9, 11),
      );

      expect(days, closeTo(5, 0.000001));
    });
  });
}
