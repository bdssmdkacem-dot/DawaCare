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
class DoseRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalDatabase _local = LocalDatabase.instance;
  final MedicationRepository _medicationRepo = MedicationRepository();
  final Uuid _uuid = const Uuid();

  /// Generates (idempotently) dose rows for active medication schedules.
  /// Safe to call repeatedly because the database enforces
  /// `unique(schedule_id, scheduled_at)`.
  Future<void> ensureDosesGenerated(String patientId, {int daysAhead = 14}) async {
    if (!ConnectivityService.instance.isOnline) return;

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

  /// Marks unresolved doses as MISSED once their scheduled time has passed.
  ///
  /// A five-minute grace period prevents a dose from becoming missed while
  /// the notification is still actionable. Resolved doses are never changed.
  Future<void> reconcileMissedDoses(
    String patientId, {
    Duration gracePeriod = const Duration(minutes: 5),
  }) async {
    if (!ConnectivityService.instance.isOnline) return;

    final cutoff = DateTime.now().toUtc().subtract(gracePeriod).toIso8601String();
    await _client
        .from('dose_instances')
        .update({
          'status': 'MISSED',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('patient_id', patientId)
        .inFilter('status', const ['PENDING', 'REMINDER_SENT', 'SNOOZED'])
        .lt('scheduled_at', cutoff);
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

  Future<void> clearFutureUnresolvedDosesByMedication(String medicationId, DateTime from) async {
    final fromUtc = from.toUtc().toIso8601String();
    for (final status in const ['PENDING', 'REMINDER_SENT', 'SNOOZED', 'MISSED']) {
      await _client
          .from('dose_instances')
          .delete()
          .eq('medication_id', medicationId)
          .eq('status', status)
          .gte('scheduled_at', fromUtc);
    }
    await _local.deleteFutureUnresolvedDosesByMedication(medicationId, from);
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
        // network blip after the connectivity check — queue the write
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
