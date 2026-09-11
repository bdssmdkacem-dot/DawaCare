import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/local_database.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../models/dose_instance.dart';
import '../../../models/medication.dart';
import '../../../models/medication_schedule.dart';
import '../../medications/data/medication_repository.dart';
import '../../medications/data/stock_alert_service.dart';
import '../domain/dose_engine.dart';
import '../domain/dose_lifecycle.dart';
import '../../sync/domain/sync_queue_rules.dart';

/// Offline-first data access for dose instances.
class DoseRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalDatabase _local = LocalDatabase.instance;
  final MedicationRepository _medicationRepo = MedicationRepository();

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

    final cutoff = DateTime.now().toUtc().subtract(gracePeriod);
    final rows = await _client
        .from('dose_instances')
        .select('id, patient_id, status')
        .eq('patient_id', patientId)
        .inFilter('status', const ['PENDING', 'REMINDER_SENT', 'SNOOZED'])
        .lt('scheduled_at', cutoff.toIso8601String());

    for (final row in rows) {
      final doseId = row['id'] as String?;
      if (doseId == null) continue;

      try {
        await _client.rpc(
          'apply_dose_status_transition',
          params: {
            'p_dose_id': doseId,
            'p_patient_id': patientId,
            'p_to_status': 'MISSED',
            'p_source': 'SYSTEM',
          },
        );
      } catch (_) {
        // A transient failure is retried by the next reconciliation pass.
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
        final rows = await _client.rpc(
          'apply_dose_status_transition',
          params: {
            'p_dose_id': dose.id,
            'p_patient_id': dose.patientId,
            'p_to_status': doseStatusToDb(newStatus),
            'p_source': source,
          },
        ) as List<dynamic>;

        if (rows.isEmpty) {
          await _local.upsertDose(dose.toLocalRow());
          throw StateError('Dose lifecycle conflict for ${dose.id}');
        }

        final result = Map<String, dynamic>.from(rows.first as Map);
        final applied = result['applied'] == true;
        final currentStatus = result['current_status'] as String?;

        if (!applied && currentStatus != doseStatusToDb(newStatus)) {
          await _local.upsertDose(dose.toLocalRow());
          throw StateError(
            'Dose lifecycle conflict for ${dose.id}: '
            '${currentStatus ?? 'UNKNOWN'} -> ${doseStatusToDb(newStatus)}',
          );
        }

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
      id: SyncQueueRules.doseStatusOperationId(
        doseId: dose.id,
        status: doseStatusToDb(newStatus),
      ),
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
