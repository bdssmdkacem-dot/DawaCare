import 'package:flutter_test/flutter_test.dart';
import 'package:dawacare/features/medications/domain/stock_intelligence.dart';
import 'package:dawacare/models/medication.dart';
import 'package:dawacare/models/medication_schedule.dart';

Medication _medication({
  double stock = 30,
  double threshold = 5,
  bool stockEnabled = true,
  String stockUnit = 'tablet',
}) {
  return Medication(
    id: 'med-1',
    patientId: 'patient-1',
    name: 'Test',
    startDate: DateTime(2026, 1, 1),
    active: true,
    createdBy: 'patient-1',
    createdAt: DateTime(2026, 1, 1),
    stockEnabled: stockEnabled,
    stockQuantity: stock,
    stockUnit: stockUnit,
    lowStockThreshold: threshold,
  );
}

MedicationSchedule _schedule(
  ScheduleType type,
  String amount, {
  int? interval,
  List<int> days = const [],
}) {
  return MedicationSchedule(
    id: 'schedule-${type.name}',
    medicationId: 'med-1',
    type: type,
    time: '08:00',
    daysOfWeek: days,
    intervalDays: interval,
    doseAmount: amount,
    startDate: DateTime(2026, 1, 1),
    timezone: 'Africa/Casablanca',
  );
}

void main() {
  group('parseDoseQuantity', () {
    test('parses decimal with dot and configured unit', () {
      expect(StockIntelligence.parseDoseQuantity('2.5 tablet', 'tablet'), 2.5);
    });

    test('parses decimal with comma', () {
      expect(StockIntelligence.parseDoseQuantity('2,5 tablet', 'tablet'), 2.5);
    });

    test('selects the quantity attached to the stock unit', () {
      expect(
        StockIntelligence.parseDoseQuantity('500 mg, 2 tablets', 'tablet'),
        2,
      );
    });

    test('falls back to the first number when the configured unit is absent', () {
      expect(StockIntelligence.parseDoseQuantity('2 tablets', 'capsule'), 2);
    });

    test('returns null for an empty or non-numeric dose', () {
      expect(StockIntelligence.parseDoseQuantity('', 'tablet'), isNull);
      expect(StockIntelligence.parseDoseQuantity('as needed', 'tablet'), isNull);
    });
  });

  group('dailyConsumption', () {
    test('daily schedule contributes full dose', () {
      expect(
        StockIntelligence.dailyConsumption(
          medication: _medication(),
          schedules: [_schedule(ScheduleType.daily, '2 tablets')],
        ),
        2,
      );
    });

    test('weekly schedule uses its selected days, matching DoseEngine', () {
      final weekly = _schedule(
        ScheduleType.weekly,
        '2 tablets',
        days: [1, 3, 5],
      );
      expect(
        StockIntelligence.dailyConsumption(
          medication: _medication(),
          schedules: [weekly],
        ),
        closeTo(6 / 7, 0.0001),
      );
    });

    test('weekly schedule with no selected days has no consumption', () {
      expect(
        StockIntelligence.dailyConsumption(
          medication: _medication(),
          schedules: [_schedule(ScheduleType.weekly, '7 tablets')],
        ),
        0,
      );
    });

    test('specific-days schedule is averaged over seven days', () {
      final specific = _schedule(
        ScheduleType.specificDays,
        '2 tablets',
        days: [1, 3, 5],
      );
      expect(
        StockIntelligence.dailyConsumption(
          medication: _medication(),
          schedules: [specific],
        ),
        closeTo(6 / 7, 0.0001),
      );
    });

    test('interval schedule uses intervalDays', () {
      expect(
        StockIntelligence.dailyConsumption(
          medication: _medication(),
          schedules: [
            _schedule(ScheduleType.interval, '1 tablet', interval: 2),
          ],
        ),
        0.5,
      );
    });

    test('PRN and one-time schedules do not create recurring daily consumption', () {
      expect(
        StockIntelligence.dailyConsumption(
          medication: _medication(),
          schedules: [
            _schedule(ScheduleType.prn, '2 tablets'),
            _schedule(ScheduleType.once, '5 tablets'),
          ],
        ),
        0,
      );
    });

    test('disabled stock tracking reports zero consumption', () {
      expect(
        StockIntelligence.dailyConsumption(
          medication: _medication(stockEnabled: false),
          schedules: [_schedule(ScheduleType.daily, '2 tablets')],
        ),
        0,
      );
    });
  });

  test('days remaining is stock divided by expected daily consumption', () {
    expect(
      StockIntelligence.daysRemaining(
        medication: _medication(stock: 30),
        schedules: [_schedule(ScheduleType.daily, '2 tablets')],
      ),
      15,
    );
  });

  test('days remaining is null when there is no predictable consumption', () {
    expect(
      StockIntelligence.daysRemaining(
        medication: _medication(stock: 30),
        schedules: [_schedule(ScheduleType.prn, '2 tablets')],
      ),
      isNull,
    );
  });

  test('depletion date follows calculated coverage', () {
    final from = DateTime(2026, 1, 1);
    final date = StockIntelligence.depletionDate(
      medication: _medication(stock: 10),
      schedules: [_schedule(ScheduleType.daily, '2 tablets')],
      from: from,
    );

    expect(date, DateTime(2026, 1, 6));
  });

  test('low and out of stock are mutually exclusive', () {
    expect(StockIntelligence.isLowStock(_medication(stock: 5)), isTrue);
    expect(StockIntelligence.isOutOfStock(_medication(stock: 0)), isTrue);
    expect(StockIntelligence.isLowStock(_medication(stock: 0)), isFalse);
    expect(StockIntelligence.isLowStock(_medication(stock: 8)), isFalse);
  });

  test('disabled stock never reports low or out of stock', () {
    final med = _medication(stock: 0, stockEnabled: false);
    expect(StockIntelligence.isLowStock(med), isFalse);
    expect(StockIntelligence.isOutOfStock(med), isFalse);
    expect(
      StockIntelligence.daysRemaining(
        medication: med,
        schedules: [_schedule(ScheduleType.daily, '1 tablet')],
      ),
      isNull,
    );
  });
}
