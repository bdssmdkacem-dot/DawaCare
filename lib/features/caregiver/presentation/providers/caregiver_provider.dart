import 'package:flutter/foundation.dart';

import '../../../../models/caregiver_alert.dart';
import '../../../../models/caregiver_link.dart';
import '../../data/caregiver_repository.dart';

class CaregiverProvider extends ChangeNotifier {
  final CaregiverRepository _repo = CaregiverRepository();

  List<CaregiverLink> linkedPatients = [];
  List<CaregiverAlert> alerts = [];
  bool isLoading = false;
  String? error;

  int get unreadAlertCount => alerts.where((a) => !a.read).length;

  Future<void> load(String caregiverId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      linkedPatients = await _repo.fetchLinkedPatients(caregiverId);
      alerts = await _repo.fetchAlerts(caregiverId);
    } catch (e) {
      error = 'تعذّر تحميل بيانات العائلة.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> linkByFamilyCode(String code) async {
    try {
      final patientName = await _repo.linkByFamilyCode(code);
      return patientName;
    } catch (e) {
      final message = e.toString();
      if (message.contains('FAMILY_CODE_NOT_FOUND')) {
        error = 'الرمز غير صحيح. تحقق منه وحاول مرة أخرى.';
      } else if (message.contains('CANNOT_LINK_SELF')) {
        error = 'لا يمكنك إضافة نفسك.';
      } else {
        error = 'تعذّر الربط. حاول مرة أخرى.';
      }
      notifyListeners();
      return null;
    }
  }

  Future<void> unlink(CaregiverLink link) async {
    await _repo.unlink(link.id);
    linkedPatients.removeWhere((l) => l.id == link.id);
    notifyListeners();
  }

  Future<void> markAlertRead(CaregiverAlert alert) async {
    await _repo.markAlertRead(alert.id);
    final idx = alerts.indexWhere((a) => a.id == alert.id);
    if (idx != -1) {
      alerts[idx] = CaregiverAlert(
        id: alert.id,
        caregiverId: alert.caregiverId,
        patientId: alert.patientId,
        patientName: alert.patientName,
        doseId: alert.doseId,
        type: alert.type,
        message: alert.message,
        read: true,
        createdAt: alert.createdAt,
      );
      notifyListeners();
    }
  }
}
