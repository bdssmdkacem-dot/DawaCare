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
      if (dose.status == DoseStatus.snoozed) {
        final snoozeAt = dose.updatedAt.add(_snoozeDuration);
        if (snoozeAt.isAfter(now.subtract(const Duration(seconds: 30))) &&
            snoozeAt.isBefore(horizon)) {
          await snoozeFor(dose);
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

  /// Reuses the normal notification path with a temporary scheduledAt. The
  /// database keeps the original prescription occurrence; only the local
  /// reminder is moved by ten minutes.
  static Future<void> snoozeFor(DoseInstance dose) async {
    final snoozedDose = DoseInstance(
      id: dose.id,
      medicationId: dose.medicationId,
      scheduleId: dose.scheduleId,
      patientId: dose.patientId,
      medicationName: dose.medicationName,
      doseAmount: dose.doseAmount,
      scheduledAt: dose.updatedAt.add(_snoozeDuration),
      status: DoseStatus.snoozed,
      updatedAt: dose.updatedAt,
    );
    await NotificationService.instance.scheduleDoseReminders(
      dose: snoozedDose,
      policy: const ReminderPolicy(patientId: ''),
    );
  }

  static Future<void> cancelFor(String doseId) =>
      NotificationService.instance.cancelDoseReminders(doseId);
}
