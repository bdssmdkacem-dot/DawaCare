import 'package:flutter/foundation.dart';

import '../../../../models/caregiver_alert.dart';
import '../../../../models/caregiver_link.dart';
import '../../../../models/family_link_code.dart';
import '../../../../models/family_link_request.dart';
import '../../data/caregiver_repository.dart';

class CaregiverProvider extends ChangeNotifier {
  final CaregiverRepository _repo = CaregiverRepository();
  List<CaregiverLink> linkedPatients = [];
  List<CaregiverAlert> alerts = [];
  List<FamilyLinkRequest> incomingRequests = [];
  List<FamilyLinkRequest> sentRequests = [];
  FamilyLinkCode? activeCode;
  bool isLoading = false;
  bool isCodeLoading = false;
  bool isSubmittingCode = false;
  String? error;

  int get unreadAlertCount => alerts.where((a) => !a.read).length;
  int get pendingApprovalCount => incomingRequests.length;

  Future<void> load(String userId) async {
    isLoading = true; error = null; notifyListeners();
    try {
      final results = await Future.wait([
        _repo.fetchLinkedPatients(userId), _repo.fetchAlerts(userId),
        _repo.fetchIncomingRequests(userId), _repo.fetchSentRequests(userId),
      ]);
      linkedPatients = results[0] as List<CaregiverLink>;
      alerts = results[1] as List<CaregiverAlert>;
      incomingRequests = results[2] as List<FamilyLinkRequest>;
      sentRequests = results[3] as List<FamilyLinkRequest>;
    } catch (_) { error = 'تعذّر تحميل بيانات العائلة.'; }
    finally { isLoading = false; notifyListeners(); }
  }

  Future<void> generateCode() async {
    isCodeLoading = true; error = null; notifyListeners();
    try { activeCode = await _repo.createLinkCode(); }
    catch (_) { error = 'تعذّر إنشاء رمز الربط. حاول مرة أخرى.'; }
    finally { isCodeLoading = false; notifyListeners(); }
  }

  void clearCode() { activeCode = null; notifyListeners(); }

  Future<String?> submitCode(String code, {required CaregiverRole role, String? relationshipLabel}) async {
    isSubmittingCode = true; error = null; notifyListeners();
    try {
      final patientName = await _repo.requestLink(code: code, role: role, relationshipLabel: relationshipLabel);
      isSubmittingCode = false; notifyListeners(); return patientName;
    } on FamilyLinkException catch (e) {
      error = switch (e.code) {
        'CODE_INVALID_OR_EXPIRED' => 'الرمز غير صحيح أو انتهت صلاحيته. اطلب رمزًا جديدًا.',
        'CANNOT_LINK_SELF' => 'لا يمكنك إرسال طلب لنفسك.',
        'ALREADY_LINKED' => 'أنتما مرتبطان بالفعل.',
        'REQUEST_ALREADY_PENDING' => 'لديك طلب سابق بانتظار الموافقة لهذا الشخص.',
        'INVALID_LINK_ROLE' => 'نوع الربط غير مسموح.',
        _ => 'تعذّر إرسال الطلب. حاول مرة أخرى.',
      };
      isSubmittingCode = false; notifyListeners(); return null;
    } catch (_) { error = 'تعذّر إرسال الطلب. تحقق من الاتصال بالإنترنت.'; isSubmittingCode = false; notifyListeners(); return null; }
  }

  Future<bool> cancelSentRequest(FamilyLinkRequest request) async {
    try { await _repo.cancelRequest(request.id); sentRequests.removeWhere((r) => r.id == request.id); notifyListeners(); return true; }
    catch (_) { error = 'تعذّر إلغاء الطلب.'; notifyListeners(); return false; }
  }

  Future<bool> respondToRequest(FamilyLinkRequest request, {required bool approve}) async {
    try { await _repo.respondToRequest(requestId: request.id, approve: approve); incomingRequests.removeWhere((r) => r.id == request.id); notifyListeners(); return true; }
    catch (_) { error = 'تعذّر تنفيذ العملية. حاول مرة أخرى.'; notifyListeners(); return false; }
  }

  Future<void> unlink(CaregiverLink link) async { await _repo.unlink(link.id); linkedPatients.removeWhere((l) => l.id == link.id); notifyListeners(); }

  Future<void> markAlertRead(CaregiverAlert alert) async {
    await _repo.markAlertRead(alert.id);
    final idx = alerts.indexWhere((a) => a.id == alert.id);
    if (idx != -1) {
      alerts[idx] = CaregiverAlert(id: alert.id, caregiverId: alert.caregiverId, patientId: alert.patientId, patientName: alert.patientName, doseId: alert.doseId, type: alert.type, message: alert.message, read: true, createdAt: alert.createdAt);
      notifyListeners();
    }
  }
}
