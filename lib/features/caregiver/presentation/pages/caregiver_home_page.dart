import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../models/caregiver_alert.dart';
import '../../../../models/caregiver_link.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/caregiver_repository.dart';
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
        child: SelectableText(code.code),
      ),
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
            Text(
              l.familyMembers,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (provider.linkedPatients.isEmpty)
              _EmptyState(onGenerateCode: _openGenerateCodeSheet)
            else
              ...provider.linkedPatients.map(
                (link) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
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
  const _EmptyState({required this.onGenerateCode});

  final VoidCallback onGenerateCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Icon(Icons.people_outline, size: 64),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onGenerateCode,
          child: const Text('Generate link code'),
        ),
      ],
    );
  }
}
