import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dawacare/core/config/supabase_config.dart';
import 'package:dawacare/features/caregiver/presentation/pages/medication_reports_page.dart';
import 'package:dawacare/features/caregiver/presentation/providers/medication_report_provider.dart';

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance;
  } catch (_) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }
}

void main() {
  setUpAll(_ensureSupabaseInitialized);

  testWidgets('renders caregiver reports shell and period selector',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('ar')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
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
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('period selector remains available during initial load',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('ar')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
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
  });
}
