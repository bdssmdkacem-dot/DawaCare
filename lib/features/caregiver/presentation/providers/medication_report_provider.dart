import 'package:flutter/foundation.dart';

import '../../data/medication_report_repository.dart';
import '../../domain/medication_report.dart';

enum ReportPeriod { today, week, month }

class MedicationReportProvider extends ChangeNotifier {
  MedicationReportProvider({MedicationReportRepository? repository})
      : _repository = repository ?? MedicationReportRepository();

  @visibleForTesting
  MedicationReportProvider.testLoading() : _repository = null {
    isLoading = true;
  }

  final MedicationReportRepository? _repository;

  AdherenceReport? report;
  ReportPeriod period = ReportPeriod.week;
  DateTime anchor = DateTime.now();
  bool isLoading = false;
  String? error;

  Future<void> load(
    String patientId, {
    ReportPeriod? selectedPeriod,
    DateTime? selectedAnchor,
  }) async {
    final repository = _repository;
    if (repository == null) return;
    period = selectedPeriod ?? period;
    anchor = selectedAnchor ?? anchor;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      report = switch (period) {
        ReportPeriod.today => await repository.today(patientId),
        ReportPeriod.week => await repository.week(patientId, anchor: anchor),
        ReportPeriod.month => await repository.month(patientId, anchor: anchor),
      };
    } catch (_) {
      error = 'تعذّر تحميل تقرير الالتزام.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload(String patientId) => load(patientId);
}
