import 'package:dawacare/core/localization/app_localizations.dart';
import 'package:dawacare/features/caregiver/presentation/pages/patient_detail_page.dart';
import 'package:dawacare/models/caregiver_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

CaregiverLink _link() => CaregiverLink(
      id: 'link-test',
      caregiverId: 'caregiver-test',
      patientId: 'patient-test',
      patientName: 'مريض الاختبار',
      patientAvatarUrl: null,
      role: CaregiverRole.caregiver,
      relationshipLabel: 'قريب',
      createdAt: DateTime(2026, 1, 1),
    );

Widget _app() {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PatientDetailPage(link: _link()),
              ),
            ),
            child: const Text('فتح المريض'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'PatientDetailPage survives rapid push/pop while async loading is in flight',
    (tester) async {
      await tester.pumpWidget(_app());

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('فتح المريض'));
        await tester.pump();

        // Let initState's post-frame callback start the real provider loads,
        // then immediately tear the route down while those futures may still
        // be completing. A framework lifecycle assertion here reproduces the
        // class of red screen that previously occurred on this page.
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.byType(PatientDetailPage), findsOneWidget);

        Navigator.of(tester.element(find.byType(PatientDetailPage))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
      }

      // Flush deferred notifier disposal callbacks and any provider futures.
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('فتح المريض'), findsOneWidget);
      expect(find.byType(PatientDetailPage), findsNothing);
    },
  );

  testWidgets(
    'PatientDetailPage can be re-entered immediately after disposal',
    (tester) async {
      await tester.pumpWidget(_app());

      await tester.tap(find.text('فتح المريض'));
      await tester.pump();
      expect(find.byType(PatientDetailPage), findsOneWidget);

      Navigator.of(tester.element(find.byType(PatientDetailPage))).pop();
      await tester.pump();

      await tester.tap(find.text('فتح المريض'));
      await tester.pump();
      expect(find.byType(PatientDetailPage), findsOneWidget);

      Navigator.of(tester.element(find.byType(PatientDetailPage))).pop();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(PatientDetailPage), findsNothing);
    },
  );
}
