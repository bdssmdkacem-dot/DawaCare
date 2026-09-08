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

/// Keeps the real page in its loading state without touching Supabase.
/// This mirrors PatientDetailPage, which creates the notifier and exposes it
/// to the pushed medication route with ChangeNotifierProvider.value.
class _BlockingMedicationProvider extends MedicationProvider {
  final Completer<void> _loadCompleter = Completer<void>();

  @override
  Future<void> load(String forPatientId) => _loadCompleter.future;
}

Widget _app({
  required MedicationProvider provider,
  required GlobalKey<NavigatorState> navigatorKey,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider<MedicationProvider>.value(
                value: provider,
                child: CaregiverMedicationDetailPage(
                  medication: _medication(),
                  patientName: 'مريض الاختبار',
                  canManageDoses: false,
                ),
              ),
            ),
          ),
          child: const Text('Open medication'),
        ),
      ),
    ),
  );
}

Future<void> _openAndPop(WidgetTester tester) async {
  final provider = _BlockingMedicationProvider();
  final navigatorKey = GlobalKey<NavigatorState>();

  await tester.pumpWidget(
    _app(provider: provider, navigatorKey: navigatorKey),
  );
  await tester.pump();

  await tester.tap(find.text('Open medication'));
  await tester.pump();
  await tester.pump();

  expect(find.byType(CaregiverMedicationDetailPage), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // The detail page is a real Navigator route. Pop the route while its
  // provider load remains pending instead of replacing the whole app tree.
  navigatorKey.currentState!.pop();
  await tester.pump();
  expect(find.byType(CaregiverMedicationDetailPage), findsNothing);

  // Give route teardown and inherited-dependency removal a full frame.
  await tester.pump(const Duration(milliseconds: 50));
  expect(find.byType(CaregiverMedicationDetailPage), findsNothing);

  provider.dispose();
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
    'CaregiverMedicationDetailPage survives rapid route replacement while loading',
    (tester) async {
      for (var i = 0; i < 5; i++) {
        await _openAndPop(tester);
      }
    },
  );

  testWidgets(
    'CaregiverMedicationDetailPage can be re-entered after route disposal',
    (tester) async {
      await _openAndPop(tester);
      await _openAndPop(tester);
    },
  );
}
