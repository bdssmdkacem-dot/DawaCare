import 'package:flutter/foundation.dart';

import 'dose_instance.dart';

/// Lightweight dashboard metrics for one linked family member.
///
/// The summary is intentionally separate from [CaregiverLink] so the family
/// page can keep connection management independent from medication data.
@immutable
class FamilyMemberSummary {
  final int activeMedicationCount;
  final int todayDoseCount;
  final int takenDoseCount;
  final int missedDoseCount;
  final DateTime? lastActivityAt;

  const FamilyMemberSummary({
    required this.activeMedicationCount,
    required this.todayDoseCount,
    required this.takenDoseCount,
    required this.missedDoseCount,
    required this.lastActivityAt,
  });

  const FamilyMemberSummary.empty()
      : activeMedicationCount = 0,
        todayDoseCount = 0,
        takenDoseCount = 0,
        missedDoseCount = 0,
        lastActivityAt = null;

  double get adherence {
    final resolved = takenDoseCount + missedDoseCount;
    if (resolved == 0) return 0;
    return takenDoseCount / resolved;
  }

  static FamilyMemberSummary fromDoses({
    required int activeMedicationCount,
    required List<DoseInstance> todayDoses,
  }) {
    DateTime? last;
    for (final dose in todayDoses) {
      if (last == null || dose.updatedAt.isAfter(last)) last = dose.updatedAt;
    }
    return FamilyMemberSummary(
      activeMedicationCount: activeMedicationCount,
      todayDoseCount: todayDoses.length,
      takenDoseCount: todayDoses.where((d) => d.status == DoseStatus.taken).length,
      missedDoseCount: todayDoses.where((d) => d.status == DoseStatus.missed).length,
      lastActivityAt: last,
    );
  }
}
