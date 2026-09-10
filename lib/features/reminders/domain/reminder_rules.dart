import '../../../models/dose_instance.dart';

/// Pure scheduling rules shared by the reminder coordinator and tests.
/// Keeping these decisions independent from the notification plugin makes
/// reminder lifecycle behavior deterministic and regression-testable.
class ReminderRules {
  ReminderRules._();

  static const Duration schedulingHorizon = Duration(hours: 48);
  static const Duration lateGrace = Duration(minutes: 5);

  static bool shouldSchedule({
    required DoseInstance dose,
    required DateTime now,
  }) {
    if (dose.status == DoseStatus.snoozed) return false;
    if (isResolvedStatus(dose.status)) return false;

    final lowerBound = now.subtract(lateGrace);
    final upperBound = now.add(schedulingHorizon);
    return !dose.scheduledAt.isBefore(lowerBound) &&
        dose.scheduledAt.isBefore(upperBound);
  }

  static bool shouldCancel({
    required DoseInstance dose,
    required DateTime now,
  }) {
    if (dose.status == DoseStatus.snoozed) return false;
    return !shouldSchedule(dose: dose, now: now);
  }
}
