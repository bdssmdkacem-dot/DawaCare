import '../../../core/notifications/notification_service.dart';
import '../../../models/dose_instance.dart';
import '../../../models/reminder_policy.dart';

/// Bridges dose lifecycle state to on-device notifications.
class ReminderEngine {
  ReminderEngine._();

  static const Duration _schedulingHorizon = Duration(hours: 48);
  static const Duration _snoozeDuration = Duration(minutes: 10);

  static Future<void> syncUpcoming(List<DoseInstance> doses, ReminderPolicy policy) async {
    final now = DateTime.now();
    final horizon = now.add(_schedulingHorizon);

    for (final dose in doses) {
      // A snoozed dose has a new reminder anchored to updatedAt. Its original
      // scheduledAt may already be in the past, so it must not be treated as
      // an expired dose by the normal upcoming window.
      if (dose.status == DoseStatus.snoozed) {
        final snoozeAt = dose.updatedAt.add(_snoozeDuration);
        if (snoozeAt.isAfter(now.subtract(const Duration(seconds: 30))) &&
            snoozeAt.isBefore(horizon)) {
          await NotificationService.instance.scheduleSnoozeReminder(dose: dose, at: snoozeAt);
        } else {
          await NotificationService.instance.cancelDoseReminders(dose.id);
        }
        continue;
      }

      final withinHorizon =
          dose.scheduledAt.isAfter(now.subtract(const Duration(minutes: 5))) &&
          dose.scheduledAt.isBefore(horizon);
      final unresolved = !isResolvedStatus(dose.status);

      if (withinHorizon && unresolved) {
        await NotificationService.instance.scheduleDoseReminders(
          dose: dose,
          policy: policy,
        );
      } else {
        await NotificationService.instance.cancelDoseReminders(dose.id);
      }
    }
  }

  static Future<void> snoozeFor(DoseInstance dose) =>
      NotificationService.instance.scheduleSnoozeReminder(
        dose: dose,
        at: dose.updatedAt.add(_snoozeDuration),
      );

  static Future<void> cancelFor(String doseId) =>
      NotificationService.instance.cancelDoseReminders(doseId);
}
