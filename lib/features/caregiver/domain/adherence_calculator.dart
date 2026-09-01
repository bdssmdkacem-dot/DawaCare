import '../../../models/dose_instance.dart';

class AdherenceStats {
  final int taken;
  final int missed;
  final int skipped;
  final int open; // still pending/snoozed but already due
  final int total;

  const AdherenceStats({
    required this.taken,
    required this.missed,
    required this.skipped,
    required this.open,
    required this.total,
  });

  double get takenRate => total == 0 ? 0 : taken / total;
  int get takenPercent => (takenRate * 100).round();
}

/// Computes adherence only over doses whose scheduled time has already
/// passed — future doses aren't "missed" yet, so counting them would
/// artificially deflate the percentage (see architecture doc §18).
class AdherenceCalculator {
  AdherenceCalculator._();

  static AdherenceStats compute(List<DoseInstance> doses) {
    final now = DateTime.now();
    final due = doses.where((d) => d.scheduledAt.isBefore(now)).toList();

    int taken = 0, missed = 0, skipped = 0, open = 0;
    for (final d in due) {
      switch (d.status) {
        case DoseStatus.taken:
          taken++;
          break;
        case DoseStatus.missed:
          missed++;
          break;
        case DoseStatus.skipped:
        case DoseStatus.cancelled:
          skipped++;
          break;
        default:
          open++;
      }
    }
    return AdherenceStats(taken: taken, missed: missed, skipped: skipped, open: open, total: due.length);
  }
}
