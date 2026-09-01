enum ScheduleType { daily, weekly, specificDays, interval, once, prn }

ScheduleType scheduleTypeFromDb(String value) {
  switch (value) {
    case 'WEEKLY':
      return ScheduleType.weekly;
    case 'SPECIFIC_DAYS':
      return ScheduleType.specificDays;
    case 'INTERVAL':
      return ScheduleType.interval;
    case 'ONCE':
      return ScheduleType.once;
    case 'PRN':
      return ScheduleType.prn;
    default:
      return ScheduleType.daily;
  }
}

String scheduleTypeToDb(ScheduleType type) {
  switch (type) {
    case ScheduleType.weekly:
      return 'WEEKLY';
    case ScheduleType.specificDays:
      return 'SPECIFIC_DAYS';
    case ScheduleType.interval:
      return 'INTERVAL';
    case ScheduleType.once:
      return 'ONCE';
    case ScheduleType.prn:
      return 'PRN';
    case ScheduleType.daily:
      return 'DAILY';
  }
}

/// Weekday convention used throughout the app: 1 = Sunday ... 7 = Saturday
/// (matches the calendar tool's convention already used elsewhere).
class MedicationSchedule {
  final String id;
  final String medicationId;
  final ScheduleType type;
  final String time; // "HH:mm"
  final List<int> daysOfWeek;
  final int? intervalDays;
  final String doseAmount;
  final DateTime startDate;
  final DateTime? endDate;
  final String timezone;

  const MedicationSchedule({
    required this.id,
    required this.medicationId,
    required this.type,
    required this.time,
    this.daysOfWeek = const [],
    this.intervalDays,
    required this.doseAmount,
    required this.startDate,
    this.endDate,
    required this.timezone,
  });

  factory MedicationSchedule.fromMap(Map<String, dynamic> map) {
    return MedicationSchedule(
      id: map['id'] as String,
      medicationId: map['medication_id'] as String,
      type: scheduleTypeFromDb(map['type'] as String),
      time: map['time'] as String,
      daysOfWeek: (map['days_of_week'] as List?)?.map((e) => e as int).toList() ?? const [],
      intervalDays: map['interval_days'] as int?,
      doseAmount: map['dose_amount'] as String? ?? '1',
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date'] as String) : null,
      timezone: map['timezone'] as String? ?? 'Africa/Casablanca',
    );
  }

  Map<String, dynamic> toInsertMap(String medicationIdOverride) => {
        'medication_id': medicationIdOverride,
        'type': scheduleTypeToDb(type),
        'time': time,
        'days_of_week': daysOfWeek,
        'interval_days': intervalDays,
        'dose_amount': doseAmount,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate?.toIso8601String().split('T').first,
        'timezone': timezone,
      };

  int get hour => int.parse(time.split(':')[0]);
  int get minute => int.parse(time.split(':')[1]);
}
