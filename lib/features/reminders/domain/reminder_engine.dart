import '../../../core/notifications/notification_service.dart';
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
      // must never cancel or recreate it while scheduledAt remains unchanged.
      if (dose.status == DoseStatus.snoozed) continue;

      if (ReminderRules.shouldSchedule(dose: dose, now: now)) {
        await NotificationService.instance.scheduleDoseReminders(
          dose: dose,
          policy: policy,
        );
      } else {
        await NotificationService.instance.cancelDoseReminders(dose.id);
      }
    }
  }

  static Future<void> cancelFor(String doseId) =>
      NotificationService.instance.cancelDoseReminders(doseId);
}
