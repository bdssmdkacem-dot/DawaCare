import 'package:flutter/material.dart'; import 'package:provider/provider.dart'; import '../../../../core/widgets/loading_indicator.dart'; import '../../../../models/medication.dart'; import '../../../auth/presentation/providers/auth_provider.dart'; import '../../../doses/domain/dose_engine.dart'; import '../providers/medication_provider.dart'; import 'add_edit_medication_page.dart';

class MedicationListPage extends StatefulWidget {
  const MedicationListPage({super.key});

  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_loadedOnce) {
      _loadedOnce = true;

      final userId = context.read<AuthProvider>().profile?.id;

      if (userId != null) {
        context.read<MedicationProvider>().load(userId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicationProvider>();
    final userId = context.read<AuthProvider>().profile?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('أدويتي')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const AddMedicationPage(),
            ),
          );

          if (!mounted) return;

          if (added == true && userId != null) {
            await context.read<MedicationProvider>().load(userId);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('دواء جديد'),
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(MedicationProvider provider) {
    if (provider.isLoading && provider.medications.isEmpty) {
      return const LoadingIndicator();
    }

    if (provider.medications.isEmpty) {
      return const EmptyState(
        icon: Icons.medication_outlined,
        title: 'لم تُضِف أي دواء بعد',
        subtitle: 'اضغط على "دواء جديد" لإضافة أول دواء وتحديد موعده',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: provider.medications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final med = provider.medications[index];
        final schedules =
            provider.schedulesByMedicationId[med.id] ?? const [];

        return _MedicationTile(
          medication: med,
          scheduleLabel: schedules.isNotEmpty
              ? DoseEngine.describeSchedule(schedules.first)
              : null,
          onDeactivate: () => _confirmDeactivate(med),
        );
      },
    );
  }

  Future<void> _confirmDeactivate(Medication medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إيقاف هذا الدواء؟'),
        content: Text(
          'لن تُنشأ جرعات جديدة لـ${medication.name}. يمكنك إضافته من جديد لاحقًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إيقاف'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      await context.read<MedicationProvider>().deactivate(medication);
    }
  }
}

class _MedicationTile extends StatelessWidget {
  final Medication medication;
  final String? scheduleLabel;
  final VoidCallback onDeactivate;

  const _MedicationTile({
    required this.medication,
    required this.scheduleLabel,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor:
              theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            Icons.medication_liquid_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          medication.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (medication.strength != null &&
                medication.strength!.isNotEmpty)
              medication.strength!,
            if (scheduleLabel != null) scheduleLabel!,
          ].join(' · '),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'deactivate') {
              onDeactivate();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'deactivate',
              child: Text('إيقاف الدواء'),
            ),
          ],
        ),
      ),
    );
  }
}
