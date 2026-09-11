import 'package:flutter/foundation.dart';

import '../features/doses/domain/adherence_engine.dart';
import 'dose_instance.dart';

/// Lightweight dashboard metrics for one linked family member.
@immutable
class FamilyMemberSummary {
  final int activeMedicationCount;
  final int todayDoseCount;
  final int takenDoseCount;
  final int missedDoseCount;
  final int pendingDoseCount;
  final int excludedDoseCount;
  final DateTime? nextDoseAt;
  final int lowStockMedicationCount;
  final int outOfStockMedicationCount;
  final DateTime? lastActivityAt;

  const FamilyMemberSummary({
    required this.activeMedicationCount,
    required this.todayDoseCount,
    required this.takenDoseCount,
    required this.missedDoseCount,
    required this.pendingDoseCount,
    required this.excludedDoseCount,
    required this.nextDoseAt,
    required this.lowStockMedicationCount,
    required this.outOfStockMedicationCount,
    required this.lastActivityAt,
  });

  const FamilyMemberSummary.empty()
      : activeMedicationCount = 0,
        todayDoseCount = 0,
        takenDoseCount = 0,
        missedDoseCount = 0,
        pendingDoseCount = 0,
        excludedDoseCount = 0,
        nextDoseAt = null,
        lowStockMedicationCount = 0,
        outOfStockMedicationCount = 0,
        lastActivityAt = null;

  double get adherence {
    final resolved = takenDoseCount + missedDoseCount;
    if (resolved == 0) return 0;
    return takenDoseCount / resolved;
  }

  static FamilyMemberSummary fromDoses({
    required int activeMedicationCount,
    required List<DoseInstance> todayDoses,
    DateTime? nextDoseAt,
    int lowStockMedicationCount = 0,
    int outOfStockMedicationCount = 0,
  }) {
    DateTime? last;
    for (final dose in todayDoses) {
      if (last == null || dose.updatedAt.isAfter(last)) last = dose.updatedAt;
    }

    final adherence = AdherenceEngine.compute(todayDoses, day: DateTime.now());

    return FamilyMemberSummary(
      activeMedicationCount: activeMedicationCount,
      todayDoseCount: todayDoses.length,
      takenDoseCount: adherence.taken,
      missedDoseCount: adherence.missed,
      pendingDoseCount: adherence.pending,
      excludedDoseCount: adherence.excluded,
      nextDoseAt: nextDoseAt,
      lowStockMedicationCount: lowStockMedicationCount,
      outOfStockMedicationCount: outOfStockMedicationCount,
      lastActivityAt: last,
    );
  }
}
