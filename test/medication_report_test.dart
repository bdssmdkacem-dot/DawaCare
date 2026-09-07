import 'package:flutter_test/flutter_test.dart';

import '../lib/features/caregiver/domain/medication_report.dart';
import '../lib/models/dose_instance.dart';

DoseInstance _dose(String id, DoseStatus status, {int day = 1}) => DoseInstance(
      id: id,
      medicationId: 'med-1',
      scheduleId: 'schedule-1',
      patientId: 'patient-1',
      medicationName: 'دواء تجريبي',
      doseAmount: '1',
      scheduledAt: DateTime(2026, 9, day, 8),
      status: status,
      updatedAt: DateTime(2026, 9, day, 8),
    );

void main() {
  test('calculates overall adherence and status counts', () {
    final report = AdherenceReport.fromDoses(
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 7),
      [
        _dose('1', DoseStatus.taken),
        _dose('2', DoseStatus.taken),
        _dose('3', DoseStatus.missed),
        _dose('4', DoseStatus.skipped),
        _dose('5', DoseStatus.pending),
      ],
    );

    expect(report.scheduled, 5);
    expect(report.taken, 2);
    expect(report.missed, 1);
    expect(report.skipped, 1);
    expect(report.pending, 1);
    expect(report.adherence, 0.5);
    expect(report.medications.single.adherence, 0.5);
  });

  test('groups taken doses by local calendar day', () {
    final report = AdherenceReport.fromDoses(
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 7),
      [
        _dose('1', DoseStatus.taken, day: 1),
        _dose('2', DoseStatus.taken, day: 1),
        _dose('3', DoseStatus.taken, day: 3),
      ],
    );

    expect(report.takenByDay[DateTime(2026, 9, 1)], 2);
    expect(report.takenByDay[DateTime(2026, 9, 3)], 1);
  });

  test('does not penalize unresolved doses in adherence', () {
    final report = AdherenceReport.fromDoses(
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 1),
      [_dose('1', DoseStatus.pending)],
    );

    expect(report.resolved, 0);
    expect(report.adherence, 0);
  });
}
