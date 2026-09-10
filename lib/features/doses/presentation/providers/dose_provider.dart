import 'package:flutter/foundation.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../models/dose_instance.dart';
import '../../../../models/reminder_policy.dart';
import '../../../reminders/data/reminder_policy_repository.dart';
import '../../../reminders/domain/reminder_engine.dart';
import '../../data/dose_repository.dart';

/// Drives the Today screen and owns the load → generate → reconcile → fetch
/// → reminder synchronization pipeline.
class DoseProvider extends ChangeNotifier {
  final DoseRepository _doseRepo = DoseRepository();
  final ReminderPolicyRepository _policyRepo = ReminderPolicyRepository();
  bool _disposed = false;

  String? patientId;
  List<DoseInstance> _doses = [];
  ReminderPolicy policy = const ReminderPolicy(patientId: '');
  bool isLoading = false;
  String? error;

  List<DoseInstance> get all => _doses;

  List<DoseInstance> get todayDoses {
    final today = _doses
        .where((d) => DateTimeUtils.isSameDate(d.scheduledAt, DateTime.now()))
        .toList();
    today.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return today;
  }

  List<DoseInstance> get upcomingDoses {
    final now = DateTime.now();
    final upcoming = _doses
        .where((d) =>
            d.scheduledAt.isAfter(now) &&
            !DateTimeUtils.isSameDate(d.scheduledAt, now))
        .toList();
    upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Loads a rolling window and keeps dose statuses/reminders synchronized.
  Future<void> load(String forPatientId, {bool scheduleReminders = true}) async {
    final switchingPatient = patientId != null && patientId != forPatientId;

    if (switchingPatient) {
      _doses = [];
      policy = const ReminderPolicy(patientId: '');
    }

    patientId = forPatientId;
    isLoading = true;
    error = null;
    _notify();

    try {
      // Generation is idempotent and intentionally happens before fetching.
      await _doseRepo.ensureDosesGenerated(forPatientId);

      // Resolve overdue doses before the UI and reminder engine consume them.
      // The five-minute grace period lives in DoseRepository so all callers
      // use the same definition of "missed".
      await _doseRepo.reconcileMissedDoses(forPatientId);

      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));
      final to = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 2, hours: 23));

      _doses = await _doseRepo.fetchDosesForRange(
        forPatientId,
        from: from,
        to: to,
      );
      policy = await _policyRepo.fetch(forPatientId);

      if (scheduleReminders) {
        await ReminderEngine.syncUpcoming(_doses, policy);
      }
    } catch (e) {
      error = 'تعذّر تحميل الجرعات. تحقق من الاتصال بالإنترنت.';
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> confirm(DoseInstance dose, {String source = 'PATIENT'}) =>
      _updateStatus(dose, DoseStatus.taken, source: source);

  Future<void> snooze(DoseInstance dose, {String source = 'PATIENT'}) async {
    final updated = await NotificationService.instance.snoozeDose(
      dose,
      source: source,
    );
    if (updated == null) return;
    final idx = _doses.indexWhere((d) => d.id == dose.id);
    if (idx != -1) _doses[idx] = updated;
    _notify();
  }

  Future<void> skip(DoseInstance dose, {String source = 'PATIENT'}) =>
      _updateStatus(dose, DoseStatus.skipped, source: source);

  Future<void> _updateStatus(
    DoseInstance dose,
    DoseStatus status, {
    String source = 'PATIENT',
  }) async {
    final updated = await _doseRepo.updateStatus(
      dose,
      status,
      source: source,
    );
    final idx = _doses.indexWhere((d) => d.id == dose.id);
    if (idx != -1) _doses[idx] = updated;
    _notify();
    await ReminderEngine.cancelFor(dose.id);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
