class ReminderPolicy {
  final String patientId;
  final int repeatIntervalMin;
  final int maxRepeats;
  final int gracePeriodMin;
  final bool caregiverEscalation;

  const ReminderPolicy({
    required this.patientId,
    this.repeatIntervalMin = 15,
    this.maxRepeats = 2,
    this.gracePeriodMin = 60,
    this.caregiverEscalation = true,
  });

  factory ReminderPolicy.fromMap(Map<String, dynamic> map) {
    return ReminderPolicy(
      patientId: map['patient_id'] as String,
      repeatIntervalMin: map['repeat_interval_min'] as int? ?? 15,
      maxRepeats: map['max_repeats'] as int? ?? 2,
      gracePeriodMin: map['grace_period_min'] as int? ?? 60,
      caregiverEscalation: map['caregiver_escalation'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toUpsertMap() => {
        'patient_id': patientId,
        'repeat_interval_min': repeatIntervalMin,
        'max_repeats': maxRepeats,
        'grace_period_min': gracePeriodMin,
        'caregiver_escalation': caregiverEscalation,
      };

  ReminderPolicy copyWith({
    int? repeatIntervalMin,
    int? maxRepeats,
    int? gracePeriodMin,
    bool? caregiverEscalation,
  }) {
    return ReminderPolicy(
      patientId: patientId,
      repeatIntervalMin: repeatIntervalMin ?? this.repeatIntervalMin,
      maxRepeats: maxRepeats ?? this.maxRepeats,
      gracePeriodMin: gracePeriodMin ?? this.gracePeriodMin,
      caregiverEscalation: caregiverEscalation ?? this.caregiverEscalation,
    );
  }
}
