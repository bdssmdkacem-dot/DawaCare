import 'package:dawacare/features/caregiver/domain/patient_permissions.dart';
import 'package:dawacare/models/caregiver_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PatientPermissions role matrix', () {
    test('primary caregiver has full patient management permissions', () {
      final permissions = PatientPermissions.forRole(CaregiverRole.primary);

      expect(permissions.canView, isTrue);
      expect(permissions.canEdit, isTrue);
      expect(permissions.canEditMedication, isTrue);
      expect(permissions.canEditSchedule, isTrue);
      expect(permissions.canManageStock, isTrue);
      expect(permissions.canManageDose, isTrue);
      expect(permissions.canManageCaregivers, isTrue);
      expect(permissions.canContact, isTrue);
      expect(permissions.canSendMessage, isTrue);
      expect(permissions.canUnlink, isTrue);
      expect(permissions.isViewer, isFalse);
    });

    test('caregiver can edit clinical data but cannot manage caregivers', () {
      final permissions = PatientPermissions.forRole(CaregiverRole.caregiver);

      expect(permissions.canView, isTrue);
      expect(permissions.canEdit, isTrue);
      expect(permissions.canEditMedication, isTrue);
      expect(permissions.canEditSchedule, isTrue);
      expect(permissions.canManageStock, isTrue);
      expect(permissions.canManageDose, isTrue);
      expect(permissions.canManageCaregivers, isFalse);
      expect(permissions.canContact, isTrue);
      expect(permissions.canSendMessage, isTrue);
      expect(permissions.canUnlink, isFalse);
      expect(permissions.isViewer, isFalse);
    });

    test('viewer can view and communicate but is read-only', () {
      final permissions = PatientPermissions.forRole(CaregiverRole.viewer);

      expect(permissions.canView, isTrue);
      expect(permissions.canEdit, isFalse);
      expect(permissions.canEditMedication, isFalse);
      expect(permissions.canEditSchedule, isFalse);
      expect(permissions.canManageStock, isFalse);
      expect(permissions.canManageDose, isFalse);
      expect(permissions.canManageCaregivers, isFalse);
      expect(permissions.canContact, isTrue);
      expect(permissions.canSendMessage, isTrue);
      expect(permissions.canUnlink, isFalse);
      expect(permissions.isViewer, isTrue);
    });

    test('unlinked user has no patient permissions', () {
      final permissions = PatientPermissions.forRole(null);

      expect(permissions.canView, isFalse);
      expect(permissions.canEdit, isFalse);
      expect(permissions.canEditMedication, isFalse);
      expect(permissions.canEditSchedule, isFalse);
      expect(permissions.canManageStock, isFalse);
      expect(permissions.canManageDose, isFalse);
      expect(permissions.canManageCaregivers, isFalse);
      expect(permissions.canContact, isFalse);
      expect(permissions.canSendMessage, isFalse);
      expect(permissions.canUnlink, isFalse);
      expect(permissions.isViewer, isFalse);
    });
  });
}
