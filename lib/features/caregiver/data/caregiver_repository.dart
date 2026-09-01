import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/caregiver_alert.dart';
import '../../../models/caregiver_link.dart';

class CaregiverRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<CaregiverLink>> fetchLinkedPatients(String caregiverId) async {
    final rows = await _client
        .from('caregiver_patient')
        .select('*, patient:profiles!patient_id(full_name)')
        .eq('caregiver_id', caregiverId)
        .order('created_at');
    return rows.map((r) => CaregiverLink.fromMap(r)).toList();
  }

  /// Links the current user (as caregiver) to a patient identified by their
  /// 6-character family code, via the `link_family_member` RPC — see
  /// supabase/schema.sql for why this can't be a plain insert.
  Future<String> linkByFamilyCode(String code) async {
    final rows = await _client.rpc('link_family_member', params: {'p_family_code': code});
    final row = (rows as List).first as Map<String, dynamic>;
    return row['patient_name'] as String? ?? 'مريض';
  }

  Future<void> unlink(String linkId) async {
    await _client.from('caregiver_patient').delete().eq('id', linkId);
  }

  Future<List<CaregiverAlert>> fetchAlerts(String caregiverId, {bool unreadOnly = false}) async {
    var query = _client
        .from('caregiver_alerts')
        .select('*, patient:profiles!patient_id(full_name)')
        .eq('caregiver_id', caregiverId);
    if (unreadOnly) query = query.eq('read', false);
    final rows = await query.order('created_at', ascending: false).limit(50);
    return rows.map((r) => CaregiverAlert.fromMap(r)).toList();
  }

  Future<void> markAlertRead(String alertId) async {
    await _client.from('caregiver_alerts').update({'read': true}).eq('id', alertId);
  }
}
