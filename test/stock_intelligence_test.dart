import 'package:flutter_test/flutter_test.dart';
import 'package:dawacare/features/medications/domain/stock_intelligence.dart';
import 'package:dawacare/models/medication.dart';
import 'package:dawacare/models/medication_schedule.dart';

Medication medication({double stock = 30, double threshold = 5}) => Medication(
      id: 'med-1',
      patientId: 'patient-1',
      name: 'Test',
      startDate: DateTime(2026, 1, 1),
      active: true,
      createdBy: 'patient-1',
      createdAt: DateTime(2026, 1, 1),
      stockEnabled: true,
      stockQuantity: stock,
      stockUnit: 'tablet',
      lowStockThreshold: threshold,
    );

MedicationSchedule schedule(ScheduleType type, String amount, {int? interval, List<int> days = const []}) => MedicationSchedule(
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
  });

  group('dailyConsumption', () {
    test('daily schedule contributes full dose', () {
      expect(
        StockIntelligence.dailyConsumption(
          medication: medication(),
          schedules: [schedule(ScheduleType.daily, '2 tablets')],
        ),
        2,
      );
    });

    test('weekly and specific-days schedules are averaged over seven days', () {
      final weekly = schedule(ScheduleType.weekly, '7 tablets');
      final specific = schedule(ScheduleType.specificDays, '2 tablets', days: [1, 3, 5]);
      expect(
        StockIntelligence.dailyConsumption(
          medication: medication(),
          schedules: [weekly, specific],
        ),
        closeTo(1 + 6 / 7, 0.0001),
      );
    });

    test('interval schedule uses intervalDays', () {
      expect(
        StockIntelligence.dailyConsumption(
          medication: medication(),
          schedules: [schedule(ScheduleType.interval, '1 tablet', interval: 2)],
        ),
        0.5,
      );
    });

    test('PRN and one-time schedules do not create recurring daily consumption', () {
      expect(
        StockIntelligence.dailyConsumption(
          medication: medication(),
          schedules: [
            schedule(ScheduleType.prn, '2 tablets'),
            schedule(ScheduleType.once, '5 tablets'),
          ],
        ),
        0,
      );
    });
  });

  test('days remaining is stock divided by expected daily consumption', () {
    expect(
      StockIntelligence.daysRemaining(
        medication: medication(stock: 30),
        schedules: [schedule(ScheduleType.daily, '2 tablets')],
      ),
      15,
    );
  });

  test('low and out of stock are mutually exclusive', () {
    expect(StockIntelligence.isLowStock(medication(stock: 5)), isTrue);
    expect(StockIntelligence.isOutOfStock(medication(stock: 0)), isTrue);
    expect(StockIntelligence.isLowStock(medication(stock: 0)), isFalse);
    expect(StockIntelligence.isLowStock(medication(stock: 8)), isFalse);
  });

  test('disabled stock never reports low or out of stock', () {
    final med = medication(stock: 0).copyWith(stockEnabled: false);
    expect(StockIntelligence.isLowStock(med), isFalse);
    expect(StockIntelligence.isOutOfStock(med), isFalse);
    expect(
      StockIntelligence.daysRemaining(
        medication: med,
        schedules: [schedule(ScheduleType.daily, '1 tablet')],
      ),
      isNull,
    );
  });
}
