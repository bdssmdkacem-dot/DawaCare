/// Pure rules for identifying and classifying queued dose-status writes.
///
/// A deterministic key prevents the same dose/status intent from being
/// inserted into the local queue more than once while offline. Server-side
/// replay remains idempotent as a second layer of protection.
class SyncQueueRules {
  SyncQueueRules._();

  static String doseStatusOperationId({
    required String doseId,
    required String status,
  }) {
    return 'DOSE_STATUS:$doseId:$status';
  }

  static bool isAlreadyApplied({
    required bool applied,
    required String? currentStatus,
    required String requestedStatus,
  }) {
    return applied || currentStatus == requestedStatus;
  }

  static bool isPermanentConflict({
    required bool applied,
    required String? currentStatus,
    required String requestedStatus,
  }) {
    return !isAlreadyApplied(
      applied: applied,
      currentStatus: currentStatus,
      requestedStatus: requestedStatus,
    );
  }
}