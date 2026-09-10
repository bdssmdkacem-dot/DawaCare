import 'package:dawacare/features/caregiver/data/caregiver_repository.dart';
import 'package:dawacare/features/caregiver/domain/patient_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PatientPermissions', () {
    test('primary caregiver can manage patient medication flow', () {
      final permissions =
          PatientPermissions.forRole(CaregiverRole.primaryCaregiver);

      expect(permissions.canView, isTrue);
      expect(permissions.canEditMedication, isTrue);
      expect(permissions.canEditSchedule, isTrue);
      expect(permissions.canManageStock, isTrue);
      expect(permissions.canManageDose, isTrue);
      expect(permissions.canUnlink, isTrue);
      expect(permissions.canSendMessage, isTrue);
    });

    test('caregiver can manage medication but cannot unlink patient', () {
      final permissions = PatientPermissions.forRole(CaregiverRole.caregiver);

      expect(permissions.canView, isTrue);
      expect(permissions.canEditMedication, isTrue);
      expect(permissions.canEditSchedule, isTrue);
      expect(permissions.canManageStock, isTrue);
      expect(permissions.canManageDose, isTrue);
      expect(permissions.canUnlink, isFalse);
      expect(permissions.canSendMessage, isTrue);
    });

    test('viewer is strictly read-only for medication state', () {
      final permissions = PatientPermissions.forRole(CaregiverRole.viewer);

      expect(permissions.canView, isTrue);
      expect(permissions.isViewer, isTrue);
      expect(permissions.canEditMedication, isFalse);
      expect(permissions.canEditSchedule, isFalse);
      expect(permissions.canManageStock, isFalse);
      expect(permissions.canManageDose, isFalse);
      expect(permissions.canUnlink, isFalse);
      expect(permissions.canSendMessage, isTrue);
    });

    test('unlinked user cannot access patient permissions', () {
      final permissions = PatientPermissions.forRole(null);

      expect(permissions.canView, isFalse);
      expect(permissions.canEditMedication, isFalse);
      expect(permissions.canEditSchedule, isFalse);
      expect(permissions.canManageStock, isFalse);
      expect(permissions.canManageDose, isFalse);
      expect(permissions.canUnlink, isFalse);
      expect(permissions.canSendMessage, isFalse);
    });
  });
}
