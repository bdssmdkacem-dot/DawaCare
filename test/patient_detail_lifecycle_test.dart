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

NavigatorState _navigator(GlobalKey<NavigatorState> navigatorKey) {
  final navigator = navigatorKey.currentState;
  expect(navigator, isNotNull);
  expect(navigator!.mounted, isTrue);
  return navigator;
}

Future<void> _openAndRapidlyClose(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigatorKey,
) async {
  final navigator = _navigator(navigatorKey);

  navigator.push(
    MaterialPageRoute(
      builder: (_) => PatientDetailPage(link: _link()),
    ),
  );
  await tester.pump();
  expect(find.byType(PatientDetailPage), findsOneWidget);

  // Start the page's post-frame async work, then pop immediately while the
  // real providers may still be loading.
  await tester.pump(const Duration(milliseconds: 1));
  navigator.pop();

  // Complete route teardown before the next iteration/re-entry.
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

      final navigator = _navigator(navigatorKey);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => PatientDetailPage(link: _link()),
        ),
      );
      await tester.pump();
      expect(find.byType(PatientDetailPage), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(PatientDetailPage), findsNothing);
    },
  );
}
