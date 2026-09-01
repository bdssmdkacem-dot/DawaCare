import 'package:flutter/foundation.dart';

import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../../data/medication_repository.dart';

class MedicationProvider extends ChangeNotifier {
  final MedicationRepository _repo = MedicationRepository();

  String? patientId;
  List<Medication> medications = [];
  final Map<String, List<MedicationSchedule>> schedulesByMedicationId = {};
  bool isLoading = false;
  String? error;

  Future<void> load(String forPatientId) async {
    patientId = forPatientId;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      medications = await _repo.fetchMedications(forPatientId);
      for (final med in medications) {
        schedulesByMedicationId[med.id] = await _repo.fetchSchedules(med.id);
      }
    } catch (e) {
      error = 'تعذّر تحميل الأدوية.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addMedication({
    required Medication medication,
    required MedicationSchedule schedule,
  }) async {
    try {
      final created = await _repo.createMedication(medication);
      final createdSchedule = await _repo.createSchedule(created.id, schedule);
      medications.insert(0, created);
      schedulesByMedicationId[created.id] = [createdSchedule];
      notifyListeners();
      return true;
    } catch (e) {
      error = 'تعذّر إضافة الدواء. حاول مرة أخرى.';
      notifyListeners();
      return false;
    }
  }

  Future<void> deactivate(Medication medication) async {
    await _repo.deactivateMedication(medication.id);
    medications.removeWhere((m) => m.id == medication.id);
    notifyListeners();
  }
}
