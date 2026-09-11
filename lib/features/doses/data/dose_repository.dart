import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../models/dose_instance.dart';
import '../../../models/medication.dart';
import '../../../models/medication_schedule.dart';
import '../../medications/data/medication_repository.dart';
import '../../medications/data/stock_alert_service.dart';
import '../domain/dose_engine.dart';
import '../domain/dose_lifecycle.dart';

/// Offline-first data access for dose instances.
class DoseRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalDatabase _local = LocalDatabase.instance;
  final MedicationRepository _medicationRepo = MedicationRepository();
  final Uuid _uuid = const Uuid();

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
    // Same-state replay is a safe no-op. This prevents duplicate lifecycle
    // events and repeated stock side effects during notification/offline replay.
    if (dose.status == newStatus) {
      await _local.upsertDose(dose.toLocalRow());
      return dose;
    }

    if (!DoseLifecycle.canTransition(dose.status, newStatus)) {
      throw StateError(
        'Invalid dose lifecycle transition: '
        '${doseStatusToDb(dose.status)} -> ${doseStatusToDb(newStatus)}',
      );
    }

    final updated = dose.copyWith(status: newStatus, updatedAt: DateTime.now());
    await _local.upsertDose(updated.toLocalRow());

    if (ConnectivityService.instance.isOnline) {
      try {
        final allowedFrom = DoseLifecycle.allowedPredecessors(newStatus)
            .map(doseStatusToDb)
            .toList();

        final rows = await _client
            .from('dose_instances')
            .update({
              'status': doseStatusToDb(newStatus),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', dose.id)
            .inFilter('status', allowedFrom)
            .select('id,status');

        // A zero-row update means another actor won the race. Never overwrite
        // that newer server state and never enqueue a stale transition.
        if (rows.isEmpty) {
          await _local.upsertDose(dose.toLocalRow());
          throw StateError('Dose lifecycle conflict for ${dose.id}');
        }

        await _client.from('dose_events').insert({
          'dose_id': dose.id,
          'patient_id': dose.patientId,
          'action': doseStatusToDb(newStatus),
          'source': source,
        });

        try {
          final medication = await _client
              .from('medications')
              .select()
              .eq('id', dose.medicationId)
              .maybeSingle();
          if (medication != null) {
            await StockAlertService.instance.checkMedication(
              Medication.fromMap(medication),
            );
          }
        } catch (_) {
          // Alert delivery must never affect successful dose persistence.
        }

        return updated;
      } on StateError {
        rethrow;
      } catch (_) {
        // Network blip after the connectivity check — keep the optimistic
        // local state and queue the exact lifecycle transition for replay.
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
