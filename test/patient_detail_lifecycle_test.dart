import 'package:dawacare/core/localization/app_localizations.dart';
import 'package:dawacare/features/caregiver/presentation/pages/patient_detail_page.dart';
import 'package:dawacare/models/caregiver_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      home: PatientDetailPage(link: _link()),
    );

Widget _host() => _app(
      home: const Scaffold(
        body: Center(child: Text('Lifecycle host')),
      ),
    );

Future<void> _openAndRapidlyClose(WidgetTester tester) async {
  await tester.pumpWidget(_page());
  await tester.pump();
  expect(find.byType(PatientDetailPage), findsOneWidget);

  // Let the page start its post-frame async work, then replace the entire
  // route tree immediately. This exercises State.dispose while providers
  // may still be loading, without depending on a test Navigator harness.
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pumpWidget(_host());
  await tester.pump();
  expect(find.byType(PatientDetailPage), findsNothing);

  // Flush PatientDetailPage's deferred notifier disposal callbacks.
  await tester.pump(const Duration(milliseconds: 50));
  expect(find.byType(PatientDetailPage), findsNothing);
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // PatientDetailPage constructs providers whose repositories access
  // Supabase.instance during initState. The lifecycle test does not need a
  // live backend, but Supabase must be initialized so the real page can mount.
  await Supabase.initialize(
    url: 'https://test.supabase.co',
    publishableKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlc3QiLCJyb2xlIjoianonInRlc3QifQ.test',
  );

  testWidgets(
    'PatientDetailPage survives rapid replacement while async loading is in flight',
    (tester) async {
      for (var i = 0; i < 5; i++) {
        await _openAndRapidlyClose(tester);
      }
    },
  );

  testWidgets(
    'PatientDetailPage can be re-entered immediately after disposal',
    (tester) async {
      await _openAndRapidlyClose(tester);

      await tester.pumpWidget(_page());
      await tester.pump();
      expect(find.byType(PatientDetailPage), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpWidget(_host());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(PatientDetailPage), findsNothing);
    },
  );
}
