import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/medication.dart';
import '../../../models/medication_schedule.dart';
import 'medication_image_service.dart';

class MedicationRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final MedicationImageService _imageService = MedicationImageService();

  Future<List<Medication>> fetchMedications(String patientId, {bool activeOnly = true}) async {
    var query = _client.from('medications').select().eq('patient_id', patientId);
    if (activeOnly) query = query.eq('active', true);
    final rows = await query.order('created_at', ascending: false);
    return rows.map((r) => Medication.fromMap(r)).toList();
  }

  Future<List<MedicationSchedule>> fetchSchedules(String medicationId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final rows = await _client
        .from('medication_schedules')
        .select()
        .eq('medication_id', medicationId)
        .or('end_date.is.null,end_date.gte.$today');
    return rows.map((r) => MedicationSchedule.fromMap(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchStockTransactions(String medicationId) async {
    final rows = await _client
        .from('medication_stock_transactions')
        .select('id, medication_id, patient_id, quantity, transaction_type, dose_id, note, created_by, created_at')
        .eq('medication_id', medicationId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Medication> createMedication(Medication medication, {Uint8List? imageBytes}) async {
    final row = await _client.from('medications').insert(medication.toInsertMap()).select().single();
    var created = Medication.fromMap(row);
    String? uploadedPath;
    try {
      if (imageBytes != null) {
        uploadedPath = await _imageService.upload(patientId: created.patientId, medicationId: created.id, bytes: imageBytes);
        final updated = await _client.from('medications').update({'image_url': uploadedPath}).eq('id', created.id).select().single();
        created = Medication.fromMap(updated);
      }
      if (medication.stockEnabled && medication.stockQuantity > 0) {
        final newQuantity = await addStock(
          medicationId: created.id,
          patientId: created.patientId,
          quantity: medication.stockQuantity,
          type: 'INITIAL',
          note: 'Initial medication stock',
        );
        created = Medication(
          id: created.id, patientId: created.patientId, name: created.name, genericName: created.genericName,
          strength: created.strength, dosageForm: created.dosageForm, instructions: created.instructions,
          imageUrl: created.imageUrl, startDate: created.startDate, endDate: created.endDate, active: created.active,
          createdBy: created.createdBy, createdAt: created.createdAt, stockEnabled: true, stockQuantity: newQuantity,
          stockUnit: medication.stockUnit, packageQuantity: medication.packageQuantity, lowStockThreshold: medication.lowStockThreshold,
        );
      }
    } catch (_) {
      await _imageService.delete(uploadedPath);
      await _client.from('medications').delete().eq('id', created.id);
      rethrow;
    }
    return created;
  }

  Future<Medication> updateMedication(Medication medication) async {
    final row = await _client.from('medications').update(medication.toInsertMap()).eq('id', medication.id).select().single();
    return Medication.fromMap(row);
  }

  Future<double> addStock({required String medicationId, required String patientId, required double quantity, String type = 'ADD', String? note}) async {
    final result = await _client.rpc('apply_medication_stock_transaction', params: {
      'p_medication_id': medicationId,
      'p_patient_id': patientId,
      'p_quantity': quantity,
      'p_transaction_type': type,
      'p_dose_id': null,
      'p_note': note,
    });
    return (result as num).toDouble();
  }

  Future<Map<String, dynamic>> updateStockSettings({required String medicationId, required String unit, required double? packageQuantity, required double threshold}) async {
    final row = await _client.from('medications').update({
      'stock_enabled': true,
      'stock_unit': unit,
      'package_quantity': packageQuantity,
      'low_stock_threshold': threshold,
    }).eq('id', medicationId).select().single();
    return row;
  }

  Future<String> updateMedicationImage({required Medication medication, required Uint8List bytes}) async {
    final oldPath = medication.imageUrl;
    final newPath = await _imageService.upload(patientId: medication.patientId, medicationId: medication.id, bytes: bytes);
    try {
      await _client.from('medications').update({'image_url': newPath}).eq('id', medication.id);
      if (oldPath != null && oldPath != newPath) await _imageService.delete(oldPath);
      return newPath;
    } catch (_) {
      await _imageService.delete(newPath);
      rethrow;
    }
  }

  Future<void> removeMedicationImage(Medication medication) async {
    await _imageService.delete(medication.imageUrl);
    await _client.from('medications').update({'image_url': null}).eq('id', medication.id);
  }

  Future<String?> signedMedicationImageUrl(String? imagePath) => _imageService.signedUrl(imagePath);

  Future<MedicationSchedule> createSchedule(String medicationId, MedicationSchedule schedule) async {
    final row = await _client.from('medication_schedules').insert(schedule.toInsertMap(medicationId)).select().single();
    return MedicationSchedule.fromMap(row);
  }

  Future<MedicationSchedule> updateSchedule(MedicationSchedule schedule) async {
    final data = schedule.toInsertMap(schedule.medicationId)..remove('medication_id');
    final row = await _client.from('medication_schedules').update(data).eq('id', schedule.id).select().single();
    return MedicationSchedule.fromMap(row);
  }

  Future<void> retireSchedule(String scheduleId, DateTime endDate) async {
    await _client.from('medication_schedules').update({
      'end_date': endDate.toIso8601String().split('T').first,
    }).eq('id', scheduleId);
  }

  /// Rebuilds the future schedule while preserving old schedule rows and dose history.
  /// Existing schedules are retired yesterday; new schedules receive fresh IDs.
  Future<List<MedicationSchedule>> replaceSchedules({
    required String medicationId,
    required List<MedicationSchedule> schedules,
  }) async {
    final existing = await _client.from('medication_schedules').select('id').eq('medication_id', medicationId);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    for (final row in existing) {
      await retireSchedule(row['id'] as String, yesterday);
    }
    final created = <MedicationSchedule>[];
    for (final schedule in schedules) {
      created.add(await createSchedule(medicationId, schedule));
    }
    return created;
  }

  /// Removes only future, unresolved dose occurrences for a schedule.
  /// Resolved history (TAKEN/SKIPPED/CANCELLED) is intentionally preserved.
  Future<void> deleteFutureUnresolvedDoses(String scheduleId, DateTime from) async {
    final fromUtc = from.toUtc().toIso8601String();
    for (final status in const ['PENDING', 'REMINDER_SENT', 'SNOOZED', 'MISSED']) {
      await _client
          .from('dose_instances')
          .delete()
          .eq('schedule_id', scheduleId)
          .eq('status', status)
          .gte('scheduled_at', fromUtc);
    }
  }

  Future<void> deleteFuturePendingDoses(String scheduleId, DateTime from) async {
    await _client.from('dose_instances').delete().eq('schedule_id', scheduleId).eq('status', 'PENDING').gte('scheduled_at', from.toUtc().toIso8601String());
  }

  Future<void> deactivateMedication(String medicationId) async => _client.from('medications').update({'active': false}).eq('id', medicationId);
  Future<void> deleteMedication(String medicationId) async => _client.from('medications').delete().eq('id', medicationId);
}
