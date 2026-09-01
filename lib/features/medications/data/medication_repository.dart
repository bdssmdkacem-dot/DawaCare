import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/medication.dart';
import '../../../models/medication_schedule.dart';

class MedicationRepository {
  final SupabaseClient _client = Supabase.instance.client;

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

  Future<Medication> createMedication(Medication medication) async {
    final row = await _client.from('medications').insert(medication.toInsertMap()).select().single();
    return Medication.fromMap(row);
  }

  Future<MedicationSchedule> createSchedule(String medicationId, MedicationSchedule schedule) async {
    final row = await _client
        .from('medication_schedules')
        .insert(schedule.toInsertMap(medicationId))
        .select()
        .single();
    return MedicationSchedule.fromMap(row);
  }

  Future<void> deactivateMedication(String medicationId) async {
    await _client.from('medications').update({'active': false}).eq('id', medicationId);
  }

  Future<void> deleteMedication(String medicationId) async {
    await _client.from('medications').delete().eq('id', medicationId);
  }
}
