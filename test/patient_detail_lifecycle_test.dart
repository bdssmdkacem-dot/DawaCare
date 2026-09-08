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

Future<void> _openAndRapidlyClose(WidgetTester tester) async {
  await tester.tap(find.text('فتح المريض'));
  await tester.pump();
  expect(find.byType(PatientDetailPage), findsOneWidget);

  // Allow the page's post-frame callback to start the real provider loads,
  // then pop the route while those asynchronous operations may still be in
  // flight. Do not wait for the providers to finish before disposing the page.
  await tester.pump(const Duration(milliseconds: 1));
  Navigator.of(tester.element(find.byType(PatientDetailPage))).pop();

  // Complete the Navigator route transition before interacting with the
  // underlying entry point again. A single pump is not sufficient because
  // MaterialPageRoute has an exit animation; without settling it, the button
  // remains covered by the outgoing route and the test can fail for the wrong
  // reason (finder sees zero buttons), rather than exercising lifecycle.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'PatientDetailPage survives rapid push/pop while async loading is in flight',
    (tester) async {
      await tester.pumpWidget(_app());

      for (var i = 0; i < 5; i++) {
        await _openAndRapidlyClose(tester);
        expect(find.text('فتح المريض'), findsOneWidget);
        expect(find.byType(PatientDetailPage), findsNothing);
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

      await _openAndRapidlyClose(tester);
      expect(find.text('فتح المريض'), findsOneWidget);
      expect(find.byType(PatientDetailPage), findsNothing);

      // Re-enter immediately after the previous route has completed its
      // transition and disposal callback has had a chance to run.
      await tester.tap(find.text('فتح المريض'));
      await tester.pump();
      expect(find.byType(PatientDetailPage), findsOneWidget);

      Navigator.of(tester.element(find.byType(PatientDetailPage))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(PatientDetailPage), findsNothing);
    },
  );
}
