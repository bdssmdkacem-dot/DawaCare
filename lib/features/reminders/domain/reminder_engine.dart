import '../../../core/notifications/notification_service.dart';
import '../../../models/dose_instance.dart';
import '../../../models/reminder_policy.dart';

/// Bridges a list of doses to on-device notifications. Call
/// [syncUpcoming] whenever the Today screen loads or a dose's status
/// changes, so local alarms always match what's in the database.
class ReminderEngine {
  ReminderEngine._();

  /// Only doses within this horizon get local notifications scheduled —
  /// Android limits how many exact alarms an app may hold at once, and
  /// there is no point alarming for something 2 weeks out.
  static const Duration _schedulingHorizon = Duration(hours: 48);

  static Future<void> syncUpcoming(List<DoseInstance> doses, ReminderPolicy policy) async {
    final now = DateTime.now();
    final horizon = now.add(_schedulingHorizon);

    for (final dose in doses) {
      // Snoozed doses use a dedicated notification at index 99. Their
      // scheduledAt is intentionally unchanged, so normal synchronization
      // must not cancel the active snooze alarm or recreate the old reminder.
      if (dose.status == DoseStatus.snoozed) {
        continue;
      }

      final withinHorizon = dose.scheduledAt.isAfter(now.subtract(const Duration(minutes: 5))) &&
          dose.scheduledAt.isBefore(horizon);
      final unresolved = !isResolvedStatus(dose.status);

      if (withinHorizon && unresolved) {
        await NotificationService.instance.scheduleDoseReminders(dose: dose, policy: policy);
      } else {
        await NotificationService.instance.cancelDoseReminders(dose.id);
      }
    }
  }

  static Future<void> cancelFor(String doseId) => NotificationService.instance.cancelDoseReminders(doseId);
}
