import 'package:dawacare/features/medications/presentation/widgets/medication_stock_badge.dart';
import 'package:dawacare/models/medication.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Medication _medication({bool enabled = true, double quantity = 18}) {
  final now = DateTime.now();
  return Medication(
    id: 'med-1',
    patientId: 'patient-1',
    name: 'Amoxicillin',
    startDate: now,
    endDate: null,
    active: true,
    createdBy: 'patient-1',
    createdAt: now,
    stockEnabled: enabled,
    stockQuantity: quantity,
    stockUnit: 'capsule',
    packageQuantity: 24,
    lowStockThreshold: 5,
  );
}

void main() {
  group('Medication stock regression', () {
    testWidgets('shows remaining capsule quantity', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MedicationStockBadge(medication: _medication())),
      ));

      expect(find.text('متبقي 18 كبسولة'), findsOneWidget);
    });

    testWidgets('shows low-stock state at threshold', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MedicationStockBadge(medication: _medication(quantity: 5))),
      ));

      expect(find.text('متبقي 5 كبسولة'), findsOneWidget);
    });

    testWidgets('shows empty state when stock is zero', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MedicationStockBadge(medication: _medication(quantity: 0))),
      ));

      expect(find.text('نفد الدواء'), findsOneWidget);
    });

    testWidgets('offers stock setup when tracking is disabled', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MedicationStockBadge(medication: _medication(enabled: false), onAdd: () => tapped = true)),
      ));

      expect(find.text('تفعيل عداد المخزون'), findsOneWidget);
      await tester.tap(find.text('تفعيل عداد المخزون'));
      expect(tapped, isTrue);
    });
  });
}
