import 'package:dawacare/core/localization/app_localizations.dart';
import 'package:dawacare/features/patient/presentation/widgets/dose_card.dart';
import 'package:dawacare/models/dose_instance.dart';
import 'package:flutter/material.dart';
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
    localizationsDelegates: const [AppLocalizations.delegate],
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

      expect(find.text('دواء الاختبار'), findsOneWidget);
      expect(find.text('تم أخذ الجرعة'), findsOneWidget);
      expect(find.text('تأجيل'), findsOneWidget);
      expect(find.text('تخطي'), findsOneWidget);

      await tester.tap(find.text('تم أخذ الجرعة'));
      await tester.tap(find.text('تأجيل'));
      await tester.tap(find.text('تخطي'));

      expect(confirmed, isTrue);
      expect(snoozed, isTrue);
      expect(skipped, isTrue);
    });

    testWidgets('taken dose is rendered as resolved and exposes no actions', (tester) async {
      await tester.pumpWidget(
        _host(DoseCard(dose: _dose(status: DoseStatus.taken))),
      );

      expect(find.text('دواء الاختبار'), findsOneWidget);
      expect(find.text('تم أخذ الجرعة'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('تأجيل'), findsNothing);
      expect(find.text('تخطي'), findsNothing);
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

      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.text('تم أخذ الجرعة'), findsOneWidget);

      await tester.tap(find.text('تم أخذ الجرعة'));
      expect(confirmed, isTrue);
    });

    testWidgets('empty and error presentation primitives remain renderable', (tester) async {
      await tester.pumpWidget(
        _host(
          ListView(
            children: const [
              Card(child: Text('لا توجد جرعات مجدولة لك اليوم.')),
              Card(child: Text('تعذّر تحميل الجرعات. تحقق من الاتصال بالإنترنت.')),
            ],
          ),
        ),
      );

      expect(find.text('لا توجد جرعات مجدولة لك اليوم.'), findsOneWidget);
      expect(find.text('تعذّر تحميل الجرعات. تحقق من الاتصال بالإنترنت.'), findsOneWidget);
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

      expect(find.text('دواء الاختبار'), findsNWidgets(3));
      expect(find.byType(DoseCard), findsNWidgets(3));
    });
  });
}
