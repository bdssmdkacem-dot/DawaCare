import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/database/local_database.dart';
import '../../core/network/connectivity_service.dart';

/// Replays queued offline writes against Supabase once connectivity returns.
///
/// Today this only handles `DOSE_STATUS` operations (confirm/snooze/skip
/// made while offline) — the queue's `entity_type` column exists so future
/// offline-writable features (e.g. editing a medication while offline) can
/// plug into the same replay loop without a schema change.
class SyncEngine {
  SyncEngine._();
  static final SyncEngine instance = SyncEngine._();

  final SupabaseClient _client = Supabase.instance.client;
  final LocalDatabase _local = LocalDatabase.instance;

  StreamSubscription<bool>? _connectivitySub;
  bool _flushing = false;

  void start() {
    ConnectivityService.instance.start();
    _connectivitySub ??= ConnectivityService.instance.onOnlineChanged.listen((online) {
      if (online) flushQueue();
    });
    // Also try once at startup in case we launched already online.
    flushQueue();
  }

  Future<void> flushQueue() async {
    if (_flushing) return;
    if (!await ConnectivityService.instance.checkNow()) return;
    _flushing = true;

    try {
      final pending = await _local.pendingSyncOperations();
      for (final op in pending) {
        final ok = await _replay(op);
        if (ok) {
          await _local.markSynced(op['id'] as String);
        } else {
          await _local.incrementRetry(op['id'] as String);
        }
      }
    } finally {
      _flushing = false;
    }
  }

  Future<bool> _replay(Map<String, dynamic> op) async {
    final payload = jsonDecode(op['payload'] as String) as Map<String, dynamic>;
    try {
      switch (op['entity_type']) {
        case 'DOSE_STATUS':
          await _client
              .from('dose_instances')
              .update({'status': payload['status'], 'updated_at': DateTime.now().toUtc().toIso8601String()})
              .eq('id', payload['dose_id']);
          await _client.from('dose_events').insert({
            'dose_id': payload['dose_id'],
            'patient_id': payload['patient_id'],
            'action': payload['status'],
            'source': payload['source'] ?? 'PATIENT',
          });
          return true;
        default:
          return true; // unknown op type: drop rather than block the queue forever
      }
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
