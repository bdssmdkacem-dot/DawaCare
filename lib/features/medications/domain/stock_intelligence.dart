import '../../../models/medication.dart';
import '../../../models/medication_schedule.dart';

/// Pure stock calculations. It never mutates Medication or schedules.
class StockIntelligence {
  StockIntelligence._();

  static double? parseDoseQuantity(String doseAmount, String stockUnit) {
    final text = doseAmount.trim();
    if (text.isEmpty) return null;

    final unit = stockUnit.trim();
    if (unit.isNotEmpty) {
      final unitIndex = text.toLowerCase().indexOf(unit.toLowerCase());
      if (unitIndex >= 0) {
        final beforeUnit = text.substring(0, unitIndex);
        final match = RegExp(r'([0-9]+(?:[.,][0-9]+)?)\s*$').firstMatch(beforeUnit);
        if (match != null) return double.tryParse(match.group(1)!.replaceAll(',', '.'));
      }
    }

    final match = RegExp(r'([0-9]+(?:[.,][0-9]+)?)').firstMatch(text);
    return match == null ? null : double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  static double dailyConsumption({
    required Medication medication,
    required List<MedicationSchedule> schedules,
  }) {
    if (!medication.stockEnabled) return 0;

    var total = 0.0;
    for (final schedule in schedules) {
      if (schedule.type == ScheduleType.prn || schedule.type == ScheduleType.once) continue;
      final amount = parseDoseQuantity(schedule.doseAmount, medication.stockUnit);
      if (amount == null || amount <= 0) continue;

      switch (schedule.type) {
        case ScheduleType.daily:
          total += amount;
          break;
        case ScheduleType.weekly:
          total += amount / 7;
          break;
        case ScheduleType.specificDays:
          total += amount * schedule.daysOfWeek.toSet().length / 7;
          break;
        case ScheduleType.interval:
          final interval = schedule.intervalDays;
          if (interval != null && interval > 0) total += amount / interval;
          break;
        case ScheduleType.once:
        case ScheduleType.prn:
          break;
      }
    }
    return total;
  }

  static double? daysRemaining({
    required Medication medication,
    required List<MedicationSchedule> schedules,
  }) {
    if (!medication.stockEnabled) return null;
    final daily = dailyConsumption(medication: medication, schedules: schedules);
    if (daily <= 0) return null;
    return medication.stockQuantity / daily;
  }

  static bool isOutOfStock(Medication medication) =>
      medication.stockEnabled && medication.stockQuantity <= 0;

  static bool isLowStock(Medication medication) =>
      medication.stockEnabled &&
      !isOutOfStock(medication) &&
      medication.stockQuantity <= medication.lowStockThreshold;

  static DateTime? depletionDate({
    required Medication medication,
    required List<MedicationSchedule> schedules,
    DateTime? from,
  }) {
    final days = daysRemaining(medication: medication, schedules: schedules);
    if (days == null) return null;
    final start = from ?? DateTime.now();
    return start.add(Duration(minutes: (days * 24 * 60).floor()));
  }
}
