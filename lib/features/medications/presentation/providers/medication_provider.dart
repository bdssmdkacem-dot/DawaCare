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
    } catch (_) {
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
    } catch (_) {
      error = 'تعذّر إضافة الدواء. حاول مرة أخرى.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateMedicationImage(Medication medication, Uint8List bytes) async {
    try {
      final path = await _repo.updateMedicationImage(medication: medication, bytes: bytes);
      final index = medications.indexWhere((m) => m.id == medication.id);
      if (index >= 0) {
        medications[index] = Medication(
          id: medication.id,
          patientId: medication.patientId,
          name: medication.name,
          genericName: medication.genericName,
          strength: medication.strength,
          dosageForm: medication.dosageForm,
          instructions: medication.instructions,
          imageUrl: path,
          startDate: medication.startDate,
          endDate: medication.endDate,
          active: medication.active,
          createdBy: medication.createdBy,
          createdAt: medication.createdAt,
        );
        notifyListeners();
      }
      return true;
    } catch (_) {
      error = 'تعذّر تحديث صورة الدواء.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMedicationImage(Medication medication) async {
    try {
      await _repo.removeMedicationImage(medication);
      final index = medications.indexWhere((m) => m.id == medication.id);
      if (index >= 0) {
        medications[index] = Medication(
          id: medication.id,
          patientId: medication.patientId,
          name: medication.name,
          genericName: medication.genericName,
          strength: medication.strength,
          dosageForm: medication.dosageForm,
          instructions: medication.instructions,
          imageUrl: null,
          startDate: medication.startDate,
          endDate: medication.endDate,
          active: medication.active,
          createdBy: medication.createdBy,
          createdAt: medication.createdAt,
        );
        notifyListeners();
      }
      return true;
    } catch (_) {
      error = 'تعذّر حذف صورة الدواء.';
      notifyListeners();
      return false;
    }
  }

  Future<String?> signedMedicationImageUrl(String? imagePath) => _repo.signedMedicationImageUrl(imagePath);

  Future<void> deactivate(Medication medication) async {
    await _repo.deactivateMedication(medication.id);
    medications.removeWhere((m) => m.id == medication.id);
    notifyListeners();
  }
}
