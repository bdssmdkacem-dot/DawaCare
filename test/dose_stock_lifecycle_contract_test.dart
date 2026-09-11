import 'package:flutter_test/flutter_test.dart';

enum DoseAction { taken, snoozed, skipped, missed, cancelled }

bool consumesStock(DoseAction action) => action == DoseAction.taken;

class ConsumptionLedger {
  final Set<String> consumed = <String>{};

  bool consumeOnce(String doseId, DoseAction action) {
    if (!consumesStock(action)) return false;
    return consumed.add(doseId);
  }
}

void main() {
  test('only TAKEN consumes stock', () {
    expect(consumesStock(DoseAction.taken), isTrue);
    expect(consumesStock(DoseAction.snoozed), isFalse);
    expect(consumesStock(DoseAction.skipped), isFalse);
    expect(consumesStock(DoseAction.missed), isFalse);
    expect(consumesStock(DoseAction.cancelled), isFalse);
  });

  test('a repeated TAKEN is idempotent', () {
    final ledger = ConsumptionLedger();
    expect(ledger.consumeOnce('dose-1', DoseAction.taken), isTrue);
    expect(ledger.consumeOnce('dose-1', DoseAction.taken), isFalse);
  });

  test('different TAKEN doses consume independently', () {
    final ledger = ConsumptionLedger();
    expect(ledger.consumeOnce('dose-1', DoseAction.taken), isTrue);
    expect(ledger.consumeOnce('dose-2', DoseAction.taken), isTrue);
  });

  test('non-Taken actions never consume stock', () {
    final ledger = ConsumptionLedger();
    for (final action in DoseAction.values) {
      if (action == DoseAction.taken) continue;
      expect(ledger.consumeOnce('dose-${action.name}', action), isFalse);
    }
  });
}
