import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/medication.dart';
import '../../../models/medication_schedule.dart';
import 'medication_image_service.dart';

class MedicationRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final MedicationImageService _imageService = MedicationImageService();

  static const futureUnresolvedDoseStatuses = <String>[
    'PENDING',
    'REMINDER_SENT',
    'SNOOZED',
    'MISSED',
  ];

  Future<List<Medication>> fetchMedications(String patientId, {bool activeOnly = true}) async { var query = _client.from('medications').select().eq('patient_id', patientId); if (activeOnly) query = query.eq('active', true); final rows = await query.order('created_at', ascending: false); return rows.map((r) => Medication.fromMap(r)).toList(); }
  Future<List<MedicationSchedule>> fetchSchedules(String medicationId) async { final today = DateTime.now().toIso8601String().split('T').first; final rows = await _client.from('medication_schedules').select().eq('medication_id', medicationId).or('end_date.is.null,end_date.gte.$today'); return rows.map((r) => MedicationSchedule.fromMap(r)).toList(); }
  Future<List<Map<String, dynamic>>> fetchStockTransactions(String medicationId) async { final rows = await _client.from('medication_stock_transactions').select('id, medication_id, patient_id, quantity, transaction_type, dose_id, note, created_by, created_at').eq('medication_id', medicationId).order('created_at', ascending: false).limit(100); return rows.map((row) => Map<String, dynamic>.from(row)).toList(); }

  Future<Medication> createMedication(Medication medication, {Uint8List? imageBytes}) async {
    final insertData = medication.toInsertMap()..['stock_quantity'] = 0;
    final row = await _client.from('medications').insert(insertData).select().single();
    var created = Medication.fromMap(row);
    String? uploadedPath;
    try {
      if (imageBytes != null) {
        uploadedPath = await _imageService.upload(patientId: created.patientId, medicationId: created.id, bytes: imageBytes);
        final updated = await _client.from('medications').update({'image_url': uploadedPath}).eq('id', created.id).select().single();
        created = Medication.fromMap(updated);
      }
      if (medication.stockEnabled && medication.stockQuantity > 0) {
        await addStock(medicationId: created.id, patientId: created.patientId, quantity: medication.stockQuantity, type: 'INITIAL', note: 'Initial medication stock');
        final refreshed = await _client.from('medications').select().eq('id', created.id).single();
        created = Medication.fromMap(refreshed);
      }
    } catch (_) {
      await _imageService.delete(uploadedPath);
      await _client.from('medications').delete().eq('id', created.id);
      rethrow;
    }
    return created;
  }

  Future<Medication> updateMedication(Medication medication) async {
    final data = medication.toInsertMap()..remove('stock_quantity');
    final row = await _client.from('medications').update(data).eq('id', medication.id).select().single();
    return Medication.fromMap(row);
  }

  Future<double> addStock({required String medicationId, required String patientId, required double quantity, String type = 'ADD', String? note}) async { final result = await _client.rpc('apply_medication_stock_transaction', params: {'p_medication_id': medicationId, 'p_patient_id': patientId, 'p_quantity': quantity, 'p_transaction_type': type, 'p_dose_id': null, 'p_note': note}); return (result as num).toDouble(); }
  Future<Map<String, dynamic>> updateStockSettings({required String medicationId, required String unit, required double? packageQuantity, required double threshold}) async { final row = await _client.from('medications').update({'stock_enabled': true, 'stock_unit': unit, 'package_quantity': packageQuantity, 'low_stock_threshold': threshold}).eq('id', medicationId).select().single(); return row; }
  Future<String> updateMedicationImage({required Medication medication, required Uint8List bytes}) async { final oldPath = medication.imageUrl; final newPath = await _imageService.upload(patientId: medication.patientId, medicationId: medication.id, bytes: bytes); try { await _client.from('medications').update({'image_url': newPath}).eq('id', medication.id); if (oldPath != null && oldPath != newPath) await _imageService.delete(oldPath); return newPath; } catch (_) { await _imageService.delete(newPath); rethrow; } }
  Future<void> removeMedicationImage(Medication medication) async { await _imageService.delete(medication.imageUrl); await _client.from('medications').update({'image_url': null}).eq('id', medication.id); }
  Future<String?> signedMedicationImageUrl(String? imagePath) => _imageService.signedUrl(imagePath);
  Future<MedicationSchedule> createSchedule(String medicationId, MedicationSchedule schedule) async { final row = await _client.from('medication_schedules').insert(schedule.toInsertMap(medicationId)).select().single(); return MedicationSchedule.fromMap(row); }
  Future<MedicationSchedule> updateSchedule(MedicationSchedule schedule) async { final data = schedule.toInsertMap(schedule.medicationId)..remove('medication_id'); final row = await _client.from('medication_schedules').update(data).eq('id', schedule.id).select().single(); return MedicationSchedule.fromMap(row); }
  Future<void> retireSchedule(String scheduleId, DateTime endDate) async { await _client.from('medication_schedules').update({'end_date': endDate.toIso8601String().split('T').first}).eq('id', scheduleId); }

  Future<List<MedicationSchedule>> replaceSchedules({required String medicationId, required List<MedicationSchedule> schedules}) async {
    final existing = await _client.from('medication_schedules').select('id').eq('medication_id', medicationId);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final replacementFrom = DateTime.now();
    for (final row in existing) {
      final scheduleId = row['id'] as String;
      await deleteFutureUnresolvedDoses(scheduleId, replacementFrom);
      await retireSchedule(scheduleId, yesterday);
    }
    final created = <MedicationSchedule>[];
    for (final schedule in schedules) {
      created.add(await createSchedule(medicationId, schedule));
    }
    return created;
  }

  Future<void> deleteFutureUnresolvedDoses(String scheduleId, DateTime from) async {
    final fromUtc = from.toUtc().toIso8601String();
    for (final status in futureUnresolvedDoseStatuses) {
      await _client.from('dose_instances').delete().eq('schedule_id', scheduleId).eq('status', status).gte('scheduled_at', fromUtc);
    }
  }
  Future<void> deleteFuturePendingDoses(String scheduleId, DateTime from) async { await _client.from('dose_instances').delete().eq('schedule_id', scheduleId).eq('status', 'PENDING').gte('scheduled_at', from.toUtc().toIso8601String()); }

  /// Stops a medication without deleting its history, stock, schedules or image.
  /// Future unresolved doses are handled by MedicationProvider before this call.
  Future<void> deactivateMedication(String medicationId) async {
    debugPrint('DawaCare medication DEACTIVATE START id=$medicationId');
    try {
      final rows = await _client
          .from('medications')
          .update({'active': false})
          .eq('id', medicationId)
          .select('id, active');

      debugPrint('DawaCare medication DEACTIVATE RESULT id=$medicationId rows=${rows.length} data=$rows');
      if (rows.isEmpty) {
        throw StateError('DEACTIVATE_NO_ROWS_UPDATED medication_id=$medicationId. Check medication RLS/update policy and patient permissions.');
      }
      final active = rows.first['active'];
      if (active != false) {
        throw StateError('DEACTIVATE_VERIFY_FAILED medication_id=$medicationId active=$active');
      }
    } on PostgrestException catch (e, st) {
      debugPrint('DawaCare medication DEACTIVATE POSTGREST id=$medicationId code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}');
      debugPrintStack(stackTrace: st);
      rethrow;
    } catch (e, st) {
      debugPrint('DawaCare medication DEACTIVATE FAILED id=$medicationId error=$e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  /// Permanently deletes the medication row. Database CASCADE constraints remove
  /// schedules, doses, stock transactions and caregiver alerts. The image is
  /// removed through the Storage API as a best-effort cleanup.
  Future<void> deleteMedication(String medicationId) async {
    debugPrint('DawaCare medication DELETE START id=$medicationId');
    String? imagePath;
    try {
      final rows = await _client.from('medications').select('id, image_url').eq('id', medicationId);
      debugPrint('DawaCare medication DELETE FETCH id=$medicationId rows=${rows.length}');
      if (rows.isEmpty) {
        throw StateError('DELETE_NOT_FOUND medication_id=$medicationId');
      }
      imagePath = rows.first['image_url'] as String?;

      final deleted = await _client
          .from('medications')
          .delete()
          .eq('id', medicationId)
          .select('id');
      debugPrint('DawaCare medication DELETE RESULT id=$medicationId rows=${deleted.length} data=$deleted');
      if (deleted.isEmpty) {
        throw StateError('DELETE_NO_ROWS_DELETED medication_id=$medicationId. Check medication RLS/delete policy and patient permissions.');
      }

      if (imagePath != null && imagePath.isNotEmpty) {
        try {
          await _imageService.delete(imagePath);
          debugPrint('DawaCare medication DELETE IMAGE OK id=$medicationId path=$imagePath');
        } catch (e, st) {
          debugPrint('DawaCare medication DELETE IMAGE FAILED id=$medicationId path=$imagePath error=$e');
          debugPrintStack(stackTrace: st);
        }
      }
      debugPrint('DawaCare medication DELETE SUCCESS id=$medicationId');
    } on PostgrestException catch (e, st) {
      debugPrint('DawaCare medication DELETE POSTGREST id=$medicationId code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}');
      debugPrintStack(stackTrace: st);
      rethrow;
    } catch (e, st) {
      debugPrint('DawaCare medication DELETE FAILED id=$medicationId error=$e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }
}
