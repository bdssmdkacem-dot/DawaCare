import '../../../models/medication.dart';
import '../../../models/medication_schedule.dart';
import '../../doses/domain/dose_engine.dart';

enum MedicationStatus {
  active,
  lowStock,
  outOfStock,
  endingSoon,
  inactive,
  prn,
}

/// Single source of truth for medication-level schedule insights.
///
/// It deliberately delegates occurrence calculation to [DoseEngine], while
/// keeping stock/treatment calculations independent from persistence.
class MedicationScheduleCalculator {
  MedicationScheduleCalculator._();

  static DateTime? nextDose(
    List<MedicationSchedule> schedules,
    DateTime now, {
    Duration horizon = const Duration(days: 30),
  }) {
    DateTime? next;
    final end = now.add(horizon);
    for (final schedule in schedules) {
      for (final occurrence in DoseEngine.computeOccurrences(
        schedule: schedule,
        windowStart: now,
        windowEnd: end,
      )) {
        if (!occurrence.isBefore(now) && (next == null || occurrence.isBefore(next))) {
          next = occurrence;
        }
      }
    }
    return next;
  }

  /// Average units consumed per calendar day.
  ///
  /// PRN and once-only schedules are intentionally excluded: neither defines
  /// an ongoing daily consumption rate. This prevents a one-time dose from
  /// making the stock appear to run down every day.
  static double dailyConsumption(List<MedicationSchedule> schedules) {
    var total = 0.0;
    for (final schedule in schedules) {
      final dose = parseDose(schedule.doseAmount);
      if (dose <= 0) continue;
      switch (schedule.type) {
        case ScheduleType.daily:
          total += dose;
          break;
        case ScheduleType.weekly:
        case ScheduleType.specificDays:
          if (schedule.daysOfWeek.isNotEmpty) {
            total += dose * schedule.daysOfWeek.length / 7;
          }
          break;
        case ScheduleType.interval:
          final days = schedule.intervalDays ?? 0;
          if (days > 0) total += dose / days;
          break;
        case ScheduleType.once:
        case ScheduleType.prn:
          break;
      }
    }
    return total;
  }

  /// Returns stock coverage in days, capped by the remaining treatment period
  /// when an end date exists. A PRN/once-only regimen has no meaningful daily
  /// rate, so null is returned instead of a misleading number.
  static double? daysRemaining(
    Medication medication,
    List<MedicationSchedule> schedules,
    DateTime now,
  ) {
    if (!medication.stockEnabled) return null;
    if (medication.stockQuantity <= 0) return 0;

    final daily = dailyConsumption(schedules);
    if (daily <= 0) return null;

    var days = medication.stockQuantity / daily;
    final endDate = medication.endDate;
    if (endDate != null) {
      final treatmentDays = endDate.difference(now).inHours <= 0
          ? 0.0
          : endDate.difference(now).inHours / 24.0;
      days = days < treatmentDays ? days : treatmentDays;
    }
    return days < 0 ? 0 : days;
  }

  static MedicationStatus status(
    Medication medication,
    List<MedicationSchedule> schedules,
    DateTime now,
  ) {
    if (!medication.active) return MedicationStatus.inactive;
    if (medication.stockEnabled && medication.stockQuantity <= 0) {
      return MedicationStatus.outOfStock;
    }
    if (medication.stockEnabled &&
        medication.stockQuantity <= medication.lowStockThreshold) {
      return MedicationStatus.lowStock;
    }
    if (medication.endDate != null && !medication.endDate!.isAfter(now)) {
      return MedicationStatus.endingSoon;
    }
    if (schedules.isNotEmpty &&
        schedules.every((schedule) => schedule.type == ScheduleType.prn)) {
      return MedicationStatus.prn;
    }
    if (medication.endDate != null &&
        medication.endDate!.difference(now).inDays <= 7) {
      return MedicationStatus.endingSoon;
    }
    return MedicationStatus.active;
  }

  static double parseDose(String value) {
    final match = RegExp(r'([0-9]+(?:[.,][0-9]+)?)').firstMatch(value);
    return match == null
        ? 0
        : double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0;
  }
}
