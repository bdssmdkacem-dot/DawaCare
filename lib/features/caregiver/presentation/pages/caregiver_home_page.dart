import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  const CaregiverHomePage({super.key});

  @override
  State<CaregiverHomePage> createState() => _CaregiverHomePageState();
}

class _CaregiverHomePageState extends State<CaregiverHomePage> {
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      final userId = context.read<AuthProvider>().profile?.id;
      if (userId != null) context.read<CaregiverProvider>().load(userId);
    }
  }

  Future<void> _reload() async {
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId != null) await context.read<CaregiverProvider>().load(userId);
  }

  Future<void> _openGenerateCodeSheet() async {
    final provider = context.read<CaregiverProvider>();
    await provider.generateCode();
    if (!mounted) return;

    if (provider.activeCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'تعذّر إنشاء الرمز')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LinkCodeSheet(
        initialCode: provider.activeCode!,
        onRegenerate: () async {
          await provider.generateCode();
          return provider.activeCode;
        },
      ),
    );
  }

  Future<void> _openRequestLinkDialog() async {
    final codeCtrl = TextEditingController();
    final relationshipCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب متابعة أحد أفراد العائلة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أدخل رمز الربط الذي شاركه معك (صالح 15 دقيقة، استعمال واحد):'),
            const SizedBox(height: 14),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 6),
              decoration: const InputDecoration(counterText: '', hintText: '000000'),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: relationshipCtrl,
              decoration: const InputDecoration(labelText: 'صلتك بهذا الشخص (اختياري)', hintText: 'مثال: ابنه، ابنته...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال الطلب')),
        ],
      ),
    );

    if (result != true || codeCtrl.text.trim().isEmpty || !mounted) return;

    final provider = context.read<CaregiverProvider>();
    final patientName = await provider.submitCode(
      codeCtrl.text.trim(),
      relationshipLabel: relationshipCtrl.text.trim(),
    );
    if (!mounted) return;

    if (patientName != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إرسال الطلب إلى $patientName — بانتظار الموافقة')),
      );
      await _reload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'تعذّر إرسال الطلب')),
      );
    }
  }

  Future<void> _respond(FamilyLinkRequest request, bool approve) async {
    final provider = context.read<CaregiverProvider>();
    final ok = await provider.respondToRequest(request, approve: approve);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'تم قبول ${request.caregiverName}' : 'تم رفض الطلب')),
      );
      if (approve) await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CaregiverProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('العائلة')),
      body: provider.isLoading && provider.linkedPatients.isEmpty && provider.incomingRequests.isEmpty
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (provider.incomingRequests.isNotEmpty) ...[
                    Text('طلبات بانتظار موافقتك', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    ...provider.incomingRequests.map(
                      (r) => _IncomingRequestCard(
                        request: r,
                        onApprove: () => _respond(r, true),
                        onReject: () => _respond(r, false),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openGenerateCodeSheet,
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text('دعوة فرد لأدويتي'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openRequestLinkDialog,
                          icon: const Icon(Icons.person_search_rounded),
                          label: const Text('متابعة شخص آخر'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (provider.sentRequests.isNotEmpty) ...[
                    Text('طلباتي المعلّقة', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    ...provider.sentRequests.map(
                      (r) => _SentRequestTile(
                        request: r,
                        onCancel: () async {
                          final caregiverProvider = context.read<CaregiverProvider>();
                          final ok = await caregiverProvider.cancelSentRequest(r);
                          if (ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إلغاء الطلب')),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (provider.alerts.isNotEmpty) ...[
                    Text('تنبيهات', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    ...provider.alerts.take(5).map((a) => _AlertTile(alert: a)),
                    const SizedBox(height: 20),
                  ],
                  Text('أفراد العائلة', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  if (provider.linkedPatients.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Icon(Icons.family_restroom_rounded, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('لم تربط أي فرد من العائلة بعد', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 220,
                            child: PrimaryButton(label: 'طلب متابعة أحد الآن', onPressed: _openRequestLinkDialog),
                          ),
                        ],
                      ),
                    )
                  else
                    ...provider.linkedPatients.map((link) => _PatientLinkTile(link: link)),
                ],
              ),
            ),
    );
  }
}

class _IncomingRequestCard extends StatelessWidget {
  final FamilyLinkRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _IncomingRequestCard({required this.request, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.relationshipLabel != null && request.relationshipLabel!.isNotEmpty
                  ? '${request.caregiverName} (${request.relationshipLabel}) يريد متابعة أدويتك'
                  : '${request.caregiverName} يريد متابعة أدويتك',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(DateTimeUtils.relativeDayLabel(request.requestedAt), style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: onReject, child: const Text('رفض'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: onApprove, child: const Text('قبول'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SentRequestTile extends StatelessWidget {
  final FamilyLinkRequest request;
  final VoidCallback onCancel;

  const _SentRequestTile({required this.request, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.hourglass_top_rounded, color: Colors.orange),
        title: Text(request.patientName),
        subtitle: const Text('بانتظار الموافقة'),
        trailing: TextButton(onPressed: onCancel, child: const Text('إلغاء')),
      ),
    );
  }
}

class _PatientLinkTile extends StatelessWidget {
  final CaregiverLink link;
  const _PatientLinkTile({required this.link});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (link.relationshipLabel != null && link.relationshipLabel!.isNotEmpty) link.relationshipLabel!,
      link.role == CaregiverRole.primary ? 'مرافق رئيسي' : 'مرافق',
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          child: const Icon(Icons.person_rounded),
        ),
        title: Text(link.patientName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PatientDetailPage(link: link)),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final CaregiverAlert alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: alert.read ? null : Colors.red.withValues(alpha: 0.06),
      child: ListTile(
        leading: const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
        title: Text(alert.message),
        subtitle: Text(alert.patientName),
        onTap: () => context.read<CaregiverProvider>().markAlertRead(alert),
      ),
    );
  }
}
