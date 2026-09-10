import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dawacare/app/theme/app_colors.dart';
import 'package:dawacare/models/caregiver_link.dart';
import 'package:dawacare/models/family_member_summary.dart';
import 'package:dawacare/features/caregiver/presentation/widgets/family_member_card.dart';

CaregiverLink _link({
  CaregiverRole role = CaregiverRole.caregiver,
  String? relationshipLabel = 'ابني',
}) {
  return CaregiverLink(
    id: 'link-1',
    caregiverId: 'caregiver-1',
    patientId: 'patient-1',
    patientName: 'محمد أحمد',
    patientAvatarUrl: null,
    role: role,
    relationshipLabel: relationshipLabel,
    createdAt: DateTime(2026, 9, 1),
  );
}

Widget _app(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('family member card renders identity, relationship and active link', (tester) async {
    var opened = false;
    var profiled = false;

    await tester.pumpWidget(_app(FamilyMemberCard(
      link: _link(),
      onOpen: () => opened = true,
      onProfile: () => profiled = true,
    )));

    expect(find.text('محمد أحمد'), findsOneWidget);
    expect(find.textContaining('ابني'), findsOneWidget);
    expect(find.text('الرابط نشط'), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);

    await tester.tap(find.text('محمد أحمد'));
    expect(opened, isTrue);

    await tester.tap(find.byType(CircleAvatar));
    expect(profiled, isTrue);
  });

  testWidgets('viewer family member uses the restricted family role label', (tester) async {
    await tester.pumpWidget(_app(FamilyMemberCard(
      link: _link(role: CaregiverRole.viewer, relationshipLabel: null),
      onOpen: () {},
      onProfile: () {},
    )));

    expect(find.text('فرد العائلة'), findsOneWidget);
    expect(find.text('مرافق'), findsNothing);
    expect(find.text('مرافق رئيسي'), findsNothing);
  });

  testWidgets('family member card keeps avatar-independent initials fallback', (tester) async {
    await tester.pumpWidget(_app(FamilyMemberCard(
      link: _link(),
      onOpen: () {},
      onProfile: () {},
    )));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(avatar.backgroundImage, isNull);
    expect(find.text('مأ'), findsOneWidget);
    expect(AppColors.primary, isNotNull);
  });

  testWidgets('family member card renders medication and adherence metrics', (tester) async {
    const summary = FamilyMemberSummary(
      activeMedicationCount: 4,
      todayDoseCount: 6,
      takenDoseCount: 5,
      missedDoseCount: 1,
      nextDoseAt: null,
      lowStockMedicationCount: 0,
      outOfStockMedicationCount: 0,
      lastActivityAt: null,
    );

    await tester.pumpWidget(_app(FamilyMemberCard(
      link: _link(),
      summary: summary,
      onOpen: () {},
      onProfile: () {},
    )));

    expect(find.text('4'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('83%'), findsOneWidget);
    expect(find.textContaining('1 جرعات فائتة اليوم'), findsOneWidget);
  });
}