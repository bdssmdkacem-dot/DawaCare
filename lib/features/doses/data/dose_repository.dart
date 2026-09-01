import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../models/dose_instance.dart';
import '../../../models/medication_schedule.dart';
import '../../medications/data/medication_repository.dart';
import '../domain/dose_engine.dart';

/// Offline-first data access for dose instances.
///
/// Reads try Supabase first and always refresh the local cache; if the
/// network call fails (or the device is offline), it falls back to the
/// local sqlite cache so the Today screen never shows a blank error state.
///
/// Writes (confirm / snooze / skip) update the local cache immediately
/// (optimistic UI), then either write straight to Supabase when online, or
/// drop into [LocalDatabase]'s `sync_queue` for [SyncEngine] to replay later.
class DoseRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalDatabase _local = LocalDatabase.instance;
  final MedicationRepository _medicationRepo = MedicationRepository();
  final Uuid _uuid = const Uuid();

  /// Generates (idempotently) `dose_instances` rows for every active
  /// medication schedule of [patientId], covering `[today, today+daysAhead]`.
  /// Safe to call often — the `unique(schedule_id, scheduled_at)` DB
  /// constraint makes overlapping calls a no-op.
  Future<void> ensureDosesGenerated(String patientId, {int daysAhead = 14}) async {
    if (!ConnectivityService.instance.isOnline) return; // needs the DB round-trip

    final medications = await _medicationRepo.fetchMedications(patientId);
    final now = DateTime.now();
    final windowStart = DateTime(now.year, now.month, now.day);
    final windowEnd = windowStart.add(Duration(days: daysAhead));

    for (final medication in medications) {
      final schedules = await _medicationRepo.fetchSchedules(medication.id);
      for (final schedule in schedules) {
        if (schedule.type == ScheduleType.prn) continue;
        final occurrences = DoseEngine.computeOccurrences(
          schedule: schedule,
          windowStart: windowStart,
          windowEnd: windowEnd,
        );
        if (occurrences.isEmpty) continue;

        final rows = occurrences
            .map((dt) => {
                  'medication_id': medication.id,
                  'schedule_id': schedule.id,
                  'patient_id': patientId,
                  'scheduled_at': dt.toUtc().toIso8601String(),
                  'dose_amount': schedule.doseAmount,
                  'status': 'PENDING',
                })
            .toList();

        await _client.from('dose_instances').upsert(
              rows,
              onConflict: 'schedule_id,scheduled_at',
              ignoreDuplicates: true,
            );
      }
    }
  }

  Future<List<DoseInstance>> fetchDosesForRange(
    String patientId, {
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows = await _client
          .from('dose_instances')
          .select('*, medications(name)')
          .eq('patient_id', patientId)
          .gte('scheduled_at', from.toUtc().toIso8601String())
          .lte('scheduled_at', to.toUtc().toIso8601String())
          .order('scheduled_at');

      final doses = rows.map((r) => DoseInstance.fromMap(r)).toList();
      await _local.upsertDoses(doses.map((d) => d.toLocalRow()).toList());
      return doses;
    } catch (_) {
      final localRows = await _local.dosesForPatient(patientId, from: from, to: to);
      return localRows.map((r) => DoseInstance.fromLocalRow(r)).toList();
    }
  }

  Future<DoseInstance> updateStatus(
    DoseInstance dose,
    DoseStatus newStatus, {
    String source = 'PATIENT',
  }) async {
    final updated = dose.copyWith(status: newStatus, updatedAt: DateTime.now());
    await _local.upsertDose(updated.toLocalRow());

    if (ConnectivityService.instance.isOnline) {
      try {
        await _client
            .from('dose_instances')
            .update({
              'status': doseStatusToDb(newStatus),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', dose.id);
        await _client.from('dose_events').insert({
          'dose_id': dose.id,
          'patient_id': dose.patientId,
          'action': doseStatusToDb(newStatus),
          'source': source,
        });
        return updated;
      } catch (_) {
        // network blip after the connectivity check — fall through to queue
      }
    }

    await _local.enqueue(
      id: _uuid.v4(),
      entityType: 'DOSE_STATUS',
      entityId: dose.id,
      operation: 'UPDATE',
      payloadJson: jsonEncode({
        'dose_id': dose.id,
        'patient_id': dose.patientId,
        'status': doseStatusToDb(newStatus),
        'source': source,
      }),
    );
    return updated;
  }
}
