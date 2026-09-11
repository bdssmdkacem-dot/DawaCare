import '../../../models/dose_instance.dart';

/// Immutable adherence summary for a completed observation window.
class AdherenceSummary {
  final int taken;
  final int missed;
  final int pending;
  final int excluded;

  const AdherenceSummary({
    required this.taken,
    required this.missed,
    required this.pending,
    required this.excluded,
  });

  int get resolved => taken + missed;

  /// Percentage of resolved, actionable doses that were taken.
  /// Pending, skipped and cancelled doses never reduce adherence.
  double get percentage => resolved == 0 ? 0 : (taken / resolved) * 100;
}

class AdherenceEngine {
  const AdherenceEngine._();

  /// Computes adherence from dose instances in a local-calendar window.
  ///
  /// Only TAKEN and MISSED are actionable outcomes for the denominator.
  /// PENDING/REMINDER_SENT/SNOOZED remain open, while SKIPPED/CANCELLED are
  /// explicitly excluded from adherence rather than being treated as failures.
  static AdherenceSummary compute(
    Iterable<DoseInstance> doses, {
    required DateTime day,
  }) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    var taken = 0;
    var missed = 0;
    var pending = 0;
    var excluded = 0;

    for (final dose in doses) {
      final scheduled = dose.scheduledAt.toLocal();
      if (scheduled.isBefore(start) || !scheduled.isBefore(end)) continue;

      switch (dose.status) {
        case DoseStatus.taken:
          taken++;
        case DoseStatus.missed:
          missed++;
        case DoseStatus.pending:
        case DoseStatus.reminderSent:
        case DoseStatus.snoozed:
          pending++;
        case DoseStatus.skipped:
        case DoseStatus.cancelled:
          excluded++;
      }
    }

    return AdherenceSummary(
      taken: taken,
      missed: missed,
      pending: pending,
      excluded: excluded,
    );
  }
}
