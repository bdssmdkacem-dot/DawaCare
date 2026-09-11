import '../../../models/dose_instance.dart';
import 'adherence_engine.dart';

/// A calendar-day adherence snapshot for reporting and dashboards.
class DailyAdherence {
  final DateTime day;
  final AdherenceSummary summary;

  const DailyAdherence({required this.day, required this.summary});

  double get percentage => summary.percentage;
}

/// Aggregated adherence for a local-calendar week.
class WeeklyAdherence {
  final DateTime start;
  final DateTime endExclusive;
  final List<DailyAdherence> days;

  const WeeklyAdherence({
    required this.start,
    required this.endExclusive,
    required this.days,
  });

  int get taken => days.fold(0, (sum, day) => sum + day.summary.taken);
  int get missed => days.fold(0, (sum, day) => sum + day.summary.missed);
  int get pending => days.fold(0, (sum, day) => sum + day.summary.pending);
  int get excluded => days.fold(0, (sum, day) => sum + day.summary.excluded);

  int get resolved => taken + missed;
  double get percentage => resolved == 0 ? 0 : (taken / resolved) * 100;
}

/// Medication-specific adherence. Useful for identifying which treatments
/// need attention without changing the underlying dose records.
class MedicationAdherence {
  final String medicationId;
  final String medicationName;
  final AdherenceSummary summary;

  const MedicationAdherence({
    required this.medicationId,
    required this.medicationName,
    required this.summary,
  });

  double get percentage => summary.percentage;
}

class AdherenceReportEngine {
  const AdherenceReportEngine._();

  /// Builds seven local-calendar days starting at the supplied date.
  /// The input is normalized to midnight so callers can pass any time of day.
  static WeeklyAdherence weekly(
    Iterable<DoseInstance> doses, {
    required DateTime weekStart,
  }) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final all = List<DoseInstance>.from(doses);
    final days = List.generate(
      7,
      (index) {
        final day = start.add(Duration(days: index));
        return DailyAdherence(
          day: day,
          summary: AdherenceEngine.compute(all, day: day),
        );
      },
    );

    return WeeklyAdherence(
      start: start,
      endExclusive: start.add(const Duration(days: 7)),
      days: days,
    );
  }

  /// Groups doses by medication while preserving the same adherence rules as
  /// the daily engine. Doses outside [from, to) are ignored.
  static List<MedicationAdherence> byMedication(
    Iterable<DoseInstance> doses, {
    required DateTime from,
    required DateTime to,
  }) {
    final start = from.toLocal();
    final end = to.toLocal();
    final grouped = <String, List<DoseInstance>>{};
    final names = <String, String>{};

    for (final dose in doses) {
      final scheduled = dose.scheduledAt.toLocal();
      if (scheduled.isBefore(start) || !scheduled.isBefore(end)) continue;
      grouped.putIfAbsent(dose.medicationId, () => <DoseInstance>[]).add(dose);
      names[dose.medicationId] = dose.medicationName;
    }

    final result = grouped.entries
        .map(
          (entry) => MedicationAdherence(
            medicationId: entry.key,
            medicationName: names[entry.key] ?? 'دواء',
            summary: _summary(entry.value),
          ),
        )
        .toList();

    result.sort((a, b) => a.medicationName.compareTo(b.medicationName));
    return result;
  }

  static AdherenceSummary _summary(Iterable<DoseInstance> doses) {
    var taken = 0;
    var missed = 0;
    var pending = 0;
    var excluded = 0;

    for (final dose in doses) {
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
