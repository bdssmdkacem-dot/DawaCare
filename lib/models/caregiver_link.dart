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
/// linked patient's display info (name / id) for the Family tab.
class CaregiverLink {
  final String id;
  final String caregiverId;
  final String patientId;
  final String patientName;
  final CaregiverRole role;
  final DateTime createdAt;

  const CaregiverLink({
    required this.id,
    required this.caregiverId,
    required this.patientId,
    required this.patientName,
    required this.role,
    required this.createdAt,
  });

  factory CaregiverLink.fromMap(Map<String, dynamic> map) {
    final patient = map['patient'] as Map<String, dynamic>?;
    return CaregiverLink(
      id: map['id'] as String,
      caregiverId: map['caregiver_id'] as String,
      patientId: map['patient_id'] as String,
      patientName: (patient?['full_name'] as String?) ?? 'مريض',
      role: caregiverRoleFromDb(map['role'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
