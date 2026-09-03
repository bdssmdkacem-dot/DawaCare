import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/caregiver_alert.dart';
import '../../../../models/caregiver_link.dart';
import '../../../../models/family_link_request.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/caregiver_provider.dart';
import '../widgets/link_code_sheet.dart';
import 'patient_detail_page.dart';

class CaregiverHomePage extends StatefulWidget {
  final String? initialAlertId;
  const CaregiverHomePage({super.key, this.initialAlertId});
  @override
  State<CaregiverHomePage> createState() => _CaregiverHomePageState();
}

class _CaregiverHomePageState extends State<CaregiverHomePage> {
  bool _loadedOnce = false;
  bool _openedInitialAlert = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      final id = context.read<AuthProvider>().profile?.id;
      if (id != null) context.read<CaregiverProvider>().load(id).then((_) => _openInitialAlert());
    }
  }

  Future<void> _reload() async {
    final id = context.read<AuthProvider>().profile?.id;
    if (id != null) await context.read<CaregiverProvider>().load(id);
  }

  void _openInitialAlert() {
    if (!mounted || _openedInitialAlert || widget.initialAlertId == null) return;
    final p = context.read<CaregiverProvider>();
    final alert = p.alerts.cast<CaregiverAlert?>().firstWhere((a) => a?.id == widget.initialAlertId, orElse: () => null);
    if (alert == null) return;
    _openedInitialAlert = true;
    final link = p.linkedPatients.cast<CaregiverLink?>().firstWhere((l) => l?.patientId == alert.patientId, orElse: () => null);
    p.markAlertRead(alert);
    if (link == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientDetailPage(link: link, initialDoseId: alert.doseId))); });
  }

  Future<void> _openAlert(CaregiverAlert alert) async {
    final p = context.read<CaregiverProvider>();
    await p.markAlertRead(alert);
    if (!mounted) return;
    final link = p.linkedPatients.cast<CaregiverLink?>().firstWhere((l) => l?.patientId == alert.patientId, orElse: () => null);
    if (link == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientDetailPage(link: link, initialDoseId: alert.doseId)));
  }

  Future<void> _openGenerateCodeSheet() async {
    final p = context.read<CaregiverProvider>();
    final l = AppLocalizations.of(context);
    await p.generateCode();
    if (!mounted) return;
    if (p.activeCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.error ?? l.unexpectedError)));
      return;
    }
    await showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => LinkCodeSheet(initialCode: p.activeCode!, onRegenerate: () async { await p.generateCode(); return p.activeCode; }));
  }

  Future<void> _openRequestLinkDialog() async {
    final l = AppLocalizations.of(context);
    final codeCtrl = TextEditingController();
    final relationshipCtrl = TextEditingController();
    var selectedRole = CaregiverRole.caregiver;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.followSomeone),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_tr(context, 'أدخل رمز الربط الذي شاركه معك واختر مستوى الوصول.', 'Enter the shared link code and choose the access level.', 'Saisissez le code partagé et choisissez le niveau d’accès.')),
            const SizedBox(height: 14),
            TextField(controller: codeCtrl, autofocus: true, textAlign: TextAlign.center, keyboardType: TextInputType.number, maxLength: 6, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 6), decoration: const InputDecoration(counterText: '', hintText: '000000')),
            const SizedBox(height: 10),
            Text(_tr(context, 'نوع الوصول', 'Access level', 'Niveau d’accès'), style: const TextStyle(fontWeight: FontWeight.w800)),
            RadioListTile<CaregiverRole>(contentPadding: EdgeInsets.zero, value: CaregiverRole.caregiver, groupValue: selectedRole, onChanged: (value) { if (value != null) setDialogState(() => selectedRole = value); }, title: Text(_tr(context, 'مرافق — يمكنه متابعة وتدبير الجرعات', 'Caregiver — can monitor and manage doses', 'Accompagnant — peut suivre et gérer les doses'))),
            RadioListTile<CaregiverRole>(contentPadding: EdgeInsets.zero, value: CaregiverRole.viewer, groupValue: selectedRole, onChanged: (value) { if (value != null) setDialogState(() => selectedRole = value); }, title: Text(_tr(context, 'فرد العائلة — مشاهدة وإرسال رسائل صوتية فقط', 'Family member — view and send voice messages only', 'Membre de la famille — consultation et messages vocaux uniquement'))),
            TextField(controller: relationshipCtrl, decoration: InputDecoration(labelText: _tr(context, 'صلتك بهذا الشخص (اختياري)', 'Your relationship to this person (optional)', 'Votre lien avec cette personne (facultatif)'), hintText: _tr(context, 'مثال: ابنه، ابنته...', 'e.g. son, daughter...', 'ex. fils, fille...'))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_tr(context, 'إرسال الطلب', 'Send request', 'Envoyer la demande'))),
          ],
        ),
      ),
    );
    if (result != true || codeCtrl.text.trim().isEmpty || !mounted) return;
    final p = context.read<CaregiverProvider>();
    final name = await p.submitCode(codeCtrl.text.trim(), role: selectedRole, relationshipLabel: relationshipCtrl.text.trim());
    if (!mounted) return;
    if (name != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_tr(context, 'تم إرسال الطلب إلى $name — بانتظار الموافقة', 'Request sent to $name — awaiting approval', 'Demande envoyée à $name — en attente d’approbation'))));
      await _reload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.error ?? l.unexpectedError)));
    }
  }

  Future<void> _respond(FamilyLinkRequest r, bool approve) async {
    final p = context.read<CaregiverProvider>();
    final ok = await p.respondToRequest(r, approve: approve);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? _tr(context, 'تم قبول ${r.caregiverName}', '${r.caregiverName} was accepted', '${r.caregiverName} a été accepté') : _tr(context, 'تم رفض الطلب', 'Request rejected', 'Demande refusée'))));
      if (approve) await _reload();
    }
  }

  Widget _sectionHeader(BuildContext context, String title, {IconData? icon}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [if (icon != null) ...[Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 19, color: AppColors.primary)), const SizedBox(width: 10)], Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)))]));

  Widget _actionCard(BuildContext context, {required IconData icon, required String label, required VoidCallback onPressed}) => Expanded(child: Card(child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onPressed, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), shape: BoxShape.circle), child: Icon(icon, color: AppColors.primary, size: 23)), const SizedBox(height: 9), Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))]))));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.watch<CaregiverProvider>();
    final children = <Widget>[
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.primaryDark]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .16), blurRadius: 20, offset: const Offset(0, 8))]), child: Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 29)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.family, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(_tr(context, 'تابع من تحب وكن قريباً من أدويتهم.', 'Stay close to the people you care for and their medicines.', 'Restez proche de vos proches et de leurs médicaments.'), style: TextStyle(color: Colors.white.withValues(alpha: .88), height: 1.35))]))]),
      const SizedBox(height: 18),
      if (p.incomingRequests.isNotEmpty) ...[_sectionHeader(context, l.familyRequests, icon: Icons.notifications_active_rounded), ...p.incomingRequests.map((r) => _IncomingRequestCard(request: r, onApprove: () => _respond(r, true), onReject: () => _respond(r, false))), const SizedBox(height: 18)],
      _sectionHeader(context, _tr(context, 'إدارة الربط', 'Connection', 'Liaison'), icon: Icons.link_rounded),
      Row(children: [_actionCard(context, icon: Icons.qr_code_2_rounded, label: l.inviteToMedicines, onPressed: _openGenerateCodeSheet), const SizedBox(width: 10), _actionCard(context, icon: Icons.person_search_rounded, label: l.followSomeone, onPressed: _openRequestLinkDialog)]),
      if (p.sentRequests.isNotEmpty) ...[const SizedBox(height: 18), _sectionHeader(context, l.pendingRequests, icon: Icons.hourglass_top_rounded), ...p.sentRequests.map((r) => _SentRequestTile(request: r, onCancel: () async { final ok = await context.read<CaregiverProvider>().cancelSentRequest(r); if (!context.mounted) return; if (ok) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_tr(context, 'تم إلغاء الطلب', 'Request cancelled', 'Demande annulée')))); }))],
      if (p.alerts.isNotEmpty) ...[const SizedBox(height: 18), _sectionHeader(context, l.alerts, icon: Icons.warning_amber_rounded), ...p.alerts.take(5).map((a) => _AlertTile(alert: a, onTap: () => _openAlert(a)))],
      const SizedBox(height: 18), _sectionHeader(context, l.familyMembers, icon: Icons.groups_rounded),
      if (p.linkedPatients.isEmpty) Card(child: Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), child: Column(children: [Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .09), shape: BoxShape.circle), child: const Icon(Icons.family_restroom_rounded, size: 32, color: AppColors.primary)), const SizedBox(height: 12), Text(l.noFamilyLinked, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 16), SizedBox(width: 220, child: PrimaryButton(label: l.requestFollowNow, onPressed: _openRequestLinkDialog, icon: Icons.person_add_alt_1_rounded))]))) else ...p.linkedPatients.map((link) => _PatientLinkTile(link: link)),
    ];
    return Scaffold(appBar: AppBar(title: Text(l.family)), body: p.isLoading && p.linkedPatients.isEmpty && p.incomingRequests.isEmpty ? const LoadingIndicator() : RefreshIndicator(onRefresh: _reload, child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), children: children)));
  }
}

String _tr(BuildContext c, String ar, String en, String fr) { switch (Localizations.localeOf(c).languageCode) { case 'en': return en; case 'fr': return fr; default: return ar; } }

class _IncomingRequestCard extends StatelessWidget {
  final FamilyLinkRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _IncomingRequestCard({required this.request, required this.onApprove, required this.onReject});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final role = request.role == CaregiverRole.viewer ? _tr(context, 'فرد العائلة', 'Family member', 'Membre de la famille') : request.role == CaregiverRole.primary ? _tr(context, 'مرافق رئيسي', 'Primary caregiver', 'Accompagnant principal') : _tr(context, 'مرافق', 'Caregiver', 'Accompagnant');
    final msg = request.relationshipLabel != null && request.relationshipLabel!.isNotEmpty ? _tr(context, '${request.caregiverName} (${request.relationshipLabel}) يطلب الوصول كـ $role', '${request.caregiverName} (${request.relationshipLabel}) requests access as $role', '${request.caregiverName} (${request.relationshipLabel}) demande un accès en tant que $role') : _tr(context, '${request.caregiverName} يطلب الوصول كـ $role', '${request.caregiverName} requests access as $role', '${request.caregiverName} demande un accès en tant que $role');
    return Card(color: Theme.of(context).colorScheme.primary.withValues(alpha: .06), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(DateTimeUtils.relativeDayLabel(request.requestedAt), style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 12), Row(children: [Expanded(child: OutlinedButton(onPressed: onReject, child: Text(l.reject))), const SizedBox(width: 10), Expanded(child: FilledButton(onPressed: onApprove, child: Text(l.accept)))])])));
  }
}

class _SentRequestTile extends StatelessWidget { final FamilyLinkRequest request; final VoidCallback onCancel; const _SentRequestTile({required this.request, required this.onCancel}); @override Widget build(BuildContext context) { final l = AppLocalizations.of(context); final role = request.role == CaregiverRole.viewer ? _tr(context, 'فرد العائلة', 'Family member', 'Membre de la famille') : _tr(context, 'مرافق', 'Caregiver', 'Accompagnant'); return Card(child: ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: .12), shape: BoxShape.circle), child: const Icon(Icons.hourglass_top_rounded, color: AppColors.warning)), title: Text(request.patientName, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${l.waitingApproval} · $role'), trailing: TextButton(onPressed: onCancel, child: Text(l.cancel)))); } }

class _PatientLinkTile extends StatelessWidget { final CaregiverLink link; const _PatientLinkTile({required this.link}); @override Widget build(BuildContext context) { final role = link.role == CaregiverRole.viewer ? _tr(context, 'فرد العائلة', 'Family member', 'Membre de la famille') : link.role == CaregiverRole.primary ? _tr(context, 'مرافق رئيسي', 'Primary caregiver', 'Accompagnant principal') : _tr(context, 'مرافق', 'Caregiver', 'Accompagnant'); final subtitle = [if (link.relationshipLabel != null && link.relationshipLabel!.isNotEmpty) link.relationshipLabel!, role].join(' · '); return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person_rounded)), title: Text(link.patientName, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientDetailPage(link: link)))); } }

class _AlertTile extends StatelessWidget { final CaregiverAlert alert; final VoidCallback onTap; const _AlertTile({required this.alert, required this.onTap}); @override Widget build(BuildContext context) { return Card(child: ListTile(leading: Icon(alert.read ? Icons.notifications_none_rounded : Icons.notifications_active_rounded, color: alert.read ? null : AppColors.danger), title: Text(alert.message, maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text(DateTimeUtils.relativeDayLabel(alert.createdAt)), onTap: onTap)); } }
