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
    final rows = await _client.from('medication_schedules').select().eq('medication_id', medicationId);
    return rows.map((r) => MedicationSchedule.fromMap(r)).toList();
  }

  Future<Medication> createMedication(Medication medication, {Uint8List? imageBytes}) async {
    final row = await _client.from('medications').insert(medication.toInsertMap()).select().single();
    var created = Medication.fromMap(row);
    String? uploadedPath;

    if (imageBytes != null) {
      try {
        uploadedPath = await _imageService.upload(
          patientId: created.patientId,
          medicationId: created.id,
          bytes: imageBytes,
        );
        final updated = await _client
            .from('medications')
            .update({'image_url': uploadedPath})
            .eq('id', created.id)
            .select()
            .single();
        created = Medication.fromMap(updated);
      } catch (_) {
        await _imageService.delete(uploadedPath);
        await _client.from('medications').delete().eq('id', created.id);
        rethrow;
      }
    }

    return created;
  }

  Future<String> updateMedicationImage({
    required Medication medication,
    required Uint8List bytes,
  }) async {
    final oldPath = medication.imageUrl;
    final newPath = await _imageService.upload(
      patientId: medication.patientId,
      medicationId: medication.id,
      bytes: bytes,
    );
    try {
      await _client.from('medications').update({'image_url': newPath}).eq('id', medication.id);
      if (oldPath != null && oldPath != newPath) {
        await _imageService.delete(oldPath);
      }
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
    final row = await _client
        .from('medication_schedules')
        .update(data)
        .eq('id', schedule.id)
        .select()
        .single();
    return MedicationSchedule.fromMap(row);
  }

  Future<void> deleteFuturePendingDoses(String scheduleId, DateTime from) async {
    await _client
        .from('dose_instances')
        .delete()
        .eq('schedule_id', scheduleId)
        .eq('status', 'PENDING')
        .gte('scheduled_at', from.toUtc().toIso8601String());
  }

  Future<void> deactivateMedication(String medicationId) async {
    await _client.from('medications').update({'active': false}).eq('id', medicationId);
  }

  Future<void> deleteMedication(String medicationId) async {
    await _client.from('medications').delete().eq('id', medicationId);
  }
}
