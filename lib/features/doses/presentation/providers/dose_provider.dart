import 'package:flutter/foundation.dart';

import '../../../../core/utils/date_time_utils.dart';
import '../../../../models/dose_instance.dart';
import '../../../../models/reminder_policy.dart';
import '../../../reminders/data/reminder_policy_repository.dart';
import '../../../reminders/domain/reminder_engine.dart';
import '../../data/dose_repository.dart';

/// Drives the Today screen (and, when pointed at a different patientId, the
/// caregiver's per-patient view). Owns the load → generate → fetch → local
/// notification sync pipeline described in the architecture doc's
/// "Dose Lifecycle" diagram.
class DoseProvider extends ChangeNotifier {
  final DoseRepository _doseRepo = DoseRepository();
  final ReminderPolicyRepository _policyRepo = ReminderPolicyRepository();

  String? patientId;
  List<DoseInstance> _doses = [];
  ReminderPolicy policy = const ReminderPolicy(patientId: '');
  bool isLoading = false;
  String? error;

  List<DoseInstance> get all => _doses;

  List<DoseInstance> get todayDoses {
    final today = _doses.where((d) => DateTimeUtils.isSameDate(d.scheduledAt, DateTime.now())).toList();
    today.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return today;
  }

  List<DoseInstance> get upcomingDoses {
    final now = DateTime.now();
    final upcoming = _doses.where((d) => d.scheduledAt.isAfter(now) && !DateTimeUtils.isSameDate(d.scheduledAt, now)).toList();
    upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming;
  }

  /// Loads a rolling window of [today-1, today+2] doses for [patientId].
  /// [scheduleReminders] should be true only for the signed-in user's own
  /// doses — a caregiver viewing a family member's doses shouldn't have
  /// alarms fire on their own phone for someone else's medication.
  Future<void> load(String forPatientId, {bool scheduleReminders = true}) async {
    patientId = forPatientId;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _doseRepo.ensureDosesGenerated(forPatientId);
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      final to = DateTime(now.year, now.month, now.day).add(const Duration(days: 2, hours: 23));

      _doses = await _doseRepo.fetchDosesForRange(forPatientId, from: from, to: to);
      policy = await _policyRepo.fetch(forPatientId);

      if (scheduleReminders) {
        await ReminderEngine.syncUpcoming(_doses, policy);
      }
    } catch (e) {
      error = 'تعذّر تحميل الجرعات. تحقق من الاتصال بالإنترنت.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confirm(DoseInstance dose, {String source = 'PATIENT'}) =>
      _updateStatus(dose, DoseStatus.taken, source: source);
  Future<void> snooze(DoseInstance dose, {String source = 'PATIENT'}) =>
      _updateStatus(dose, DoseStatus.snoozed, source: source);
  Future<void> skip(DoseInstance dose, {String source = 'PATIENT'}) =>
      _updateStatus(dose, DoseStatus.skipped, source: source);

  Future<void> _updateStatus(DoseInstance dose, DoseStatus status, {String source = 'PATIENT'}) async {
    final updated = await _doseRepo.updateStatus(dose, status, source: source);
    final idx = _doses.indexWhere((d) => d.id == dose.id);
    if (idx != -1) _doses[idx] = updated;
    notifyListeners();
    await ReminderEngine.cancelFor(dose.id);
  }
}
