import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../models/caregiver_alert.dart';
import '../../../../models/caregiver_link.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/caregiver_provider.dart';
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

  Future<void> _openLinkDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ربط فرد من العائلة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اطلب من الشخص رمز العائلة الخاص به من تبويب الإعدادات، ثم أدخله هنا:'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(hintText: 'مثال: K7F3QX'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ربط')),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty && mounted) {
      final provider = context.read<CaregiverProvider>();
      final patientName = await provider.linkByFamilyCode(controller.text.trim());
      if (!mounted) return;
      if (patientName != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم ربط $patientName بنجاح')));
        final userId = context.read<AuthProvider>().profile?.id;
        if (userId != null) await provider.load(userId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error ?? 'تعذّر الربط')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CaregiverProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('العائلة')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openLinkDialog,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('ربط فرد'),
      ),
      body: provider.isLoading && provider.linkedPatients.isEmpty
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: () async {
                final userId = context.read<AuthProvider>().profile?.id;
                if (userId != null) await provider.load(userId);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
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
                            width: 200,
                            child: PrimaryButton(label: 'ربط فرد الآن', onPressed: _openLinkDialog),
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

class _PatientLinkTile extends StatelessWidget {
  final CaregiverLink link;
  const _PatientLinkTile({required this.link});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          child: const Icon(Icons.person_rounded),
        ),
        title: Text(link.patientName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(link.role == CaregiverRole.primary ? 'مرافق رئيسي' : 'مرافق'),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientDetailPage(link: link))),
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
