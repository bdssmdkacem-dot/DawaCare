import 'package:flutter_test/flutter_test.dart';

import 'package:dawacare/features/sync/domain/sync_queue_rules.dart';

void main() {
  group('SyncQueueRules', () {
    test('dose status intent id is deterministic', () {
      final first = SyncQueueRules.doseStatusOperationId(
        doseId: 'dose-1',
        status: 'TAKEN',
      );
      final second = SyncQueueRules.doseStatusOperationId(
        doseId: 'dose-1',
        status: 'TAKEN',
      );

      expect(first, second);
      expect(first, 'DOSE_STATUS:dose-1:TAKEN');
    });

    test('different status intents remain independent', () {
      expect(
        SyncQueueRules.doseStatusOperationId(
          doseId: 'dose-1',
          status: 'MISSED',
        ),
        isNot(
          SyncQueueRules.doseStatusOperationId(
            doseId: 'dose-1',
            status: 'TAKEN',
          ),
        ),
      );
    });

    test('already applied server result is terminal', () {
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

    test('same-state server result is terminal and idempotent', () {
      expect(
        SyncQueueRules.isAlreadyApplied(
          applied: false,
          currentStatus: 'TAKEN',
          requestedStatus: 'TAKEN',
        ),
        isTrue,
      );
    });

    test('newer incompatible server state is a permanent conflict', () {
      expect(
        SyncQueueRules.isPermanentConflict(
          applied: false,
          currentStatus: 'MISSED',
          requestedStatus: 'SKIPPED',
        ),
        isTrue,
      );
    });
  });
}