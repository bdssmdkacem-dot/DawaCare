import '../../../models/medication.dart';
import '../../../models/medication_schedule.dart';
import '../../doses/domain/dose_engine.dart';
import 'stock_intelligence.dart';

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
  /// Stock consumption is calculated by the canonical [StockIntelligence]
  /// implementation so parsing and schedule semantics stay consistent across
  /// medication cards, detail screens, and stock calculations.
  static double dailyConsumption(
    List<MedicationSchedule> schedules, {
    String? stockUnit,
  }) {
    final medication = Medication(
      id: 'calculator',
      patientId: 'calculator',
      name: 'calculator',
      startDate: DateTime(2000),
      active: true,
      createdBy: 'calculator',
      createdAt: DateTime(2000),
      stockEnabled: true,
      stockQuantity: 0,
      stockUnit: stockUnit ?? 'unit',
      lowStockThreshold: 0,
    );

    return StockIntelligence.dailyConsumption(
      medication: medication,
      schedules: schedules,
    );
  }

  static double? daysRemaining(
    Medication medication,
    List<MedicationSchedule> schedules,
    DateTime now,
  ) {
    final coverage = StockIntelligence.daysRemaining(
      medication: medication,
      schedules: schedules,
    );
    if (coverage == null) return null;

    final endDate = medication.endDate;
    if (endDate == null) return coverage;

    final treatmentDays = endDate.difference(now).inHours <= 0
        ? 0.0
        : endDate.difference(now).inHours / 24.0;
    return coverage < treatmentDays ? coverage : treatmentDays;
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

  /// Parses an inventory dose using the canonical stock parser.
  ///
  /// The legacy calculator API returns a non-null quantity, so an invalid or
  /// missing dose is represented as zero while [StockIntelligence] remains
  /// nullable for callers that need to distinguish an unparsable value.
  static double parseDose(String value, {String? stockUnit}) =>
      StockIntelligence.parseDoseQuantity(value, stockUnit ?? 'unit') ?? 0;
}
