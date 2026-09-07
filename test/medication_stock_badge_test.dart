import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dawacare/models/medication.dart';
import 'package:dawacare/models/medication_schedule.dart';
import 'package:dawacare/features/medications/presentation/widgets/medication_stock_badge.dart';

Medication _med({double stock = 24, double threshold = 5}) => Medication(
      id: 'm1',
      patientId: 'p1',
      name: 'دواء',
      startDate: DateTime(2026, 1, 1),
      active: true,
      createdBy: 'p1',
      createdAt: DateTime(2026, 1, 1),
      stockEnabled: true,
      stockQuantity: stock,
      stockUnit: 'capsule',
      packageQuantity: 24,
      lowStockThreshold: threshold,
    );

MedicationSchedule _daily(String dose) => MedicationSchedule(
      id: 's1',
      medicationId: 'm1',
      type: ScheduleType.daily,
      time: '08:00',
      doseAmount: dose,
      startDate: DateTime(2026, 1, 1),
      timezone: 'Africa/Casablanca',
    );

void main() {
  testWidgets('shows remaining stock and estimated days', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MedicationStockBadge(
          medication: _med(),
          schedules: [_daily('2')],
        ),
      ),
    ));

    expect(find.text('متبقي 24 كبسولة'), findsOneWidget);
    expect(find.textContaining('يكفي تقريبًا لـ 12 أيام'), findsOneWidget);
    expect(find.textContaining('عبوة: 24'), findsOneWidget);
  });

  testWidgets('shows low stock state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MedicationStockBadge(medication: _med(stock: 4))),
    ));
    expect(find.text('متبقي 4 كبسولة'), findsOneWidget);
    expect(find.textContaining('المخزون منخفض'), findsOneWidget);
  });

  testWidgets('shows depleted state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MedicationStockBadge(medication: _med(stock: 0))),
    ));
    expect(find.text('نفد الدواء'), findsOneWidget);
    expect(find.textContaining('أضف المخزون'), findsOneWidget);
  });

  testWidgets('offers stock activation when disabled', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MedicationStockBadge(
          medication: Medication(
            id: 'm1',
            patientId: 'p1',
            name: 'دواء',
            startDate: DateTime(2026, 1, 1),
            active: true,
            createdBy: 'p1',
            createdAt: DateTime(2026, 1, 1),
          ),
          onAdd: () {},
        ),
      ),
    ));
    expect(find.text('تفعيل عداد المخزون'), findsOneWidget);
  });
}
