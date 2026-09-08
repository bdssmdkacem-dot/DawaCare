import 'dart:developer' as developer;

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
  final SupabaseClient _client = Supabase.instance.client;

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
      _client.from('medications').select('id').eq('patient_id', patientId).eq('active', true),
      _client
          .from('dose_instances')
          .select('*')
          .eq('patient_id', patientId)
          .gte('scheduled_at', start.toUtc().toIso8601String())
          .lt('scheduled_at', end.toUtc().toIso8601String())
          .order('scheduled_at'),
    ]);
    final medicationRows = results[0] as List;
    final doseRows = results[1] as List;
    final doses = doseRows
        .map((row) => DoseInstance.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
    return FamilyMemberSummary.fromDoses(
      activeMedicationCount: medicationRows.length,
      todayDoses: doses,
    );
  }

  Future<void> unlink(String linkId) async {
    await _client.from('caregiver_patient').delete().eq('id', linkId);
  }

  Future<FamilyLinkCode> createLinkCode() async {
    final rows = await _client.rpc('create_family_link_code');
    return FamilyLinkCode.fromMap((rows as List).first as Map<String, dynamic>);
  }

  Future<String> requestLink({
    required String code,
    required CaregiverRole role,
    String? relationshipLabel,
  }) async {
    try {
      final rows = await _client.rpc('request_family_link', params: {
        'p_code': _normalizeLinkCode(code),
        'p_relationship_label': relationshipLabel,
        'p_role': caregiverRoleToDb(role),
      });
      final row = (rows as List).first as Map<String, dynamic>;
      final requestId = row['request_id'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        await _notifyFamilyLink(requestId, 'REQUESTED');
      }
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

  Future<String> respondToRequest({required String requestId, required bool approve}) async {
    try {
      final rows = await _client.rpc('respond_family_link_request', params: {
        'p_request_id': requestId,
        'p_approve': approve,
      });
      final row = (rows as List).first as Map<String, dynamic>;
      final status = row['status'] as String? ?? (approve ? 'APPROVED' : 'REJECTED');
      await _notifyFamilyLink(requestId, approve ? 'APPROVED' : 'REJECTED');
      return status;
    } on PostgrestException catch (e) {
      throw FamilyLinkException(_extractCode(e.message));
    }
  }

  Future<void> _notifyFamilyLink(String requestId, String eventType) async {
    try {
      final response = await _client.functions.invoke(
        'family-link-notify',
        body: {'request_id': requestId, 'event_type': eventType},
      );
      if (response.status < 200 || response.status >= 300) {
        developer.log(
          'family-link-notify failed: status=${response.status} body=${response.data}',
          name: 'DawaCare.notifications',
        );
        throw StateError('family-link-notify failed: ${response.status}');
      }
      developer.log(
        'family-link-notify success: event=$eventType request=$requestId body=${response.data}',
        name: 'DawaCare.notifications',
      );
    } catch (error, stackTrace) {
      developer.log(
        'family-link-notify exception: event=$eventType request=$requestId error=$error',
        name: 'DawaCare.notifications',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<FamilyLinkRequest>> fetchIncomingRequests(String patientId) async {
    final rows = await _client
        .from('family_link_requests')
        .select('*, caregiver:profiles!caregiver_id(full_name)')
        .eq('patient_id', patientId)
        .eq('status', 'PENDING')
        .order('requested_at', ascending: false);
    return rows.map((r) => FamilyLinkRequest.fromMap(r)).toList();
  }

  Future<List<FamilyLinkRequest>> fetchSentRequests(String caregiverId) async {
    final rows = await _client
        .from('family_link_requests')
        .select('*, patient:profiles!patient_id(full_name)')
        .eq('caregiver_id', caregiverId)
        .eq('status', 'PENDING')
        .order('requested_at', ascending: false);
    return rows.map((r) => FamilyLinkRequest.fromMap(r)).toList();
  }

  Future<List<CaregiverAlert>> fetchAlerts(
    String caregiverId, {
    bool unreadOnly = false,
  }) async {
    var query = _client
        .from('caregiver_alerts')
        .select('*, patient:profiles!patient_id(full_name)')
        .eq('caregiver_id', caregiverId);
    if (unreadOnly) {
      query = query.eq('read', false);
    }
    final rows = await query.order('created_at', ascending: false).limit(50);
    return rows.map((r) => CaregiverAlert.fromMap(r)).toList();
  }

  Future<void> markAlertRead(String alertId) async {
    await _client.from('caregiver_alerts').update({'read': true}).eq('id', alertId);
  }

  String _normalizeLinkCode(String value) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const extendedArabicIndic = '۰۱۲۳۴۵۶۷۸۹';
    const latin = '0123456789';
    var result = value.trim();
    for (var i = 0; i < latin.length; i++) {
      result = result.replaceAll(arabicIndic[i], latin[i]);
      result = result.replaceAll(extendedArabicIndic[i], latin[i]);
    }
    return result.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _extractCode(String message) {
    final match = RegExp(r'[A-Z_]{6,}').firstMatch(message);
    return match?.group(0) ?? 'UNKNOWN_ERROR';
  }
}