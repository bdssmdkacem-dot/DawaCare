import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/caregiver_alert.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/family_link_code.dart';
import '../../../models/family_link_request.dart';

/// Errors surfaced by the family_link_* RPCs (see supabase/README.md §1).
/// Kept as plain string codes matching the Postgres `raise exception`
/// messages, so the provider layer can translate each into user-facing
/// Arabic without the repository needing to know about UI strings.
class FamilyLinkException implements Exception {
  final String code;
  const FamilyLinkException(this.code);
  @override
  String toString() => 'FamilyLinkException($code)';
}

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

  Future<void> unlink(String linkId) async {
    await _client.from('caregiver_patient').delete().eq('id', linkId);
  }

  // ---- Family link codes (patient side) ------------------------------------

  /// Generates a fresh 15-minute, single-use code for the current user to
  /// share. Calling this again before the previous code expires silently
  /// invalidates it (see create_family_link_code() in the migration) — the
  /// UI only ever needs to track "the current" code.
  Future<FamilyLinkCode> createLinkCode() async {
    final rows = await _client.rpc('create_family_link_code');
    return FamilyLinkCode.fromMap((rows as List).first as Map<String, dynamic>);
  }

  // ---- Family link requests (caregiver side) --------------------------------

  /// Submits a code entered by the caregiver. Throws [FamilyLinkException]
  /// with one of: CODE_INVALID_OR_EXPIRED, CANNOT_LINK_SELF, ALREADY_LINKED,
  /// REQUEST_ALREADY_PENDING.
  Future<String> requestLink({required String code, String? relationshipLabel}) async {
    try {
      final rows = await _client.rpc('request_family_link', params: {
        'p_code': code,
        'p_relationship_label': relationshipLabel,
      });
      final row = (rows as List).first as Map<String, dynamic>;
      return row['patient_name'] as String? ?? 'مريض';
    } on PostgrestException catch (e) {
      throw FamilyLinkException(_extractCode(e.message));
    }
  }

  Future<void> cancelRequest(String requestId) async {
    try {
      await _client.rpc('cancel_family_link_request', params: {'p_request_id': requestId});
    } on PostgrestException catch (e) {
      throw FamilyLinkException(_extractCode(e.message));
    }
  }

  // ---- Family link requests (patient side) -----------------------------------

  Future<String> respondToRequest({required String requestId, required bool approve}) async {
    try {
      final rows = await _client.rpc('respond_family_link_request', params: {
        'p_request_id': requestId,
        'p_approve': approve,
      });
      final row = (rows as List).first as Map<String, dynamic>;
      return row['status'] as String;
    } on PostgrestException catch (e) {
      throw FamilyLinkException(_extractCode(e.message));
    }
  }

  /// Requests where I'm the patient and a caregiver is waiting on my answer.
  Future<List<FamilyLinkRequest>> fetchIncomingRequests(String patientId) async {
    final rows = await _client
        .from('family_link_requests')
        .select('*, caregiver:profiles!caregiver_id(full_name)')
        .eq('patient_id', patientId)
        .eq('status', 'PENDING')
        .order('requested_at', ascending: false);
    return rows.map((r) => FamilyLinkRequest.fromMap(r)).toList();
  }

  /// Requests I've sent as a caregiver that are still awaiting the patient.
  Future<List<FamilyLinkRequest>> fetchSentRequests(String caregiverId) async {
    final rows = await _client
        .from('family_link_requests')
        .select('*, patient:profiles!patient_id(full_name)')
        .eq('caregiver_id', caregiverId)
        .eq('status', 'PENDING')
        .order('requested_at', ascending: false);
    return rows.map((r) => FamilyLinkRequest.fromMap(r)).toList();
  }

  // ---- Alerts (unchanged) ----------------------------------------------------

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

  /// Postgres RPC errors arrive wrapped, e.g. `... CODE_INVALID_OR_EXPIRED`.
  /// Since these are our own `raise exception 'CODE'` calls (all-caps,
  /// underscore-only, no spaces), pulling out that token is reliable without
  /// needing structured error codes from Postgres.
  String _extractCode(String message) {
    final match = RegExp(r'[A-Z_]{6,}').firstMatch(message);
    return match?.group(0) ?? 'UNKNOWN_ERROR';
  }
}
