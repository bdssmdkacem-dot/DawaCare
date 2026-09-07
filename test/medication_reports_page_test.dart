import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dawacare/features/caregiver/presentation/pages/medication_reports_page.dart';

void main() {
  testWidgets('renders caregiver reports shell and period selector',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MedicationReportsPage(
          patientId: 'patient-test',
          patientName: 'محمد',
        ),
      ),
    );

    expect(find.text('تقارير الالتزام'), findsOneWidget);
    expect(find.text('اليوم'), findsOneWidget);
    expect(find.text('هذا الأسبوع'), findsOneWidget);
    expect(find.text('هذا الشهر'), findsOneWidget);
    expect(find.byType(SegmentedButton<ReportPeriod>), findsOneWidget);
    expect(find.text('محمد'), findsNothing);

    // The first frame is intentionally checked before the asynchronous
    // repository load completes. This protects the caregiver report shell
    // from regressions without requiring a live Supabase backend.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('period selector remains available during initial load',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MedicationReportsPage(
          patientId: 'patient-test',
          patientName: 'Test Patient',
        ),
      ),
    );

    final selector = find.byType(SegmentedButton<ReportPeriod>);
    expect(selector, findsOneWidget);
    expect(tester.widget<SegmentedButton<ReportPeriod>>(selector).segments,
        hasLength(3));

    final semantics = tester.getSemantics(selector);
    expect(semantics, isNotNull);
  });
}
