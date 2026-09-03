import 'caregiver_link.dart';

enum FamilyLinkRequestStatus { pending, approved, rejected, cancelled }

FamilyLinkRequestStatus _statusFromDb(String value) {
  switch (value) {
    case 'APPROVED':
      return FamilyLinkRequestStatus.approved;
    case 'REJECTED':
      return FamilyLinkRequestStatus.rejected;
    case 'CANCELLED':
      return FamilyLinkRequestStatus.cancelled;
    default:
      return FamilyLinkRequestStatus.pending;
  }
}

/// A pending (or resolved) request to link a caregiver to a patient.
class FamilyLinkRequest {
  final String id;
  final String patientId;
  final String patientName;
  final String caregiverId;
  final String caregiverName;
  final String? relationshipLabel;
  final CaregiverRole role;
  final FamilyLinkRequestStatus status;
  final DateTime requestedAt;

  const FamilyLinkRequest({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.caregiverId,
    required this.caregiverName,
    this.relationshipLabel,
    required this.role,
    required this.status,
    required this.requestedAt,
  });

  factory FamilyLinkRequest.fromMap(Map<String, dynamic> map) {
    final patient = map['patient'] as Map<String, dynamic>?;
    final caregiver = map['caregiver'] as Map<String, dynamic>?;
    return FamilyLinkRequest(
      id: map['id'] as String,
      patientId: map['patient_id'] as String,
      patientName: (patient?['full_name'] as String?) ?? 'مريض',
      caregiverId: map['caregiver_id'] as String,
      caregiverName: (caregiver?['full_name'] as String?) ?? 'مستخدم',
      relationshipLabel: map['relationship_label'] as String?,
      role: caregiverRoleFromDb((map['role'] as String?) ?? 'CAREGIVER'),
      status: _statusFromDb(map['status'] as String),
      requestedAt: DateTime.parse(map['requested_at'] as String).toLocal(),
    );
  }
}
