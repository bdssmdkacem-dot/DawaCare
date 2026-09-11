import '../../../models/dose_instance.dart';

/// Authoritative client-side contract for dose status transitions.
///
/// The same dose occurrence may be acted on by the patient, a caregiver,
/// notification actions, offline replay, and the server escalation job. This
/// matrix prevents one actor from regressing a newer lifecycle state.
class DoseLifecycle {
  DoseLifecycle._();

  static bool canTransition(DoseStatus from, DoseStatus to) {
    if (from == to) return true;

    switch (from) {
      case DoseStatus.pending:
        return const {
          DoseStatus.reminderSent,
          DoseStatus.snoozed,
          DoseStatus.taken,
          DoseStatus.skipped,
          DoseStatus.cancelled,
          DoseStatus.missed,
        }.contains(to);
      case DoseStatus.reminderSent:
        return const {
          DoseStatus.snoozed,
          DoseStatus.taken,
          DoseStatus.skipped,
          DoseStatus.cancelled,
          DoseStatus.missed,
        }.contains(to);
      case DoseStatus.snoozed:
        return const {
          DoseStatus.reminderSent,
          DoseStatus.taken,
          DoseStatus.skipped,
          DoseStatus.cancelled,
          DoseStatus.missed,
        }.contains(to);
      case DoseStatus.missed:
        // Late confirmation is explicitly supported: MISSED -> TAKEN.
        return to == DoseStatus.taken;
      case DoseStatus.taken:
      case DoseStatus.skipped:
      case DoseStatus.cancelled:
        return false;
    }
  }

  static Set<DoseStatus> allowedPredecessors(DoseStatus target) {
    switch (target) {
      case DoseStatus.pending:
        return const {DoseStatus.pending};
      case DoseStatus.reminderSent:
        return const {DoseStatus.pending, DoseStatus.snoozed};
      case DoseStatus.snoozed:
        return const {DoseStatus.pending, DoseStatus.reminderSent};
      case DoseStatus.taken:
        return const {
          DoseStatus.pending,
          DoseStatus.reminderSent,
          DoseStatus.snoozed,
          DoseStatus.missed,
        };
      case DoseStatus.skipped:
        return const {DoseStatus.pending, DoseStatus.reminderSent, DoseStatus.snoozed};
      case DoseStatus.cancelled:
        return const {DoseStatus.pending, DoseStatus.reminderSent, DoseStatus.snoozed};
      case DoseStatus.missed:
        return const {DoseStatus.pending, DoseStatus.reminderSent, DoseStatus.snoozed};
    }
  }
}
