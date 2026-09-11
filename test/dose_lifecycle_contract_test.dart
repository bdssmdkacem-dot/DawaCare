import 'package:flutter_test/flutter_test.dart';

import '../lib/features/doses/domain/dose_lifecycle.dart';
import '../lib/models/dose_instance.dart';

void main() {
  group('DoseLifecycle', () {
    test('supports the forward reminder lifecycle', () {
      expect(
        DoseLifecycle.canTransition(DoseStatus.pending, DoseStatus.reminderSent),
        isTrue,
      );
      expect(
        DoseLifecycle.canTransition(DoseStatus.reminderSent, DoseStatus.snoozed),
        isTrue,
      );
      expect(
        DoseLifecycle.canTransition(DoseStatus.snoozed, DoseStatus.missed),
        isTrue,
      );
      expect(
        DoseLifecycle.canTransition(DoseStatus.missed, DoseStatus.taken),
        isTrue,
      );
    });

    test('terminal states cannot regress', () {
      for (final terminal in const [
        DoseStatus.taken,
        DoseStatus.skipped,
        DoseStatus.cancelled,
      ]) {
        expect(
          DoseLifecycle.canTransition(terminal, DoseStatus.pending),
          isFalse,
        );
        expect(
          DoseLifecycle.canTransition(terminal, DoseStatus.reminderSent),
          isFalse,
        );
        expect(
          DoseLifecycle.canTransition(terminal, DoseStatus.snoozed),
          isFalse,
        );
        expect(
          DoseLifecycle.canTransition(terminal, DoseStatus.missed),
          isFalse,
        );
        expect(DoseLifecycle.canTransition(terminal, terminal), isTrue);
      }
    });

    test('missed dose can only be recovered by taking it', () {
      expect(
        DoseLifecycle.canTransition(DoseStatus.missed, DoseStatus.taken),
        isTrue,
      );
      expect(
        DoseLifecycle.canTransition(DoseStatus.missed, DoseStatus.snoozed),
        isFalse,
      );
      expect(
        DoseLifecycle.canTransition(DoseStatus.missed, DoseStatus.reminderSent),
        isFalse,
      );
      expect(
        DoseLifecycle.canTransition(DoseStatus.missed, DoseStatus.skipped),
        isFalse,
      );
    });

    test('same-state replay is always idempotent', () {
      for (final status in DoseStatus.values) {
        expect(DoseLifecycle.canTransition(status, status), isTrue);
      }
    });

    test('snoozed and reminder-sent can be resumed without creating a new dose', () {
      expect(
        DoseLifecycle.canTransition(DoseStatus.snoozed, DoseStatus.reminderSent),
        isTrue,
      );
      expect(
        DoseLifecycle.canTransition(DoseStatus.reminderSent, DoseStatus.snoozed),
        isTrue,
      );
    });
  });
}
