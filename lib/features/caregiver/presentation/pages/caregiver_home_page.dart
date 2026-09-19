import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../models/caregiver_alert.dart';
import '../../../../models/caregiver_link.dart';
import '../../../../models/family_link_request.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/caregiver_provider.dart';
import '../widgets/family_link_requests_section.dart';
import '../widgets/link_code_sheet.dart';
import 'patient_detail_page.dart';

class CaregiverHomePage extends StatefulWidget {
  const CaregiverHomePage({super.key, this.initialAlertId});

  final String? initialAlertId;

  @override
  State<CaregiverHomePage> createState() => _CaregiverHomePageState();
}

class _CaregiverHomePageState extends State<CaregiverHomePage> {
  bool _openedInitialAlert = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = context.read<AuthProvider>().profile?.id;
    if (id != null) await context.read<CaregiverProvider>().load(id);
    _openInitialAlert();
  }

  void _openInitialAlert() {
    if (!mounted || _openedInitialAlert || widget.initialAlertId == null) return;
    final provider = context.read<CaregiverProvider>();
    final alert = provider.alerts.cast<CaregiverAlert?>().firstWhere(
      (item) => item?.id == widget.initialAlertId,
      orElse: () => null,
    );
    if (alert == null) return;
    _openedInitialAlert = true;
    final link = provider.linkedPatients.cast<CaregiverLink?>().firstWhere(
      (item) => item?.patientId == alert.patientId,
      orElse: () => null,
    );
    provider.markAlertRead(alert);
    if (link == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PatientDetailPage(link: link, initialDoseId: alert.doseId),
      ));
    });
  }

  Future<void> _openGenerateCodeSheet() async {
    final provider = context.read<CaregiverProvider>();
    await provider.generateCode();
    if (!mounted) return;
    final code = provider.activeCode;
    if (code == null) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? l.unexpectedError)),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LinkCodeSheet(
        initialCode: code,
        onRegenerate: () async {
          await provider.generateCode();
          return provider.activeCode;
        },
      ),
    );
  }

  Future<void> _openAddMemberDialog() async {
    final l = AppLocalizations.of(context);
    final codeController = TextEditingController();
    final relationshipController = TextEditingController();
    var selectedRole = CaregiverRole.caregiver;
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
            title: Text(l.tr('إضافة فرد من العائلة', 'Add family member', 'Ajouter un membre de la famille')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.tr('أدخل رمز الربط الذي أرسله لك فرد العائلة من تطبيقه.', 'Enter the link code sent by your family member from their app.', 'Saisissez le code de liaison envoyé par votre proche depuis son application.')),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l.tr('رمز الربط', 'Link code', 'Code de liaison'),
                      hintText: l.tr('مثال: 123456', 'Example: 123456', 'Exemple : 123456'),
                      prefixIcon: Icon(Icons.link_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: relationshipController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l.tr('صلة القرابة (اختياري)', 'Relationship (optional)', 'Lien familial (facultatif)'),
                      hintText: l.tr('مثال: ابني، والدتي، زوجتي', 'Example: son, mother, wife', 'Exemple : fils, mère, épouse'),
                      prefixIcon: Icon(Icons.people_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CaregiverRole>(
                    initialValue: selectedRole,
                    decoration: InputDecoration(
                      labelText: l.tr('نوع الوصول', 'Access type', 'Type d’accès'),
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: CaregiverRole.caregiver,
                        child: Text(l.tr('مرافق — يستطيع التعديل', 'Caregiver — can edit', 'Accompagnant — peut modifier')),
                      ),
                      DropdownMenuItem(
                        value: CaregiverRole.viewer,
                        child: Text(l.tr('مشاهد — عرض فقط', 'Viewer — view only', 'Observateur — lecture seule')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedRole = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      selectedRole == CaregiverRole.viewer
                          ? l.tr('المشاهد يستطيع الاطلاع على بيانات فرد العائلة دون تعديل الأدوية أو الجرعات أو المخزون.', 'The viewer can see family member data without editing medicines, doses or stock.', 'L’observateur peut consulter les données sans modifier les médicaments, doses ou stocks.')
                          : l.tr('المرافق يستطيع إدارة الأدوية والجرعات والجدول والمخزون حسب صلاحياته.', 'The caregiver can manage medicines, doses, schedules and stock according to permissions.', 'L’accompagnant peut gérer les médicaments, doses, planning et stock selon ses permissions.'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l.cancel),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final code = codeController.text.trim();
                  if (code.isEmpty) return;
                  final provider = context.read<CaregiverProvider>();
                  final patientName = await provider.submitCode(
                    code,
                    role: selectedRole,
                    relationshipLabel: relationshipController.text.trim().isEmpty
                        ? null
                        : relationshipController.text.trim(),
                  );
                  if (!dialogContext.mounted) return;
                  if (patientName != null) {
                    Navigator.pop(dialogContext, true);
                  } else {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(provider.error ?? l.tr('تعذّر إرسال طلب الربط.', 'Could not send the link request.', 'Impossible d’envoyer la demande de liaison.'))),
                    );
                  }
                },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(l.tr('إرسال الطلب', 'Send request', 'Envoyer la demande')),
              ),
            ],
          );
          },
        ),
      );
      if (!mounted) return;
      if (result == true) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.tr('تم إرسال طلب الربط. بانتظار موافقة فرد العائلة.', 'Link request sent. Waiting for family member approval.', 'Demande envoyée. En attente de l’approbation du membre de la famille.'))),
        );
      }
    } finally {
      codeController.dispose();
      relationshipController.dispose();
    }
  }

  Future<void> _respondToRequest(FamilyLinkRequest request, bool approve) async {
    final l = AppLocalizations.of(context);
    final provider = context.read<CaregiverProvider>();
    final success = await provider.respondToRequest(request, approve: approve);
    if (!mounted) return;
    if (success) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? l.tr('تم قبول الدعوة وإضافة فرد العائلة.', 'Invitation accepted and family member added.', 'Invitation acceptée et membre de la famille ajouté.') : l.tr('تم رفض دعوة الربط.', 'Link request rejected.', 'Demande de liaison refusée.'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? l.tr('تعذّر تنفيذ العملية. حاول مرة أخرى.', 'Could not complete the operation. Please try again.', 'Impossible de terminer l’opération. Réessayez.'))),
      );
    }
  }

  Future<void> _cancelSentRequest(FamilyLinkRequest request) async {
    final l = AppLocalizations.of(context);
    final provider = context.read<CaregiverProvider>();
    final success = await provider.cancelSentRequest(request);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? l.tr('تم إلغاء طلب الربط.', 'Link request cancelled.', 'Demande de liaison annulée.') : (provider.error ?? l.tr('تعذّر إلغاء الطلب.', 'Could not cancel the request.', 'Impossible d’annuler la demande.')))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CaregiverProvider>();
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.family),
        actions: [
          IconButton(
            tooltip: l.tr('إضافة فرد برمز', 'Add member by code', 'Ajouter un membre avec un code'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: provider.isSubmittingCode ? null : _openAddMemberDialog,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FamilyLinkRequestsSection(
              provider: provider,
              onRespond: _respondToRequest,
              onCancel: _cancelSentRequest,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(l.familyMembers, style: Theme.of(context).textTheme.headlineSmall),
                ),
                FilledButton.tonalIcon(
                  onPressed: provider.isSubmittingCode ? null : _openAddMemberDialog,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(l.tr('إضافة برمز', 'Add by code', 'Ajouter avec un code')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: provider.isCodeLoading ? null : _openGenerateCodeSheet,
                icon: const Icon(Icons.vpn_key_rounded),
                label: Text(l.tr('إنشاء رمز ربط لإرساله', 'Create a link code to send', 'Créer un code de liaison à envoyer')),
              ),
            ),
            const SizedBox(height: 12),
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (provider.linkedPatients.isEmpty)
              _EmptyState(onGenerateCode: _openGenerateCodeSheet, onAddMember: _openAddMemberDialog)
            else
              ...provider.linkedPatients.map(
                (link) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.person),
                    ),
                    title: Text(link.patientName),
                    subtitle: Text(link.relationshipLabel ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PatientDetailPage(link: link)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onGenerateCode, required this.onAddMember});
  final VoidCallback onGenerateCode;
  final VoidCallback onAddMember;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Icon(Icons.people_outline, size: 64),
        const SizedBox(height: 16),
        const Text(
          l.tr('لا يوجد أفراد مرتبطون بعد. يمكنك إنشاء رمز لإرساله، أو إدخال رمز أرسله لك أحد أفراد العائلة.', 'No linked family members yet. You can create a code to send or enter a code from a family member.', 'Aucun membre de la famille lié. Vous pouvez créer un code à envoyer ou saisir un code reçu.'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAddMember,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: Text(AppLocalizations.of(context).tr('إضافة فرد برمز', 'Add member by code', 'Ajouter un membre avec un code')),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onGenerateCode,
          icon: const Icon(Icons.qr_code_rounded),
          label: Text(AppLocalizations.of(context).tr('إنشاء رمز لإرساله', 'Create a code to send', 'Créer un code à envoyer')),
        ),
      ],
    );
  }
}
