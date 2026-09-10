import '../../../models/dose_instance.dart';

/// Pure presentation helpers for the patient's Next Dose and daily timeline.
///
/// Keeping these rules outside widgets makes the ordering/status behavior easy
/// to test and prevents UI changes from drifting away from DoseProvider.
class DoseTimeline {
  DoseTimeline._();

  static const Set<DoseStatus> actionableStatuses = {
    DoseStatus.pending,
    DoseStatus.reminderSent,
    DoseStatus.snoozed,
  };

  static DoseInstance? nextDose(
    Iterable<DoseInstance> doses, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final candidates = doses
        .where((dose) =>
            actionableStatuses.contains(dose.status) &&
            !dose.scheduledAt.isBefore(reference))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    if (candidates.isNotEmpty) return candidates.first;

    // A snoozed/reminder dose can legitimately be just before `now` while
    // still actionable. Keep it visible rather than dropping it silently.
    final overdue = doses
        .where((dose) => actionableStatuses.contains(dose.status))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return overdue.isEmpty ? null : overdue.first;
  }

  static int remainingCount(Iterable<DoseInstance> doses) =>
      doses.where((dose) => actionableStatuses.contains(dose.status)).length;

  static int completedCount(Iterable<DoseInstance> doses) =>
      doses.where((dose) => dose.status == DoseStatus.taken).length;

  static List<DoseInstance> ordered(Iterable<DoseInstance> doses) =>
      doses.toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
}
