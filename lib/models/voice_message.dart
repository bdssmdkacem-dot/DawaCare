class VoiceMessage {
  final String id;
  final String senderId;
  final String patientId;
  final String? doseId;
  final String storagePath;
  final int? durationMs;
  final DateTime createdAt;
  final DateTime? readAt;
  final String senderName;

  const VoiceMessage({
    required this.id,
    required this.senderId,
    required this.patientId,
    this.doseId,
    required this.storagePath,
    this.durationMs,
    required this.createdAt,
    this.readAt,
    this.senderName = 'المتابع',
  });

  factory VoiceMessage.fromMap(Map<String, dynamic> map) {
    final sender = map['sender'] as Map<String, dynamic>?;
    return VoiceMessage(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      patientId: map['patient_id'] as String,
      doseId: map['dose_id'] as String?,
      storagePath: map['storage_path'] as String,
      durationMs: map['duration_ms'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      readAt: map['read_at'] == null ? null : DateTime.parse(map['read_at'] as String).toLocal(),
      senderName: (sender?['full_name'] as String?)?.trim().isNotEmpty == true
          ? sender!['full_name'] as String
          : 'المتابع',
    );
  }
}
