import 'package:flutter_test/flutter_test.dart';
import 'package:dawacare/features/doses/domain/adherence_report.dart';
import 'package:dawacare/models/dose_instance.dart';

DoseInstance dose({
  required String id,
  required String medicationId,
  required String medicationName,
  required DateTime scheduledAt,
  required DoseStatus status,
}) {
  return DoseInstance(
    id: id,
    medicationId: medicationId,
    scheduleId: 'schedule-$id',
    patientId: 'patient-1',
    medicationName: medicationName,
    doseAmount: '1',
    scheduledAt: scheduledAt,
    status: status,
    updatedAt: scheduledAt,
  );
}

void main() {
  test('weekly report always contains seven local calendar days', () {
    final start = DateTime(2026, 9, 7, 18);
    final report = AdherenceReportEngine.weekly(
      [
        dose(
          id: '1',
          medicationId: 'm1',
          medicationName: 'A',
          scheduledAt: DateTime(2026, 9, 7, 8),
          status: DoseStatus.taken,
        ),
      ],
      weekStart: start,
    );

    expect(report.start, DateTime(2026, 9, 7));
    expect(report.days, hasLength(7));
    expect(report.days.first.summary.taken, 1);
    expect(report.taken, 1);
    expect(report.missed, 0);
    expect(report.percentage, 100);
  });

  test('weekly aggregation counts resolved outcomes without double counting', () {
    final start = DateTime(2026, 9, 7);
    final report = AdherenceReportEngine.weekly(
      [
        dose(id: '1', medicationId: 'm1', medicationName: 'A', scheduledAt: DateTime(2026, 9, 7, 8), status: DoseStatus.taken),
        dose(id: '2', medicationId: 'm1', medicationName: 'A', scheduledAt: DateTime(2026, 9, 8, 8), status: DoseStatus.missed),
        dose(id: '3', medicationId: 'm1', medicationName: 'A', scheduledAt: DateTime(2026, 9, 9, 8), status: DoseStatus.pending),
        dose(id: '4', medicationId: 'm1', medicationName: 'A', scheduledAt: DateTime(2026, 9, 10, 8), status: DoseStatus.skipped),
        dose(id: '5', medicationId: 'm1', medicationName: 'A', scheduledAt: DateTime(2026, 9, 11, 8), status: DoseStatus.cancelled),
      ],
      weekStart: start,
    );

    expect(report.taken, 1);
    expect(report.missed, 1);
    expect(report.pending, 1);
    expect(report.excluded, 2);
    expect(report.resolved, 2);
    expect(report.percentage, 50);
  });

  test('medication report groups by medication and excludes out-of-range doses', () {
    final report = AdherenceReportEngine.byMedication(
      [
        dose(id: '1', medicationId: 'm1', medicationName: 'Beta', scheduledAt: DateTime(2026, 9, 7, 8), status: DoseStatus.taken),
        dose(id: '2', medicationId: 'm1', medicationName: 'Beta', scheduledAt: DateTime(2026, 9, 8, 8), status: DoseStatus.missed),
        dose(id: '3', medicationId: 'm2', medicationName: 'Alpha', scheduledAt: DateTime(2026, 9, 7, 8), status: DoseStatus.taken),
        dose(id: '4', medicationId: 'm2', medicationName: 'Alpha', scheduledAt: DateTime(2026, 9, 14, 8), status: DoseStatus.missed),
      ],
      from: DateTime(2026, 9, 7),
      to: DateTime(2026, 9, 14),
    );

    expect(report.map((r) => r.medicationId), ['m2', 'm1']);
    expect(report.first.summary.taken, 1);
    expect(report.first.percentage, 100);
    expect(report.last.summary.taken, 1);
    expect(report.last.summary.missed, 1);
    expect(report.last.percentage, 50);
  });

  test('PRN, pending and excluded statuses follow adherence contract', () {
    final report = AdherenceReportEngine.byMedication(
      [
        dose(id: '1', medicationId: 'm1', medicationName: 'A', scheduledAt: DateTime(2026, 9, 7, 8), status: DoseStatus.taken),
        dose(id: '2', medicationId: 'm1', medicationName: 'A', scheduledAt: DateTime(2026, 9, 7, 9), status: DoseStatus.snoozed),
        dose(id: '3', medicationId: 'm1', medicationName: 'A', scheduledAt: DateTime(2026, 9, 7, 10), status: DoseStatus.skipped),
        dose(id: '4', medicationId: 'm1', medicationName: 'A', scheduledAt: DateTime(2026, 9, 7, 11), status: DoseStatus.cancelled),
      ],
      from: DateTime(2026, 9, 7),
      to: DateTime(2026, 9, 8),
    ).single;

    expect(report.summary.taken, 1);
    expect(report.summary.pending, 1);
    expect(report.summary.excluded, 2);
    expect(report.summary.missed, 0);
    expect(report.percentage, 100);
  });
}
