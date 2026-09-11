import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/caregiver_alert.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/dose_instance.dart';
import '../../../models/family_link_code.dart';
import '../../../models/family_link_request.dart';
import '../../../models/family_member_summary.dart';

/// Errors surfaced by the family_link_* RPCs.
class FamilyLinkException implements Exception {
  final String code;
  const FamilyLinkException(this.code);

  @override
  String toString() => 'FamilyLinkException($code)';
}

class CaregiverRepository {
  final SupabaseClient _client;

  CaregiverRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<CaregiverLink>> fetchLinkedPatients(String caregiverId) async {
    final rows = await _client
        .from('caregiver_patient')
        .select('*, patient:profiles!patient_id(full_name, avatar_url)')
        .eq('caregiver_id', caregiverId)
        .order('created_at');
    return rows.map((r) => CaregiverLink.fromMap(r)).toList();
  }

  Future<FamilyMemberSummary> fetchMemberSummary(String patientId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final results = await Future.wait([
      _client
          .from('medications')
          .select('id')
          .eq('patient_id', patientId)
          .eq('is_active', true),
      _client
          .from('dose_instances')
          .select('*')
          .eq('patient_id', patientId)
          .gte('scheduled_at', start.toUtc().toIso8601String())
          .lt('scheduled_at', end.toUtc().toIso8601String())
          .order('scheduled_at'),
    ]);

    final medications = results[0] as List;
    final doseRows = results[1] as List;
    final doses = doseRows.map((r) => DoseInstance.fromMap(r)).toList();
    return FamilyMemberSummary.fromDoses(
      activeMedicationCount: medications.length,
      doses: doses,
    );
  }

  Future<List<CaregiverAlert>> fetchAlerts(String caregiverId) async {
    final rows = await _client
        .from('caregiver_alerts')
        .select()
        .eq('caregiver_id', caregiverId)
        .order('created_at', ascending: false);
    return rows.map((r) => CaregiverAlert.fromMap(r)).toList();
  }

  Future<List<FamilyLinkRequest>> fetchIncomingRequests(String caregiverId) async {
    final rows = await _client
        .from('family_link_requests')
        .select('*, patient:profiles!patient_id(full_name, avatar_url)')
        .eq('caregiver_id', caregiverId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return rows.map((r) => FamilyLinkRequest.fromMap(r)).toList();
  }

  Future<List<FamilyLinkRequest>> fetchSentRequests(String patientId) async {
    final rows = await _client
        .from('family_link_requests')
        .select('*, caregiver:profiles!caregiver_id(full_name, avatar_url)')
        .eq('patient_id', patientId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return rows.map((r) => FamilyLinkRequest.fromMap(r)).toList();
  }

  Future<void> markAlertRead(String alertId) async {
    await _client.from('caregiver_alerts').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', alertId);
  }

  Future<void> unlink(String linkId) async {
    await _client.from('caregiver_patient').delete().eq('id', linkId);
  }

  Future<FamilyLinkCode> createLinkCode() async {
    final response = await _client.rpc('create_family_link_code');
    return FamilyLinkCode.fromMap(response);
  }

  Future<String?> requestLink({
    required String code,
    required CaregiverRole role,
    String? relationshipLabel,
  }) async {
    try {
      final response = await _client.rpc('request_family_link', params: {
        'p_code': code,
        'p_role': role.name,
        'p_relationship_label': relationshipLabel,
      });
      return response == null ? null : response.toString();
    } on PostgrestException catch (e) {
      throw FamilyLinkException(e.code ?? e.message);
    }
  }

  Future<void> cancelRequest(String requestId) async {
    await _client.rpc('cancel_family_link_request', params: {'p_request_id': requestId});
  }

  Future<void> respondToRequest({required String requestId, required bool approve}) async {
    try {
      await _client.rpc('respond_to_family_link_request', params: {
        'p_request_id': requestId,
        'p_approve': approve,
      });
    } on PostgrestException catch (e) {
      throw FamilyLinkException(e.code ?? e.message);
    }
  }
}
