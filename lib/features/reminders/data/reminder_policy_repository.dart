import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/reminder_policy.dart';

class ReminderPolicyRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<ReminderPolicy> fetch(String patientId) async {
    final row = await _client.from('reminder_policies').select().eq('patient_id', patientId).maybeSingle();
    if (row == null) return ReminderPolicy(patientId: patientId);
    return ReminderPolicy.fromMap(row);
  }

  Future<ReminderPolicy> save(ReminderPolicy policy) async {
    final row = await _client.from('reminder_policies').upsert(policy.toUpsertMap()).select().single();
    return ReminderPolicy.fromMap(row);
  }
}
