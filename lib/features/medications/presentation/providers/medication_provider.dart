import 'dart:typed_data';

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
      schedulesByMedicationId.clear();
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
    Uint8List? imageBytes,
  }) async {
    try {
      final created = await _repo.createMedication(medication, imageBytes: imageBytes);
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

  Future<bool> updateMedicationImage(Medication medication, Uint8List bytes) async {
    try {
      await _repo.updateMedicationImage(medication: medication, bytes: bytes);
      final index = medications.indexWhere((m) => m.id == medication.id);
      if (index >= 0) {
        final updated = Medication.fromMap({
          'id': medication.id,
          'patient_id': medication.patientId,
          'name': medication.name,
          'generic_name': medication.genericName,
          'strength': medication.strength,
          'dosage_form': medication.dosageForm,
          'instructions': medication.instructions,
          'image_url': 'updated',
          'start_date': medication.startDate.toIso8601String(),
          'end_date': medication.endDate?.toIso8601String(),
          'active': medication.active,
          'created_by': medication.createdBy,
          'created_at': medication.createdAt.toIso8601String(),
        });
        medications[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (_) {
      error = 'تعذّر تحديث صورة الدواء.';
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
