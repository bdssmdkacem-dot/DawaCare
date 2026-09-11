import 'package:dawacare/features/caregiver/presentation/providers/caregiver_provider.dart';
import 'package:dawacare/features/caregiver/presentation/widgets/caregiver_daily_dashboard.dart';
import 'package:dawacare/features/doses/domain/adherence_engine.dart';
import 'package:dawacare/models/caregiver_link.dart';
import 'package:dawacare/models/dose_instance.dart';
import 'package:dawacare/models/family_member_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

DoseInstance _dose({
  required DoseStatus status,
  required DateTime scheduledAt,
  required String id,
}) {
  return DoseInstance(
    id: id,
    medicationId: 'med-1',
    scheduleId: 'schedule-1',
    patientId: 'patient-1',
    medicationName: 'دواء الاختبار',
    doseAmount: 'قرص واحد',
    scheduledAt: scheduledAt,
    status: status,
    updatedAt: scheduledAt,
  );
}

void main() {
  final day = DateTime(2026, 9, 11, 12);
  final start = DateTime(2026, 9, 11, 8);

  test('Today adherence uses resolved doses only', () {
    final doses = [
      _dose(status: DoseStatus.taken, scheduledAt: start, id: '1'),
      _dose(status: DoseStatus.taken, scheduledAt: start.add(const Duration(hours: 1)), id: '2'),
      _dose(status: DoseStatus.missed, scheduledAt: start.add(const Duration(hours: 2)), id: '3'),
      _dose(status: DoseStatus.pending, scheduledAt: start.add(const Duration(hours: 3)), id: '4'),
      _dose(status: DoseStatus.snoozed, scheduledAt: start.add(const Duration(hours: 4)), id: '5'),
      _dose(status: DoseStatus.skipped, scheduledAt: start.add(const Duration(hours: 5)), id: '6'),
      _dose(status: DoseStatus.cancelled, scheduledAt: start.add(const Duration(hours: 6)), id: '7'),
    ];

    final summary = AdherenceEngine.compute(doses, day: day);

    expect(summary.taken, 2);
    expect(summary.missed, 1);
    expect(summary.pending, 2);
    expect(summary.excluded, 2);
    expect(summary.percentage, closeTo(66.6667, 0.001));
  });

  testWidgets('Caregiver dashboard renders the same adherence semantics', (tester) async {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );

    final provider = CaregiverProvider();
    provider.linkedPatients = [
      CaregiverLink(
        id: 'link-1',
        caregiverId: 'caregiver-1',
        patientId: 'patient-1',
        patientName: 'مريض الاختبار',
        role: CaregiverRole.caregiver,
        relationshipLabel: 'family',
        createdAt: day,
      ),
    ];
    provider.memberSummaries['patient-1'] = const FamilyMemberSummary(
      activeMedicationCount: 2,
      todayDoseCount: 7,
      takenDoseCount: 2,
      missedDoseCount: 1,
      pendingDoseCount: 2,
      excludedDoseCount: 2,
      nextDoseAt: null,
      lowStockMedicationCount: 0,
      outOfStockMedicationCount: 0,
      lastActivityAt: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaregiverDailyDashboard(provider: provider),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('67%'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('1'), findsOneWidget);
  });
}
