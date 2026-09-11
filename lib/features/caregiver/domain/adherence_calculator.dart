import '../../../models/dose_instance.dart';
import '../../doses/domain/adherence_engine.dart';

class AdherenceStats {
  final int taken;
  final int missed;
  final int skipped;
  final int open;
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

/// Compatibility adapter for caregiver reporting.
/// Adherence semantics are owned by [AdherenceEngine].
class AdherenceCalculator {
  AdherenceCalculator._();

  static AdherenceStats compute(List<DoseInstance> doses) {
    final summary = AdherenceEngine.compute(doses, day: DateTime.now());
    return AdherenceStats(
      taken: summary.taken,
      missed: summary.missed,
      skipped: summary.excluded,
      open: summary.pending,
      total: summary.resolved,
    );
  }
}
