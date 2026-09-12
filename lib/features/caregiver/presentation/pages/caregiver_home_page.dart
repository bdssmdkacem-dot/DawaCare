import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../models/caregiver_alert.dart';
import '../../../../models/caregiver_link.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/caregiver_provider.dart';
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PatientDetailPage(
            link: link,
            initialDoseId: alert.doseId,
          ),
        ),
      );
    });
  }

  Future<void> _openGenerateCodeSheet() async {
    final provider = context.read<CaregiverProvider>();
    final l = AppLocalizations.of(context);
    await provider.generateCode();
    if (!mounted) return;

    final code = provider.activeCode;
    if (code == null) {
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
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.linkCode, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SelectableText(
              code.code,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(l.linkCodeHint, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddMemberDialog() async {
    final codeController = TextEditingController();
    final relationshipController = TextEditingController();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إضافة فرد من العائلة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أدخل رمز الربط الذي أرسله لك فرد العائلة من تطبيقه.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'رمز الربط',
                  hintText: 'مثال: 123456',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationshipController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'صلة القرابة (اختياري)',
                  hintText: 'مثال: ابني، والدتي، زوجتي',
                  prefixIcon: Icon(Icons.people_alt_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final code = codeController.text.trim();
                if (code.isEmpty) return;
                final provider = context.read<CaregiverProvider>();
                final patientName = await provider.submitCode(
                  code,
                  role: CaregiverRole.caregiver,
                  relationshipLabel: relationshipController.text.trim().isEmpty
                      ? null
                      : relationshipController.text.trim(),
                );
                if (!dialogContext.mounted) return;
                if (patientName != null) {
                  Navigator.pop(dialogContext, true);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.error ?? 'تعذّر إرسال طلب الربط.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('إرسال الطلب'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (result == true) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب الربط. بانتظار موافقة فرد العائلة.')),
        );
      }
    } finally {
      codeController.dispose();
      relationshipController.dispose();
    }
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
            tooltip: 'إضافة فرد برمز',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: provider.isSubmittingCode ? null : _openAddMemberDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.familyMembers,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: provider.isSubmittingCode ? null : _openAddMemberDialog,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('إضافة برمز'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (provider.linkedPatients.isEmpty)
              _EmptyState(
                onGenerateCode: _openGenerateCodeSheet,
                onAddMember: _openAddMemberDialog,
              )
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
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PatientDetailPage(link: link),
                        ),
                      );
                    },
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
  const _EmptyState({
    required this.onGenerateCode,
    required this.onAddMember,
  });

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
          'لا يوجد أفراد مرتبطون بعد. يمكنك إنشاء رمز لإرساله، أو إدخال رمز أرسله لك أحد أفراد العائلة.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAddMember,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('إضافة فرد برمز'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onGenerateCode,
          icon: const Icon(Icons.qr_code_rounded),
          label: const Text('إنشاء رمز لإرساله'),
        ),
      ],
    );
  }
}
