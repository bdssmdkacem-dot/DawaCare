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

  /// Average inventory units consumed per calendar day.
  ///
  /// The configured stock unit is used to select the consumption quantity
  /// when the dose text contains both strength and inventory quantity.
  static double dailyConsumption(
    List<MedicationSchedule> schedules, {
    String? stockUnit,
  }) {
    var total = 0.0;
    for (final schedule in schedules) {
      final dose = parseDose(schedule.doseAmount, stockUnit: stockUnit);
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

  static double? daysRemaining(
    Medication medication,
    List<MedicationSchedule> schedules,
    DateTime now,
  ) {
    if (!medication.stockEnabled) return null;
    if (medication.stockQuantity <= 0) return 0;

    final daily = dailyConsumption(schedules, stockUnit: medication.stockUnit);
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

  /// Parses the inventory quantity consumed from a dose description.
  ///
  /// When [stockUnit] is configured, the parser first looks for a number
  /// immediately followed by that unit. This prevents `500 mg, 2 tablets`
  /// from being interpreted as 500 tablets. Decimal point and decimal comma
  /// are both supported.
  static double parseDose(String value, {String? stockUnit}) {
    final normalized = value.trim();
    if (stockUnit != null && stockUnit.trim().isNotEmpty) {
      final unit = stockUnit.trim();
      final unitPattern = _unitPattern(unit);
      final unitMatch = RegExp(
        r'([0-9]+(?:[.,][0-9]+)?)\s*' + unitPattern,
        caseSensitive: false,
      ).firstMatch(normalized);
      if (unitMatch != null) {
        return _toDouble(unitMatch.group(1));
      }
    }

    final match = RegExp(r'([0-9]+(?:[.,][0-9]+)?)').firstMatch(normalized);
    return _toDouble(match?.group(1));
  }

  /// Handles common singular/plural forms without changing the stored unit.
  static String _unitPattern(String unit) {
    final escaped = RegExp.escape(unit);
    switch (unit.toLowerCase()) {
      case 'tablet':
      case 'tablette':
        return '(?:$escaped|tablets|tablettes)\\b';
      case 'capsule':
      case 'gélule':
      case 'gelule':
        return '(?:$escaped|capsules|gélules|gelules)\\b';
      case 'ml':
        return r'(?:ml|mL)\b';
      case 'unit':
      case 'unité':
      case 'unite':
        return '(?:$escaped|units|unités|unites)\\b';
      default:
        return '$escaped\\b';
    }
  }

  static double _toDouble(String? value) {
    if (value == null) return 0;
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }
}
