import '../../doses/data/dose_repository.dart';
import '../domain/medication_report.dart';

class MedicationReportRepository {
  final DoseRepository _doseRepository = DoseRepository();

  Future<AdherenceReport> fetch(
    String patientId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final start = DateTime(from.year, from.month, from.day);
    final endExclusive = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
    final doses = await _doseRepository.fetchDosesForRange(
      patientId,
      from: start,
      to: endExclusive.subtract(const Duration(microseconds: 1)),
    );
    return AdherenceReport.fromDoses(
      start,
      endExclusive.subtract(const Duration(days: 1)),
      doses,
    );
  }

  Future<AdherenceReport> today(String patientId) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return fetch(patientId, from: day, to: day);
  }

  Future<AdherenceReport> week(String patientId, {DateTime? anchor}) {
    final date = anchor ?? DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final from = day.subtract(Duration(days: day.weekday - 1));
    return fetch(patientId, from: from, to: from.add(const Duration(days: 6)));
  }

  Future<AdherenceReport> month(String patientId, {DateTime? anchor}) {
    final date = anchor ?? DateTime.now();
    final from = DateTime(date.year, date.month, 1);
    final to = DateTime(date.year, date.month + 1, 0);
    return fetch(patientId, from: from, to: to);
  }
}
