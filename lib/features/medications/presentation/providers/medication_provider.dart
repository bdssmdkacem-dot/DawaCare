import 'package:flutter/foundation.dart';

import '../../../../models/dose_instance.dart';
import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../../data/medication_repository.dart';
import '../../data/stock_alert_service.dart';
import '../../../doses/data/dose_repository.dart';
import '../../../reminders/data/reminder_policy_repository.dart';
import '../../../reminders/domain/reminder_engine.dart';

class MedicationProvider extends ChangeNotifier {
  final MedicationRepository _repo = MedicationRepository();
  final DoseRepository _doseRepo = DoseRepository();
  final ReminderPolicyRepository _policyRepo = ReminderPolicyRepository();
  bool _disposed = false;

  String? patientId;
  List<Medication> medications = [];
  final Map<String, List<MedicationSchedule>> schedulesByMedicationId = {};
  bool isLoading = false;
  String? error;
  final Map<String, Future<String?>> _imageUrlFutures = {};

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load(String forPatientId) async {
    patientId = forPatientId;
    isLoading = true;
    error = null;
    _imageUrlFutures.clear();
    _notify();
    try {
      medications = await _repo.fetchMedications(forPatientId);
      schedulesByMedicationId.clear();
      for (final med in medications) {
        schedulesByMedicationId[med.id] = await _repo.fetchSchedules(med.id);
      }
      for (final med in medications) {
        try {
          await StockAlertService.instance.checkMedication(med);
        } catch (_) {
          // Stock alerts are non-critical and must never block medication loading.
        }
      }
    } catch (_) {
      error = 'تعذّر تحميل الأدوية.';
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<List<MedicationSchedule>> fetchSchedules(String medicationId) => _repo.fetchSchedules(medicationId);

  Future<List<Map<String, dynamic>>> fetchStockTransactions(String medicationId) => _repo.fetchStockTransactions(medicationId);

  Future<bool> addMedication({required Medication medication, required MedicationSchedule schedule, Uint8List? imageBytes}) async {
    try {
      final created = await _repo.createMedication(medication, imageBytes: imageBytes);
      final createdSchedule = await _repo.createSchedule(created.id, schedule);
      await _doseRepo.ensureDosesGenerated(created.patientId);
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from.add(const Duration(days: 2, hours: 23));
      final generatedDoses = await _doseRepo.fetchDosesForRange(created.patientId, from: from, to: to);
      final medicationDoses = generatedDoses.where((dose) => dose.medicationId == created.id).toList();
      final policy = await _policyRepo.fetch(created.patientId);
      await ReminderEngine.syncUpcoming(medicationDoses, policy);
      medications.insert(0, created);
      schedulesByMedicationId[created.id] = [createdSchedule];
      _notify();
      return true;
    } catch (_) {
      error = 'تعذّر إضافة الدواء. حاول مرة أخرى.';
      _notify();
      return false;
    }
  }

  Future<bool> addMedicationStock({required Medication medication, required double quantity}) async {
    if (quantity <= 0) {
      error = 'يجب أن تكون الكمية أكبر من صفر.';
      _notify();
      return false;
    }
    try {
      final unit = medication.stockEnabled ? medication.stockUnit : _unitForDosageForm(medication.dosageForm);
      if (!medication.stockEnabled) {
        await _repo.updateStockSettings(
          medicationId: medication.id,
          unit: unit,
          packageQuantity: medication.packageQuantity,
          threshold: medication.lowStockThreshold,
        );
      }
      final newQuantity = await _repo.addStock(
        medicationId: medication.id,
        patientId: medication.patientId,
        quantity: quantity,
        type: medication.stockEnabled ? 'ADD' : 'INITIAL',
        note: medication.stockEnabled ? 'Manual stock refill' : 'Initial stock setup',
      );
      final index = medications.indexWhere((m) => m.id == medication.id);
      if (index >= 0) {
        medications[index] = _copyMedication(medications[index], stockEnabled: true, stockQuantity: newQuantity, stockUnit: unit);
        _notify();
      }
      return true;
    } catch (_) {
      error = 'تعذّرت إضافة مخزون الدواء.';
      _notify();
      return false;
    }
  }

  Future<bool> updateMedicationStockSettings({required Medication medication, required String unit, required double? packageQuantity, required double threshold}) async {
    try {
      final row = await _repo.updateStockSettings(medicationId: medication.id, unit: unit, packageQuantity: packageQuantity, threshold: threshold);
      final updated = Medication.fromMap(row);
      final index = medications.indexWhere((m) => m.id == medication.id);
      if (index >= 0) medications[index] = updated;
      _notify();
      return true;
    } catch (_) {
      error = 'تعذّر تحديث إعدادات المخزون.';
      _notify();
      return false;
    }
  }

  Future<bool> updateMedicationImage(Medication medication, Uint8List bytes) async {
    try {
      final oldImagePath = medication.imageUrl;
      final path = await _repo.updateMedicationImage(medication: medication, bytes: bytes);
      final index = medications.indexWhere((m) => m.id == medication.id);
      if (index >= 0) {
        medications[index] = _copyMedication(medications[index], imageUrl: path);
        if (oldImagePath != null) _imageUrlFutures.remove(oldImagePath);
        _imageUrlFutures.remove(path);
        _notify();
      }
      return true;
    } catch (_) {
      error = 'تعذّر تحديث صورة الدواء.';
      _notify();
      return false;
    }
  }

  Future<bool> removeMedicationImage(Medication medication) async {
    try {
      final oldImagePath = medication.imageUrl;
      await _repo.removeMedicationImage(medication);
      final index = medications.indexWhere((m) => m.id == medication.id);
      if (index >= 0) {
        medications[index] = _copyMedication(medications[index], imageUrl: null, clearImage: true);
        if (oldImagePath != null) _imageUrlFutures.remove(oldImagePath);
        _notify();
      }
      return true;
    } catch (_) {
      error = 'تعذّر حذف صورة الدواء.';
      _notify();
      return false;
    }
  }

  Future<bool> updateSchedule(MedicationSchedule schedule, {required String patientId, required String time, required String doseAmount}) async {
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from.add(const Duration(days: 2, hours: 23));
      final oldDoses = await _doseRepo.fetchDosesForRange(patientId, from: from, to: to);
      for (final dose in oldDoses.where((d) => d.scheduleId == schedule.id && !isResolvedStatus(d.status))) {
        await ReminderEngine.cancelFor(dose.id);
      }
      final updated = await _repo.updateSchedule(MedicationSchedule(id: schedule.id, medicationId: schedule.medicationId, type: schedule.type, time: time, daysOfWeek: schedule.daysOfWeek, intervalDays: schedule.intervalDays, doseAmount: doseAmount, startDate: schedule.startDate, endDate: schedule.endDate, timezone: schedule.timezone));
      await _repo.deleteFuturePendingDoses(schedule.id, from);
      await _doseRepo.ensureDosesGenerated(patientId);
      final refreshed = await _doseRepo.fetchDosesForRange(patientId, from: from, to: to);
      final policy = await _policyRepo.fetch(patientId);
      await ReminderEngine.syncUpcoming(refreshed.where((d) => d.scheduleId == schedule.id).toList(), policy);
      final list = schedulesByMedicationId[schedule.medicationId];
      if (list != null) {
        final index = list.indexWhere((s) => s.id == schedule.id);
        if (index >= 0) list[index] = updated;
      }
      _notify();
      return true;
    } catch (_) {
      error = 'تعذّر تعديل توقيت أو جرعة الدواء.';
      _notify();
      return false;
    }
  }

  Future<String?> signedMedicationImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return Future.value(null);
    return _imageUrlFutures.putIfAbsent(imagePath, () => _repo.signedMedicationImageUrl(imagePath));
  }

  Future<void> deactivate(Medication medication) async {
    await _repo.deactivateMedication(medication.id);
    medications.removeWhere((m) => m.id == medication.id);
    _notify();
  }

  String _unitForDosageForm(String? form) {
    switch ((form ?? '').trim()) {
      case 'كبسولة':
      case 'Capsule':
        return 'capsule';
      case 'قرص':
      case 'Tablet':
        return 'tablet';
      case 'شراب':
      case 'Syrup':
        return 'ml';
      case 'قطرة':
      case 'Drop':
        return 'drop';
      case 'حقنة':
      case 'Injection':
        return 'injection';
      default:
        return 'unit';
    }
  }

  Medication _copyMedication(
    Medication medication, {
    String? imageUrl,
    bool clearImage = false,
    bool? stockEnabled,
    double? stockQuantity,
    String? stockUnit,
  }) {
    return Medication(
      id: medication.id,
      patientId: medication.patientId,
      name: medication.name,
      genericName: medication.genericName,
      strength: medication.strength,
      dosageForm: medication.dosageForm,
      instructions: medication.instructions,
      imageUrl: clearImage ? null : (imageUrl ?? medication.imageUrl),
      startDate: medication.startDate,
      endDate: medication.endDate,
      active: medication.active,
      createdBy: medication.createdBy,
      createdAt: medication.createdAt,
      stockEnabled: stockEnabled ?? medication.stockEnabled,
      stockQuantity: stockQuantity ?? medication.stockQuantity,
      stockUnit: stockUnit ?? medication.stockUnit,
      packageQuantity: medication.packageQuantity,
      lowStockThreshold: medication.lowStockThreshold,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
