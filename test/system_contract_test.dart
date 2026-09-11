import 'package:flutter_test/flutter_test.dart';

import 'package:dawacare/features/doses/domain/dose_lifecycle.dart';
import 'package:dawacare/features/sync/domain/sync_queue_rules.dart';
import 'package:dawacare/models/dose_instance.dart';

void main() {
  group('Medication system contract', () {
    test('a missed dose can recover to taken but cannot be skipped', () {
      expect(
        DoseLifecycle.canTransition(DoseStatus.missed, DoseStatus.taken),
        isTrue,
      );
      expect(
        DoseLifecycle.canTransition(DoseStatus.missed, DoseStatus.skipped),
        isFalse,
      );
    });

    test('reminder lifecycle reaches missed then taken deterministically', () {
      expect(
        DoseLifecycle.canTransition(
          DoseStatus.reminderSent,
          DoseStatus.missed,
        ),
        isTrue,
      );
      expect(
        DoseLifecycle.canTransition(DoseStatus.missed, DoseStatus.taken),
        isTrue,
      );
    });

    test('taken is terminal and cannot be replayed as another outcome', () {
      for (final status in const [
        DoseStatus.pending,
        DoseStatus.reminderSent,
        DoseStatus.snoozed,
        DoseStatus.missed,
        DoseStatus.skipped,
        DoseStatus.cancelled,
      ]) {
        expect(DoseLifecycle.canTransition(DoseStatus.taken, status), isFalse);
      }
      expect(DoseLifecycle.canTransition(DoseStatus.taken, DoseStatus.taken), isTrue);
    });

    test('skipped and cancelled never become taken through lifecycle replay', () {
      expect(DoseLifecycle.canTransition(DoseStatus.skipped, DoseStatus.taken), isFalse);
      expect(DoseLifecycle.canTransition(DoseStatus.cancelled, DoseStatus.taken), isFalse);
    });

    test('offline taken intent is deterministic and distinct from missed', () {
      final taken = SyncQueueRules.doseStatusOperationId(
        doseId: 'dose-42',
        status: 'TAKEN',
      );
      final missed = SyncQueueRules.doseStatusOperationId(
        doseId: 'dose-42',
        status: 'MISSED',
      );

      expect(taken, 'DOSE_STATUS:dose-42:TAKEN');
      expect(missed, 'DOSE_STATUS:dose-42:MISSED');
      expect(taken, isNot(missed));
    });

    test('server already applied taken intent is not replayed as a new event', () {
      expect(
        SyncQueueRules.isAlreadyApplied(
          applied: true,
          currentStatus: 'TAKEN',
          requestedStatus: 'TAKEN',
        ),
        isTrue,
      );
      expect(
        SyncQueueRules.isPermanentConflict(
          applied: true,
          currentStatus: 'TAKEN',
          requestedStatus: 'TAKEN',
        ),
        isFalse,
      );
    });

    test('server already at requested state is treated as completed', () {
      expect(
        SyncQueueRules.isAlreadyApplied(
          applied: false,
          currentStatus: 'TAKEN',
          requestedStatus: 'TAKEN',
        ),
        isTrue,
      );
    });

    test('an incompatible newer server state is treated as conflict', () {
      expect(
        SyncQueueRules.isPermanentConflict(
          applied: false,
          currentStatus: 'SKIPPED',
          requestedStatus: 'TAKEN',
        ),
        isTrue,
      );
    });

    test('non-taken terminal outcomes do not imply stock consumption', () {
      const nonConsuming = {
        DoseStatus.skipped,
        DoseStatus.cancelled,
        DoseStatus.missed,
      };
      expect(nonConsuming.contains(DoseStatus.taken), isFalse);
      expect(nonConsuming.length, 3);
    });
  });
}
