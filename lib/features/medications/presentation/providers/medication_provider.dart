import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  int _loadGeneration = 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load(String forPatientId) async {
    final generation = ++_loadGeneration;
    patientId = forPatientId;
    isLoading = true;
    error = null;
    _imageUrlFutures.clear();
    _notify();

    try {
      final loadedMedications = await _repo.fetchMedications(forPatientId, activeOnly: false);
      if (_disposed || generation != _loadGeneration) return;

      final scheduleEntries = await Future.wait(
        loadedMedications.map(
          (medication) async => MapEntry(
            medication.id,
            await _repo.fetchSchedules(medication.id),
          ),
        ),
      );
      if (_disposed || generation != _loadGeneration) return;

      final scheduleMap = <String, List<MedicationSchedule>>{
        for (final entry in scheduleEntries) entry.key: entry.value,
      };

      medications = loadedMedications;
      schedulesByMedicationId
        ..clear()
        ..addAll(scheduleMap);
      _notify();

      await Future.wait(
        loadedMedications.map((medication) async {
          try {
            await StockAlertService.instance.checkMedication(medication);
          } catch (_) {
            // Stock alerts are non-critical and must never block medication loading.
          }
        }),
      );
    } catch (_) {
      if (!_disposed && generation == _loadGeneration) {
        error = 'تعذّر تحميل الأدوية.';
      }
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        isLoading = false;
        _notify();
      }
    }
  }

  Future<List<MedicationSchedule>> fetchSchedules(String medicationId) => _repo.fetchSchedules(medicationId);

  Future<List<Map<String, dynamic>>> fetchStockTransactions(String medicationId) => _repo.fetchStockTransactions(medicationId);

  Future<bool> addMedication({required Medication medication, required MedicationSchedule schedule, Uint8List? imageBytes}) async {
    Medication? created;

    try {
      created = await _repo.createMedication(medication, imageBytes: imageBytes);
    } catch (e, st) {
      debugPrint('DawaCare createMedication failed: $e');
      debugPrintStack(stackTrace: st);
      error = _medicationSaveError(e, 'medication');
      _notify();
      return false;
    }

    final createdMedication = created;
    if (createdMedication == null) return false;

    try {
      final createdSchedule = await _repo.createSchedule(createdMedication.id, schedule);
      try {
        await _syncMedicationFuture(patientId: createdMedication.patientId, medicationId: createdMedication.id);
      } catch (e, st) {
        debugPrint('DawaCare medication follow-up sync failed: $e');
        debugPrintStack(stackTrace: st);
      }

      medications.insert(0, createdMedication);
      schedulesByMedicationId[createdMedication.id] = [createdSchedule];
      _notify();
      return true;
    } catch (e, st) {
      debugPrint('DawaCare createSchedule failed: $e');
      debugPrintStack(stackTrace: st);

      try {
        await _repo.deleteMedication(createdMedication.id);
      } catch (deleteError, deleteStack) {
        debugPrint('DawaCare rollback medication failed: $deleteError');
        debugPrintStack(stackTrace: deleteStack);
      }

      error = _medicationSaveError(e, 'schedule');
      _notify();
      return false;
    }
  }

  String _medicationSaveError(Object error, String stage) {
    if (error is PostgrestException) {
      debugPrint(
        'DawaCare medication $stage PostgREST: '
        'code=${error.code}, message=${error.message}, '
        'details=${error.details}, hint=${error.hint}',
      );
      return 'تعذّرت إضافة الدواء ($stage): ${error.message} [${error.code ?? 'no-code'}]';
    }
    return 'تعذّرت إضافة الدواء ($stage): $error';
  }

  Future<bool> updateMedication(Medication medication) async {
    try {
      final now = DateTime.now();
      final from = now;
      final to = DateTime(now.year, now.month, now.day).add(const Duration(days: 2, hours: 23));
      final futureDoses = await _doseRepo.fetchDosesForRange(medication.patientId, from: from, to: to);

      for (final dose in futureDoses.where((d) => d.medicationId == medication.id && !isResolvedStatus(d.status))) {
        await ReminderEngine.cancelFor(dose.id);
      }

      final updated = await _repo.updateMedication(medication);
      await _doseRepo.clearFutureUnresolvedDosesByMedication(medication.id, from);
      await _syncMedicationFuture(patientId: medication.patientId, medicationId: medication.id);

      final index = medications.indexWhere((m) => m.id == medication.id);
      if (index >= 0) {
        final current = medications[index];
        medications[index] = _copyMedication(updated, stockEnabled: current.stockEnabled, stockQuantity: current.stockQuantity, stockUnit: current.stockUnit);
      }
      _notify();
      return true;
    } catch (_) {
      error = 'تعذّر تعديل الدواء.';
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
        await _repo.updateStockSettings(medicationId: medication.id, unit: unit, packageQuantity: medication.packageQuantity, threshold: medication.lowStockThreshold);
      }
      final newQuantity = await _repo.addStock(medicationId: medication.id, patientId: medication.patientId, quantity: quantity, type: medication.stockEnabled ? 'ADD' : 'INITIAL', note: medication.stockEnabled ? 'Manual stock refill' : 'Initial stock setup');
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
      final from = now;
      final to = DateTime(now.year, now.month, now.day).add(const Duration(days: 2, hours: 23));
      final oldDoses = await _doseRepo.fetchDosesForRange(patientId, from: from, to: to);
      for (final dose in oldDoses.where((d) => d.scheduleId == schedule.id && !isResolvedStatus(d.status))) {
        await ReminderEngine.cancelFor(dose.id);
      }

      final updated = await _repo.updateSchedule(MedicationSchedule(id: schedule.id, medicationId: schedule.medicationId, type: schedule.type, time: time, daysOfWeek: schedule.daysOfWeek, intervalDays: schedule.intervalDays, doseAmount: doseAmount, startDate: schedule.startDate, endDate: schedule.endDate, timezone: schedule.timezone));
      await _repo.deleteFutureUnresolvedDoses(schedule.id, from);
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

  Future<void> _syncMedicationFuture({required String patientId, required String medicationId}) async {
    await _doseRepo.ensureDosesGenerated(patientId);
    final now = DateTime.now();
    final from = now;
    final to = DateTime(now.year, now.month, now.day).add(const Duration(days: 2, hours: 23));
    final doses = await _doseRepo.fetchDosesForRange(patientId, from: from, to: to);
    final policy = await _policyRepo.fetch(patientId);
    await ReminderEngine.syncUpcoming(doses.where((dose) => dose.medicationId == medicationId && !isResolvedStatus(dose.status)).toList(), policy);
  }

  Future<String?> signedMedicationImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return Future.value(null);
    return _imageUrlFutures.putIfAbsent(imagePath, () => _repo.signedMedicationImageUrl(imagePath));
  }

  /// Stops the medication but keeps its database row, stock, history and image.
  Future<void> deactivate(Medication medication) async {
    debugPrint('DawaCare medication STOP START id=${medication.id} patient=${medication.patientId}');

    // The database state is authoritative. Do this first so a reminder or dose
    // cleanup failure can never prevent the medication from being stopped.
    await _repo.deactivateMedication(medication.id);
    debugPrint('DawaCare medication STOP DB SUCCESS id=${medication.id}');

    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 14));
    try {
      final futureDoses = await _doseRepo.fetchDosesForRange(medication.patientId, from: from, to: to);
      for (final dose in futureDoses.where((d) => d.medicationId == medication.id && !isResolvedStatus(d.status))) {
        try {
          await ReminderEngine.cancelFor(dose.id);
        } catch (e, st) {
          debugPrint('DawaCare medication STOP reminder cleanup failed dose=${dose.id}: $e');
          debugPrintStack(stackTrace: st);
        }
      }
      try {
        await _doseRepo.clearFutureUnresolvedDosesByMedication(medication.id, from);
      } catch (e, st) {
        debugPrint('DawaCare medication STOP dose cleanup failed id=${medication.id}: $e');
        debugPrintStack(stackTrace: st);
      }
    } catch (e, st) {
      debugPrint('DawaCare medication STOP cleanup skipped id=${medication.id}: $e');
      debugPrintStack(stackTrace: st);
    }

    final index = medications.indexWhere((m) => m.id == medication.id);
    if (index >= 0) {
      medications[index] = _copyMedication(medications[index], active: false);
    }
    schedulesByMedicationId.remove(medication.id);
    _notify();
    debugPrint('DawaCare medication STOP SUCCESS id=${medication.id}');
  }

  Future<void> reactivate(Medication medication) async {
    await _repo.reactivateMedication(medication.id);
    try {
      await _syncMedicationFuture(
        patientId: medication.patientId,
        medicationId: medication.id,
      );
    } catch (e, st) {
      debugPrint('DawaCare medication REACTIVATE reminder sync failed: $e');
      debugPrintStack(stackTrace: st);
    }
    final index = medications.indexWhere((m) => m.id == medication.id);
    if (index >= 0) {
      medications[index] =
          _copyMedication(medications[index], active: true);
    }
    _notify();
  }


  /// Permanently removes the medication and all database dependents.
  Future<void> deleteMedication(Medication medication) async {
    debugPrint('DawaCare medication DELETE START id=${medication.id} patient=${medication.patientId}');
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 14));
    try {
      final futureDoses = await _doseRepo.fetchDosesForRange(medication.patientId, from: from, to: to);
      for (final dose in futureDoses.where((d) => d.medicationId == medication.id && !isResolvedStatus(d.status))) {
        try {
          await ReminderEngine.cancelFor(dose.id);
        } catch (e, st) {
          debugPrint('DawaCare medication DELETE reminder cleanup failed dose=${dose.id}: $e');
          debugPrintStack(stackTrace: st);
        }
      }
    } catch (e, st) {
      debugPrint('DawaCare medication DELETE reminder cleanup skipped id=${medication.id}: $e');
      debugPrintStack(stackTrace: st);
    }

    try {
      await _repo.deleteMedication(medication.id);
      debugPrint('DawaCare medication DELETE DB SUCCESS id=${medication.id}');
    } catch (e, st) {
      debugPrint('DawaCare medication DELETE FAILED id=${medication.id}: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }

    medications.removeWhere((m) => m.id == medication.id);
    schedulesByMedicationId.remove(medication.id);
    _imageUrlFutures.removeWhere((key, _) => key == medication.imageUrl);
    _notify();
    debugPrint('DawaCare medication DELETE SUCCESS id=${medication.id}');
  }

  String _unitForDosageForm(String? form) {
    switch ((form ?? '').trim()) {
      case 'كبسولة':
      case 'Capsule': return 'capsule';
      case 'قرص':
      case 'Tablet': return 'tablet';
      case 'شراب':
      case 'Syrup': return 'ml';
      case 'قطرة':
      case 'Drop': return 'drop';
      case 'حقنة':
      case 'Injection': return 'injection';
      default: return 'unit';
    }
  }

  Medication _copyMedication(Medication medication, {String? imageUrl, bool clearImage = false, bool? active, bool? stockEnabled, double? stockQuantity, String? stockUnit}) {
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
      active: active ?? medication.active,
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
