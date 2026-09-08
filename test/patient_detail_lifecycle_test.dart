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

Widget _app(GlobalKey<NavigatorState> navigatorKey) {
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
    home: const Scaffold(
      body: Center(child: Text('Lifecycle host')),
    ),
  );
}

Future<void> _openAndRapidlyClose(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigatorKey,
) async {
  navigatorKey.currentState!.push(
    MaterialPageRoute(
      builder: (_) => PatientDetailPage(link: _link()),
    ),
  );
  await tester.pump();
  expect(find.byType(PatientDetailPage), findsOneWidget);

  // Let the page's post-frame callback start the real provider loads, then
  // immediately tear the route down while those asynchronous operations may
  // still be in flight. This is the lifecycle condition that previously
  // produced the framework red screen.
  await tester.pump(const Duration(milliseconds: 1));
  navigatorKey.currentState!.pop();

  // Finish the route transition before the next push. The test deliberately
  // avoids a text/button finder here: the regression target is Navigator and
  // notifier lifecycle, not the entry-point UI contract.
  await tester.pumpAndSettle();
  expect(find.byType(PatientDetailPage), findsNothing);
}

void main() {
  testWidgets(
    'PatientDetailPage survives rapid push/pop while async loading is in flight',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigatorKey));

      for (var i = 0; i < 5; i++) {
        await _openAndRapidlyClose(tester, navigatorKey);
      }

      // Flush deferred notifier disposal callbacks and any provider futures.
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(PatientDetailPage), findsNothing);
    },
  );

  testWidgets(
    'PatientDetailPage can be re-entered immediately after disposal',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigatorKey));

      await _openAndRapidlyClose(tester, navigatorKey);

      // Re-enter immediately after the previous route has completed its
      // transition and deferred disposal callback has had a chance to run.
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => PatientDetailPage(link: _link()),
        ),
      );
      await tester.pump();
      expect(find.byType(PatientDetailPage), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(PatientDetailPage), findsNothing);
    },
  );
}
