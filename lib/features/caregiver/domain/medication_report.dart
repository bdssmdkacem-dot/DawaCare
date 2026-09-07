import '../../../models/dose_instance.dart';

class MedicationReport {
  final String medicationId;
  final String medicationName;
  final int scheduled;
  final int taken;
  final int missed;
  final int skipped;
  final int pending;

  const MedicationReport({
    required this.medicationId,
    required this.medicationName,
    required this.scheduled,
    required this.taken,
    required this.missed,
    required this.skipped,
    required this.pending,
  });

  int get resolved => taken + missed + skipped;
  double get adherence => resolved == 0 ? 0 : taken / resolved;

  factory MedicationReport.fromDoses(String medicationId, String name, List<DoseInstance> doses) {
    return MedicationReport(
      medicationId: medicationId,
      medicationName: name,
      scheduled: doses.length,
      taken: doses.where((d) => d.status == DoseStatus.taken).length,
      missed: doses.where((d) => d.status == DoseStatus.missed).length,
      skipped: doses.where((d) => d.status == DoseStatus.skipped).length,
      pending: doses.where((d) => !isResolvedStatus(d.status)).length,
    );
  }
}

class AdherenceReport {
  final DateTime from;
  final DateTime to;
  final List<DoseInstance> doses;
  final List<MedicationReport> medications;

  const AdherenceReport({
    required this.from,
    required this.to,
    required this.doses,
    required this.medications,
  });

  int get scheduled => doses.length;
  int get taken => doses.where((d) => d.status == DoseStatus.taken).length;
  int get missed => doses.where((d) => d.status == DoseStatus.missed).length;
  int get skipped => doses.where((d) => d.status == DoseStatus.skipped).length;
  int get pending => doses.where((d) => !isResolvedStatus(d.status)).length;
  int get resolved => taken + missed + skipped;
  double get adherence => resolved == 0 ? 0 : taken / resolved;

  Map<DateTime, int> get takenByDay {
    final result = <DateTime, int>{};
    for (final dose in doses.where((d) => d.status == DoseStatus.taken)) {
      final day = DateTime(dose.scheduledAt.year, dose.scheduledAt.month, dose.scheduledAt.day);
      result[day] = (result[day] ?? 0) + 1;
    }
    return result;
  }

  factory AdherenceReport.fromDoses(DateTime from, DateTime to, List<DoseInstance> doses) {
    final grouped = <String, List<DoseInstance>>{};
    for (final dose in doses) {
      grouped.putIfAbsent(dose.medicationId, () => []).add(dose);
    }
    final medicationReports = grouped.entries.map((entry) {
      final name = entry.value.first.medicationName;
      return MedicationReport.fromDoses(entry.key, name, entry.value);
    }).toList()..sort((a, b) => a.medicationName.compareTo(b.medicationName));
    return AdherenceReport(from: from, to: to, doses: doses, medications: medicationReports);
  }
}
