class CaregiverAlert {
  final String id;
  final String caregiverId;
  final String patientId;
  final String patientName;
  final String? doseId;
  final String type;
  final String message;
  final bool read;
  final DateTime createdAt;

  const CaregiverAlert({
    required this.id,
    required this.caregiverId,
    required this.patientId,
    required this.patientName,
    this.doseId,
    required this.type,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  factory CaregiverAlert.fromMap(Map<String, dynamic> map) {
    final patient = map['patient'] as Map<String, dynamic>?;
    return CaregiverAlert(
      id: map['id'] as String,
      caregiverId: map['caregiver_id'] as String,
      patientId: map['patient_id'] as String,
      patientName: (patient?['full_name'] as String?) ?? 'مريض',
      doseId: map['dose_id'] as String?,
      type: map['type'] as String,
      message: map['message'] as String,
      read: map['read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}
