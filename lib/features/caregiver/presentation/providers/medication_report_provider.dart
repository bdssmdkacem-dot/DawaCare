import 'package:flutter/foundation.dart';

import '../../data/medication_report_repository.dart';
import '../../domain/medication_report.dart';

enum ReportPeriod { today, week, month }

class MedicationReportProvider extends ChangeNotifier {
  final MedicationReportRepository _repository = MedicationReportRepository();

  AdherenceReport? report;
  ReportPeriod period = ReportPeriod.week;
  DateTime anchor = DateTime.now();
  bool isLoading = false;
  String? error;

  Future<void> load(String patientId, {ReportPeriod? selectedPeriod, DateTime? selectedAnchor}) async {
    period = selectedPeriod ?? period;
    anchor = selectedAnchor ?? anchor;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      report = switch (period) {
        ReportPeriod.today => await _repository.today(patientId),
        ReportPeriod.week => await _repository.week(patientId, anchor: anchor),
        ReportPeriod.month => await _repository.month(patientId, anchor: anchor),
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
