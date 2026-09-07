import 'package:dawacare/core/localization/app_localizations.dart';
import 'package:dawacare/features/patient/presentation/widgets/dose_card.dart';
import 'package:dawacare/models/dose_instance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

DoseInstance _dose({
  required DoseStatus status,
  DateTime? scheduledAt,
  String id = 'dose-1',
  String patientId = 'patient-1',
}) {
  final now = DateTime.now();
  return DoseInstance(
    id: id,
    medicationId: 'med-1',
    scheduleId: 'schedule-1',
    patientId: patientId,
    medicationName: 'دواء الاختبار',
    doseAmount: 'قرص واحد',
    scheduledAt: scheduledAt ?? now,
    status: status,
    updatedAt: now,
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  group('Patient Home dose regression', () {
    testWidgets('pending dose exposes confirm, snooze and skip actions', (tester) async {
      var confirmed = false;
      var snoozed = false;
      var skipped = false;

      await tester.pumpWidget(
        _host(
          DoseCard(
            dose: _dose(status: DoseStatus.pending),
            onConfirm: () => confirmed = true,
            onSnooze: () => snoozed = true,
            onSkip: () => skipped = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DoseCard), findsOneWidget);
      expect(find.text('دواء الاختبار'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.tap(find.byIcon(Icons.schedule_rounded).last);
      await tester.tap(find.byIcon(Icons.close_rounded));

      expect(confirmed, isTrue);
      expect(snoozed, isTrue);
      expect(skipped, isTrue);
    });

    testWidgets('taken dose is rendered as resolved and exposes no actions', (tester) async {
      await tester.pumpWidget(
        _host(DoseCard(dose: _dose(status: DoseStatus.taken))),
      );
      await tester.pump();

      expect(find.byType(DoseCard), findsOneWidget);
      expect(find.text('دواء الاختبار'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('snoozed dose remains actionable for a later confirmation', (tester) async {
      var confirmed = false;

      await tester.pumpWidget(
        _host(
          DoseCard(
            dose: _dose(status: DoseStatus.snoozed),
            onConfirm: () => confirmed = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DoseCard), findsOneWidget);
      expect(find.text('دواء الاختبار'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_rounded));
      expect(confirmed, isTrue);
    });

    testWidgets('empty and error presentation primitives remain renderable', (tester) async {
      await tester.pumpWidget(
        _host(
          ListView(
            children: const [
              Card(child: Text('لا توجد أدوية مجدولة اليوم')),
              Card(child: Text('حدث خطأ غير متوقع. حاول مرة أخرى.')),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('لا توجد أدوية مجدولة اليوم'), findsOneWidget);
      expect(find.text('حدث خطأ غير متوقع. حاول مرة أخرى.'), findsOneWidget);
    });

    testWidgets('multiple dose cards can coexist in the parent children list', (tester) async {
      final doses = [
        _dose(status: DoseStatus.pending, id: 'dose-1'),
        _dose(status: DoseStatus.taken, id: 'dose-2'),
        _dose(status: DoseStatus.snoozed, id: 'dose-3'),
      ];

      await tester.pumpWidget(
        _host(
          ListView(
            children: [
              ...doses.map((dose) => DoseCard(dose: dose)),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DoseCard), findsNWidgets(3));
      expect(find.text('دواء الاختبار'), findsNWidgets(3));
    });
  });
}
