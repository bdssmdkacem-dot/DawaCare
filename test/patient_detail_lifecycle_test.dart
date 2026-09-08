import 'package:dawacare/core/localization/app_localizations.dart';
import 'package:dawacare/features/caregiver/presentation/pages/patient_detail_page.dart';
import 'package:dawacare/models/caregiver_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

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
    home: Navigator(
      key: _navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: Center(child: Text('Lifecycle host')),
        ),
      ),
    ),
  );
}

NavigatorState _navigator() {
  final navigator = _navigatorKey.currentState;
  expect(navigator, isNotNull);
  expect(navigator!.mounted, isTrue);
  return navigator;
}

Future<void> _openAndRapidlyClose(WidgetTester tester) async {
  final navigator = _navigator();

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
}

void main() {
  testWidgets(
    'PatientDetailPage survives rapid push/pop while async loading is in flight',
    (tester) async {
      await tester.pumpWidget(_app());

      for (var i = 0; i < 5; i++) {
        await _openAndRapidlyClose(tester);
      }

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(PatientDetailPage), findsNothing);
    },
  );

  testWidgets(
    'PatientDetailPage can be re-entered immediately after disposal',
    (tester) async {
      await tester.pumpWidget(_app());

      await _openAndRapidlyClose(tester);

      final navigator = _navigator();
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
