import '../../../models/caregiver_link.dart';

/// Centralizes patient/caregiver authorization decisions used by the UI.
///
/// Database RLS remains the final security boundary; this class keeps the
/// Flutter experience consistent and prevents Viewer actions from appearing
/// actionable in the first place.
class PatientPermissions {
  const PatientPermissions._(this.role);

  final CaregiverRole? role;

  bool get canView => role != null;

  /// Clinical/data editing permission.
  bool get canEdit =>
      role == CaregiverRole.primary || role == CaregiverRole.caregiver;

  bool get canEditMedication => canEdit;
  bool get canEditSchedule => canEdit;
  bool get canManageStock => canEdit;
  bool get canManageDose => canEdit;

  /// Caregiver-management is reserved for the primary caregiver.
  bool get canManageCaregivers => role == CaregiverRole.primary;

  /// Messaging is available to every linked role. Patient-level contact
  /// restrictions remain a separate link-level/server concern.
  bool get canContact => role != null;
  bool get canSendMessage => canContact;

  bool get canUnlink => role == CaregiverRole.primary;

  bool get isViewer => role == CaregiverRole.viewer;

  static PatientPermissions forRole(CaregiverRole? role) =>
      PatientPermissions._(role);
}
