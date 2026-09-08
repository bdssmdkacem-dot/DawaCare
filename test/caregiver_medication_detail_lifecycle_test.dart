import 'dart:async';

import 'package:dawacare/core/localization/app_localizations.dart';
import 'package:dawacare/features/caregiver/presentation/pages/caregiver_medication_detail_page.dart';
import 'package:dawacare/features/medications/presentation/providers/medication_provider.dart';
import 'package:dawacare/models/medication.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Medication _medication() => Medication(
      id: 'medication-lifecycle-test',
      patientId: 'patient-test',
      name: 'دواء الاختبار',
      genericName: 'Test medication',
      strength: '10 mg',
      dosageForm: 'قرص',
      instructions: 'اختبار دورة حياة الشاشة',
      imageUrl: null,
      startDate: DateTime(2026, 1, 1),
      endDate: null,
      active: true,
      createdBy: 'caregiver-test',
      createdAt: DateTime(2026, 1, 1),
    );

class _BlockingMedicationProvider extends MedicationProvider {
  final Completer<void> _loadCompleter = Completer<void>();

  @override
  Future<void> load(String forPatientId) => _loadCompleter.future;
}

Widget _app({required Widget home}) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: home,
  );
}

Widget _page() => _app(
      home: ChangeNotifierProvider<MedicationProvider>(
        create: (_) => _BlockingMedicationProvider(),
        child: CaregiverMedicationDetailPage(
          medication: _medication(),
          patientName: 'مريض الاختبار',
          canManageDoses: false,
        ),
      ),
    );

Widget _host() => _app(
      home: const Scaffold(
        body: Center(child: Text('Lifecycle host')),
      ),
    );

Future<void> _openAndRapidlyClose(WidgetTester tester) async {
  await tester.pumpWidget(_page());
  await tester.pump();
  expect(find.byType(CaregiverMedicationDetailPage), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  await tester.pump(const Duration(milliseconds: 1));
  await tester.pumpWidget(_host());
  await tester.pump();
  expect(find.byType(CaregiverMedicationDetailPage), findsNothing);

  await tester.pump(const Duration(milliseconds: 50));
  expect(find.byType(CaregiverMedicationDetailPage), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  testWidgets(
    'CaregiverMedicationDetailPage survives rapid replacement while loading',
    (tester) async {
      for (var i = 0; i < 5; i++) {
        await _openAndRapidlyClose(tester);
      }
    },
  );

  testWidgets(
    'CaregiverMedicationDetailPage can be re-entered after disposal',
    (tester) async {
      await _openAndRapidlyClose(tester);

      await tester.pumpWidget(_page());
      await tester.pump();
      expect(find.byType(CaregiverMedicationDetailPage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpWidget(_host());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CaregiverMedicationDetailPage), findsNothing);
    },
  );
}
