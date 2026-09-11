import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/database/local_database.dart';
import '../../core/network/connectivity_service.dart';

/// Replays queued offline writes against Supabase once connectivity returns.
///
/// Queue order is preserved. A successful transition, an already-applied
/// transition, or a lifecycle conflict that has been observed on the server
/// is considered terminal for that queue item. Transient failures remain in
/// the queue and are retried later.
class SyncEngine {
  SyncEngine._();
  static final SyncEngine instance = SyncEngine._();

  final SupabaseClient _client = Supabase.instance.client;
  final LocalDatabase _local = LocalDatabase.instance;

  StreamSubscription<bool>? _connectivitySub;
  bool _flushing = false;

  void start() {
    ConnectivityService.instance.start();
    _connectivitySub ??=
        ConnectivityService.instance.onOnlineChanged.listen((online) {
      if (online) {
        flushQueue();
      }
    });
    flushQueue();
  }

  Future<void> flushQueue() async {
    if (_flushing) return;
    if (!await ConnectivityService.instance.checkNow()) return;

    _flushing = true;
    try {
      final pending = await _local.pendingSyncOperations();
      for (final op in pending) {
        final outcome = await _replay(op);
        if (outcome == _ReplayOutcome.completed ||
            outcome == _ReplayOutcome.conflict) {
          await _local.markSynced(op['id'] as String);
          if (outcome == _ReplayOutcome.conflict) {
            await _refreshConflictedDose(op);
          }
          continue;
        }

        // Stop at the first transient failure so a later operation cannot
        // overtake an earlier offline write.
        await _local.incrementRetry(op['id'] as String);
        break;
      }
    } finally {
      _flushing = false;
    }
  }

  Future<_ReplayOutcome> _replay(Map<String, dynamic> op) async {
    try {
      final payload = jsonDecode(op['payload'] as String) as Map<String, dynamic>;

      switch (op['entity_type']) {
        case 'DOSE_STATUS':
          return await _replayDoseStatus(payload);
        default:
          // Unknown operations must not block the entire queue forever.
          return _ReplayOutcome.completed;
      }
    } on FormatException {
      return _ReplayOutcome.completed;
    } catch (_) {
      return _ReplayOutcome.retry;
    }
  }

  Future<_ReplayOutcome> _replayDoseStatus(
    Map<String, dynamic> payload,
  ) async {
    final doseId = payload['dose_id'] as String?;
    final patientId = payload['patient_id'] as String?;
    final status = payload['status'] as String?;
    final source = payload['source'] as String? ?? 'PATIENT';

    if (doseId == null || patientId == null || status == null) {
      return _ReplayOutcome.completed;
    }

    final rows = await _client.rpc(
      'apply_dose_status_transition',
      params: {
        'p_dose_id': doseId,
        'p_patient_id': patientId,
        'p_to_status': status,
        'p_source': source,
      },
    ) as List<dynamic>;

    if (rows.isEmpty) {
      return _ReplayOutcome.retry;
    }

    final result = Map<String, dynamic>.from(rows.first as Map);
    final applied = result['applied'] == true;
    final currentStatus = result['current_status'] as String?;

    if (applied || currentStatus == status) {
      return _ReplayOutcome.completed;
    }

    // The server has a newer/incompatible lifecycle state. This is a
    // permanent conflict for this queued intent, not a network failure.
    return _ReplayOutcome.conflict;
  }

  Future<void> _refreshConflictedDose(Map<String, dynamic> op) async {
    try {
      final payload = jsonDecode(op['payload'] as String) as Map<String, dynamic>;
      final doseId = payload['dose_id'] as String?;
      if (doseId == null) return;

      final row = await _client
          .from('dose_instances')
          .select('*, medications(name)')
          .eq('id', doseId)
          .maybeSingle();
      if (row != null) {
        final localRow = DoseRowNormalizer.toLocalRow(row);
        await _local.upsertDose(localRow);
      }
    } catch (_) {
      // Queue conflict is already terminal. A later normal fetch can refresh
      // the local cache if this best-effort read fails.
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }
}

enum _ReplayOutcome { completed, conflict, retry }

class DoseRowNormalizer {
  const DoseRowNormalizer._();

  static Map<String, dynamic> toLocalRow(Map<String, dynamic> row) {
    final medication = row['medications'] as Map<String, dynamic>?;
    return {
      'id': row['id'],
      'medication_id': row['medication_id'],
      'schedule_id': row['schedule_id'],
      'patient_id': row['patient_id'],
      'medication_name': medication?['name'] ?? row['medication_name'] ?? 'دواء',
      'dose_amount': row['dose_amount'] ?? '1',
      'scheduled_at': DateTime.parse(row['scheduled_at'] as String).toLocal().toIso8601String(),
      'status': row['status'],
      'updated_at': DateTime.parse(row['updated_at'] as String).toLocal().toIso8601String(),
    };
  }
}
