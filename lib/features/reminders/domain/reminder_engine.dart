import '../../../core/notifications/notification_service.dart';
import '../../../features/doses/data/dose_repository.dart';
import '../../../models/dose_instance.dart';
import '../../../models/reminder_policy.dart';
import 'reminder_rules.dart';

/// Bridges a list of doses to on-device notifications.
class ReminderEngine {
  ReminderEngine._();

  static Future<void> syncUpcoming(
    List<DoseInstance> doses,
    ReminderPolicy policy,
  ) async {
    final now = DateTime.now();

    for (final dose in doses) {
      // Snoozed doses own their dedicated snooze notification. Normal sync
      // must never cancel or recreate it while the snooze lifecycle is active.
      if (dose.status == DoseStatus.snoozed) continue;

      if (ReminderRules.shouldSchedule(dose: dose, now: now)) {
        try {
          await NotificationService.instance.scheduleDoseReminders(
            dose: dose,
            policy: policy,
          );

          // Only advance PENDING after the complete local scheduling operation
          // succeeds. Repeated syncs leave REMINDER_SENT stable and the
          // notification IDs remain deterministic/idempotent.
          if (dose.status == DoseStatus.pending) {
            try {
              await DoseRepository().updateStatus(
                dose,
                DoseStatus.reminderSent,
                source: 'SYSTEM',
              );
            } on StateError {
              // Another actor won the lifecycle race (e.g. TAKEN/MISSED).
              // Remove the notifications just scheduled for the stale copy.
              await NotificationService.instance.cancelDoseReminders(dose.id);
            }
          }
        } catch (_) {
          // Scheduling failure must not advance the dose lifecycle.
        }
      } else {
        await NotificationService.instance.cancelDoseReminders(dose.id);
      }
    }
  }

  static Future<void> cancelFor(String doseId) =>
      NotificationService.instance.cancelDoseReminders(doseId);
}
