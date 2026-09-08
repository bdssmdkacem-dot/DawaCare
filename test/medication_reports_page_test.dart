import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dawacare/features/caregiver/presentation/pages/medication_reports_page.dart';
import 'package:dawacare/features/caregiver/presentation/providers/medication_report_provider.dart';

void main() {
  testWidgets('renders caregiver reports shell and period selector',
      (tester) async {
    final provider = MedicationReportProvider.testLoading();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MedicationReportsPage(
          patientId: 'patient-test',
          patientName: 'محمد',
          provider: provider,
        ),
      ),
    );

    expect(find.text('تقارير الالتزام'), findsOneWidget);
    expect(find.text('اليوم'), findsOneWidget);
    expect(find.text('هذا الأسبوع'), findsOneWidget);
    expect(find.text('هذا الشهر'), findsOneWidget);
    expect(find.byType(SegmentedButton<ReportPeriod>), findsOneWidget);
    expect(find.text('محمد'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    provider.dispose();
  });

  testWidgets('period selector remains available during initial load',
      (tester) async {
    final provider = MedicationReportProvider.testLoading();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MedicationReportsPage(
          patientId: 'patient-test',
          patientName: 'Test Patient',
          provider: provider,
        ),
      ),
    );

    final selector = find.byType(SegmentedButton<ReportPeriod>);
    expect(selector, findsOneWidget);
    expect(tester.widget<SegmentedButton<ReportPeriod>>(selector).segments,
        hasLength(3));

    provider.dispose();
  });
}
