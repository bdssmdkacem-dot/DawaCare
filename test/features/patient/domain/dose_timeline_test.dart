import 'package:dawacare/features/patient/domain/dose_timeline.dart';
import 'package:dawacare/models/dose_instance.dart';
import 'package:flutter_test/flutter_test.dart';

DoseInstance dose({
  required String id,
  required DateTime at,
  DoseStatus status = DoseStatus.pending,
}) {
  return DoseInstance(
    id: id,
    patientId: 'patient',
    medicationId: 'medication',
    scheduleId: 'schedule-$id',
    medicationName: 'دواء',
    doseAmount: '1',
    scheduledAt: at,
    status: status,
    updatedAt: at,
  );
}

void main() {
  final now = DateTime(2026, 9, 10, 10);

  test('nextDose returns the earliest actionable future dose', () {
    final result = DoseTimeline.nextDose([
      dose(id: 'late', at: now.add(const Duration(hours: 4))),
      dose(id: 'taken', at: now.add(const Duration(hours: 1)), status: DoseStatus.taken),
      dose(id: 'early', at: now.add(const Duration(hours: 2))),
    ], now: now);

    expect(result?.id, 'early');
  });

  test('nextDose keeps an actionable overdue dose visible', () {
    final result = DoseTimeline.nextDose([
      dose(id: 'overdue', at: now.subtract(const Duration(minutes: 3)), status: DoseStatus.snoozed),
      dose(id: 'taken', at: now.subtract(const Duration(hours: 1)), status: DoseStatus.taken),
    ], now: now);

    expect(result?.id, 'overdue');
  });

  test('nextDose ignores missed, skipped and taken doses', () {
    final result = DoseTimeline.nextDose([
      dose(id: 'missed', at: now.add(const Duration(hours: 1)), status: DoseStatus.missed),
      dose(id: 'skipped', at: now.add(const Duration(hours: 2)), status: DoseStatus.skipped),
      dose(id: 'taken', at: now.add(const Duration(hours: 3)), status: DoseStatus.taken),
    ], now: now);

    expect(result, isNull);
  });

  test('remainingCount counts only actionable doses', () {
    final doses = [
      dose(id: 'a', at: now),
      dose(id: 'b', at: now.add(const Duration(hours: 1)), status: DoseStatus.reminderSent),
      dose(id: 'c', at: now.add(const Duration(hours: 2)), status: DoseStatus.snoozed),
      dose(id: 'd', at: now.add(const Duration(hours: 3)), status: DoseStatus.taken),
      dose(id: 'e', at: now.add(const Duration(hours: 4)), status: DoseStatus.missed),
    ];

    expect(DoseTimeline.remainingCount(doses), 3);
    expect(DoseTimeline.completedCount(doses), 1);
  });

  test('ordered sorts the timeline chronologically', () {
    final result = DoseTimeline.ordered([
      dose(id: 'c', at: now.add(const Duration(hours: 3))),
      dose(id: 'a', at: now),
      dose(id: 'b', at: now.add(const Duration(hours: 1))),
    ]);

    expect(result.map((dose) => dose.id), ['a', 'b', 'c']);
  });
}
