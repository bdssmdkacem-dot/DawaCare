import 'package:dawacare/features/doses/domain/adherence_engine.dart';
import 'package:dawacare/models/dose_instance.dart';
import 'package:flutter_test/flutter_test.dart';

DoseInstance dose({
  required String id,
  required DateTime scheduledAt,
  required DoseStatus status,
}) {
  return DoseInstance(
    id: id,
    medicationId: 'med-1',
    scheduleId: 'schedule-1',
    patientId: 'patient-1',
    medicationName: 'Medicine',
    doseAmount: '1',
    scheduledAt: scheduledAt,
    status: status,
    updatedAt: scheduledAt,
  );
}

void main() {
  final day = DateTime(2026, 9, 11, 12);

  test('counts taken and missed as resolved adherence outcomes', () {
    final summary = AdherenceEngine.compute([
      dose(id: '1', scheduledAt: DateTime(2026, 9, 11, 8), status: DoseStatus.taken),
      dose(id: '2', scheduledAt: DateTime(2026, 9, 11, 14), status: DoseStatus.missed),
    ], day: day);

    expect(summary.taken, 1);
    expect(summary.missed, 1);
    expect(summary.resolved, 2);
    expect(summary.percentage, 50);
  });

  test('pending states do not lower adherence before they resolve', () {
    final summary = AdherenceEngine.compute([
      dose(id: '1', scheduledAt: DateTime(2026, 9, 11, 8), status: DoseStatus.taken),
      dose(id: '2', scheduledAt: DateTime(2026, 9, 11, 12), status: DoseStatus.pending),
      dose(id: '3', scheduledAt: DateTime(2026, 9, 11, 13), status: DoseStatus.reminderSent),
      dose(id: '4', scheduledAt: DateTime(2026, 9, 11, 14), status: DoseStatus.snoozed),
    ], day: day);

    expect(summary.taken, 1);
    expect(summary.missed, 0);
    expect(summary.pending, 3);
    expect(summary.percentage, 100);
  });

  test('skipped and cancelled doses are excluded, not failures', () {
    final summary = AdherenceEngine.compute([
      dose(id: '1', scheduledAt: DateTime(2026, 9, 11, 8), status: DoseStatus.taken),
      dose(id: '2', scheduledAt: DateTime(2026, 9, 11, 9), status: DoseStatus.skipped),
      dose(id: '3', scheduledAt: DateTime(2026, 9, 11, 10), status: DoseStatus.cancelled),
      dose(id: '4', scheduledAt: DateTime(2026, 9, 11, 11), status: DoseStatus.missed),
    ], day: day);

    expect(summary.excluded, 2);
    expect(summary.resolved, 2);
    expect(summary.percentage, 50);
  });

  test('doses outside the local day are ignored', () {
    final summary = AdherenceEngine.compute([
      dose(id: 'before', scheduledAt: DateTime(2026, 9, 10, 23, 59), status: DoseStatus.missed),
      dose(id: 'start', scheduledAt: DateTime(2026, 9, 11), status: DoseStatus.taken),
      dose(id: 'end', scheduledAt: DateTime(2026, 9, 12), status: DoseStatus.missed),
    ], day: day);

    expect(summary.taken, 1);
    expect(summary.missed, 0);
    expect(summary.resolved, 1);
    expect(summary.percentage, 100);
  });

  test('no resolved doses produces zero instead of NaN', () {
    final summary = AdherenceEngine.compute([
      dose(id: '1', scheduledAt: DateTime(2026, 9, 11, 8), status: DoseStatus.pending),
    ], day: day);

    expect(summary.resolved, 0);
    expect(summary.percentage, 0);
  });
}
