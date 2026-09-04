enum CaregiverRole { primary, caregiver, viewer }

CaregiverRole caregiverRoleFromDb(String value) {
  switch (value) {
    case 'PRIMARY_CAREGIVER':
      return CaregiverRole.primary;
    case 'VIEWER':
      return CaregiverRole.viewer;
    default:
      return CaregiverRole.caregiver;
  }
}

String caregiverRoleToDb(CaregiverRole role) {
  switch (role) {
    case CaregiverRole.primary:
      return 'PRIMARY_CAREGIVER';
    case CaregiverRole.viewer:
      return 'VIEWER';
    case CaregiverRole.caregiver:
      return 'CAREGIVER';
  }
}

/// A link between a caregiver and a patient, enriched at query time with the
/// linked patient's display info (name / avatar / id) for the Family tab.
class CaregiverLink {
  final String id;
  final String caregiverId;
  final String patientId;
  final String patientName;
  final String? patientAvatarUrl;
  final CaregiverRole role;
  final String? relationshipLabel;
  final DateTime createdAt;

  const CaregiverLink({
    required this.id,
    required this.caregiverId,
    required this.patientId,
    required this.patientName,
    this.patientAvatarUrl,
    required this.role,
    this.relationshipLabel,
    required this.createdAt,
  });

  factory CaregiverLink.fromMap(Map<String, dynamic> map) {
    final patient = map['patient'] as Map<String, dynamic>?;
    return CaregiverLink(
      id: map['id'] as String,
      caregiverId: map['caregiver_id'] as String,
      patientId: map['patient_id'] as String,
      patientName: (patient?['full_name'] as String?) ?? 'مريض',
      patientAvatarUrl: patient?['avatar_url'] as String?,
      role: caregiverRoleFromDb(map['role'] as String),
      relationshipLabel: map['relationship_label'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
