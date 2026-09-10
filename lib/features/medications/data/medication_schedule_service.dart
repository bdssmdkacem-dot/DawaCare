import '../../../models/medication_schedule.dart';
import '../../doses/data/dose_repository.dart';
import '../../reminders/data/reminder_policy_repository.dart';
import '../../reminders/domain/reminder_engine.dart';
import 'medication_repository.dart';

class MedicationScheduleService {
  final MedicationRepository _repo = MedicationRepository();
  final DoseRepository _doseRepo = DoseRepository();
  final ReminderPolicyRepository _policyRepo = ReminderPolicyRepository();

  Future<List<MedicationSchedule>> createSchedules({
    required String medicationId,
    required String patientId,
    required List<MedicationSchedule> schedules,
  }) async {
    final created = <MedicationSchedule>[];
    for (final schedule in schedules) {
      created.add(await _repo.createSchedule(medicationId, schedule));
    }
    await _sync(patientId: patientId, medicationId: medicationId);
    return created;
  }

  Future<void> _sync({required String patientId, required String medicationId}) async {
    await _doseRepo.ensureDosesGenerated(patientId);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 2, hours: 23));
    final doses = await _doseRepo.fetchDosesForRange(patientId, from: from, to: to);
    final policy = await _policyRepo.fetch(patientId);
    await ReminderEngine.syncUpcoming(
      doses.where((dose) => dose.medicationId == medicationId).toList(),
      policy,
    );
  }
}
