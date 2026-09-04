import 'package:flutter/foundation.dart';

import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../../../doses/data/dose_repository.dart';
import '../../../reminders/data/reminder_policy_repository.dart';
import '../../../reminders/domain/reminder_engine.dart';
import '../../data/medication_repository.dart';

class MedicationProvider extends ChangeNotifier {
  final MedicationRepository _repo = MedicationRepository();
  final DoseRepository _doseRepo = DoseRepository();
  final ReminderPolicyRepository _policyRepo = ReminderPolicyRepository();

  String? patientId;
  List<Medication> medications = [];
  final Map<String, List<MedicationSchedule>> schedulesByMedicationId = {};
  bool isLoading = false;
  String? error;

  // Signed URLs are short-lived and the list rebuilds frequently. Keeping the
  // Future stable prevents a new signed-URL request on every widget rebuild.
  final Map<String, Future<String?>> _imageUrlFutures = {};

  Future<void> load(String forPatientId) async {
    patientId = forPatientId;
    isLoading = true;
    error = null;
    _imageUrlFutures.clear();
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
      await _doseRepo.ensureDosesGenerated(created.patientId);

      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from.add(const Duration(days: 2, hours: 23));
      final generatedDoses = await _doseRepo.fetchDosesForRange(
        created.patientId,
        from: from,
        to: to,
      );
      final medicationDoses = generatedDoses
          .where((dose) => dose.medicationId == created.id)
          .toList();

      final policy = await _policyRepo.fetch(created.patientId);
      await ReminderEngine.syncUpcoming(medicationDoses, policy);

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

  Future<bool> updateSchedule(MedicationSchedule schedule, {
    required String time,
    required String doseAmount,
  }) async {
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final oldDoses = await _doseRepo.fetchDosesForRange(
        schedule.medicationId,
        from: from,
        to: from.add(const Duration(days: 2, hours: 23)),
      );
      for (final dose in oldDoses.where((d) => d.scheduleId == schedule.id && !isResolvedStatus(d.status))) {
        await ReminderEngine.cancelFor(dose.id);
      }

      final updated = await _repo.updateSchedule(
        MedicationSchedule(
          id: schedule.id,
          medicationId: schedule.medicationId,
          type: schedule.type,
          time: time,
          daysOfWeek: schedule.daysOfWeek,
          intervalDays: schedule.intervalDays,
          doseAmount: doseAmount,
          startDate: schedule.startDate,
          endDate: schedule.endDate,
          timezone: schedule.timezone,
        ),
      );

      await _repo.deleteFuturePendingDoses(schedule.id, from);
      await _doseRepo.ensureDosesGenerated(schedule.patientIdForUpdate(medications));

      final refreshed = await _doseRepo.fetchDosesForRange(
        schedule.patientIdForUpdate(medications),
        from: from,
        to: from.add(const Duration(days: 2, hours: 23)),
      );
      final policy = await _policyRepo.fetch(schedule.patientIdForUpdate(medications));
      await ReminderEngine.syncUpcoming(
        refreshed.where((d) => d.scheduleId == schedule.id).toList(),
        policy,
      );

      final list = schedulesByMedicationId[schedule.medicationId];
      if (list != null) {
        final index = list.indexWhere((s) => s.id == schedule.id);
        if (index >= 0) list[index] = updated;
      }
      notifyListeners();
      return true;
    } catch (_) {
      error = 'تعذّر تعديل توقيت أو جرعة الدواء.';
      notifyListeners();
      return false;
    }
  }

  Future<String?> signedMedicationImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return Future.value(null);
    return _imageUrlFutures.putIfAbsent(
      imagePath,
      () => _repo.signedMedicationImageUrl(imagePath),
    );
  }

  Future<void> deactivate(Medication medication) async {
    await _repo.deactivateMedication(medication.id);
    medications.removeWhere((m) => m.id == medication.id);
    notifyListeners();
  }
}

extension on MedicationSchedule {
  String patientIdForUpdate(List<Medication> medications) {
    return medications.firstWhere((m) => m.id == medicationId).patientId;
  }
}
