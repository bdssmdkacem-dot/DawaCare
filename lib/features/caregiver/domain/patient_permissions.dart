import '../data/caregiver_repository.dart';

/// Centralizes patient/caregiver authorization decisions used by the UI.
///
/// Database RLS remains the final security boundary; this class keeps the
/// Flutter experience consistent and prevents Viewer actions from appearing
/// actionable in the first place.
class PatientPermissions {
  const PatientPermissions._(this.role);

  final CaregiverRole? role;

  bool get canView => role != null;

  bool get canEditMedication =>
      role == CaregiverRole.primaryCaregiver ||
      role == CaregiverRole.caregiver;

  bool get canEditSchedule => canEditMedication;

  bool get canManageStock => canEditMedication;

  bool get canManageDose => canEditMedication;

  bool get canUnlink => role == CaregiverRole.primaryCaregiver;

  bool get canSendMessage => role != null;

  bool get isViewer => role == CaregiverRole.viewer;

  static PatientPermissions forRole(CaregiverRole? role) =>
      PatientPermissions._(role);
}
