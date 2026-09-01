enum DoseStatus { pending, reminderSent, snoozed, taken, missed, skipped, cancelled }

DoseStatus doseStatusFromDb(String value) {
  switch (value) {
    case 'REMINDER_SENT':
      return DoseStatus.reminderSent;
    case 'SNOOZED':
      return DoseStatus.snoozed;
    case 'TAKEN':
      return DoseStatus.taken;
    case 'MISSED':
      return DoseStatus.missed;
    case 'SKIPPED':
      return DoseStatus.skipped;
    case 'CANCELLED':
      return DoseStatus.cancelled;
    default:
      return DoseStatus.pending;
  }
}

String doseStatusToDb(DoseStatus status) {
  switch (status) {
    case DoseStatus.reminderSent:
      return 'REMINDER_SENT';
    case DoseStatus.snoozed:
      return 'SNOOZED';
    case DoseStatus.taken:
      return 'TAKEN';
    case DoseStatus.missed:
      return 'MISSED';
    case DoseStatus.skipped:
      return 'SKIPPED';
    case DoseStatus.cancelled:
      return 'CANCELLED';
    case DoseStatus.pending:
      return 'PENDING';
  }
}

bool isResolvedStatus(DoseStatus status) =>
    status == DoseStatus.taken || status == DoseStatus.skipped || status == DoseStatus.cancelled;

/// A single occurrence of a medication schedule — this is what the patient
/// sees as one card on the Today screen, and what caregivers see in reports.
///
/// [medicationName] and [doseAmount] are denormalized onto the row (both in
/// Postgres and in the local sqlite cache) so the Today screen can render
/// fully offline without needing a join back to `medications`.
class DoseInstance {
  final String id;
  final String medicationId;
  final String scheduleId;
  final String patientId;
  final String medicationName;
  final String doseAmount;
  final DateTime scheduledAt;
  final DoseStatus status;
  final DateTime updatedAt;

  const DoseInstance({
    required this.id,
    required this.medicationId,
    required this.scheduleId,
    required this.patientId,
    required this.medicationName,
    required this.doseAmount,
    required this.scheduledAt,
    required this.status,
    required this.updatedAt,
  });

  factory DoseInstance.fromMap(Map<String, dynamic> map) {
    // When fetched with a join: dose_instances(*, medications(name))
    final medication = map['medications'] as Map<String, dynamic>?;
    return DoseInstance(
      id: map['id'] as String,
      medicationId: map['medication_id'] as String,
      scheduleId: map['schedule_id'] as String,
      patientId: map['patient_id'] as String,
      medicationName: (medication?['name'] as String?) ?? (map['medication_name'] as String? ?? 'دواء'),
      doseAmount: map['dose_amount'] as String? ?? '1',
      scheduledAt: DateTime.parse(map['scheduled_at'] as String).toLocal(),
      status: doseStatusFromDb(map['status'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }

  factory DoseInstance.fromLocalRow(Map<String, dynamic> row) {
    return DoseInstance(
      id: row['id'] as String,
      medicationId: row['medication_id'] as String,
      scheduleId: row['schedule_id'] as String,
      patientId: row['patient_id'] as String,
      medicationName: row['medication_name'] as String,
      doseAmount: row['dose_amount'] as String,
      scheduledAt: DateTime.parse(row['scheduled_at'] as String),
      status: doseStatusFromDb(row['status'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Map<String, dynamic> toLocalRow() => {
        'id': id,
        'medication_id': medicationId,
        'schedule_id': scheduleId,
        'patient_id': patientId,
        'medication_name': medicationName,
        'dose_amount': doseAmount,
        'scheduled_at': scheduledAt.toIso8601String(),
        'status': doseStatusToDb(status),
        'updated_at': updatedAt.toIso8601String(),
      };

  DoseInstance copyWith({DoseStatus? status, DateTime? updatedAt}) {
    return DoseInstance(
      id: id,
      medicationId: medicationId,
      scheduleId: scheduleId,
      patientId: patientId,
      medicationName: medicationName,
      doseAmount: doseAmount,
      scheduledAt: scheduledAt,
      status: status ?? this.status,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
