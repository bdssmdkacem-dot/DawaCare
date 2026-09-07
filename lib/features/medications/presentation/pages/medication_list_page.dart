import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/medication_provider.dart';
import '../widgets/medication_stock_badge.dart';
import 'add_medication_page.dart';

class MedicationListPage extends StatefulWidget {
  const MedicationListPage({super.key});

  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().profile?.id;
      if (userId != null) context.read<MedicationProvider>().load(userId);
    });
  }

  Future<void> _addStock(Medication medication) async {
    final controller = TextEditingController();
    final quantity = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(medication.stockEnabled ? 'إضافة مخزون ${medication.name}' : 'تفعيل عداد ${medication.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: medication.stockEnabled ? 'الكمية المضافة' : 'الكمية الموجودة الآن',
            suffixText: _unitLabel(medication.stockEnabled ? (medication.stockUnit ?? medication.dosageForm) : medication.dosageForm),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(ctx).cancel)),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (value != null && value > 0) Navigator.pop(ctx, value);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (quantity == null || !mounted) return;
    final ok = await context.read<MedicationProvider>().addMedicationStock(medication: medication, quantity: quantity);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<MedicationProvider>().error ?? 'تعذر تحديث المخزون')));
  }

  String _unitLabel(String value) {
    switch (value) {
      case 'capsule':
      case 'كبسولة': return 'كبسولة';
      case 'tablet':
      case 'قرص': return 'قرص';
      case 'ml':
      case 'شراب': return 'مل';
      case 'drop':
      case 'قطرة': return 'قطرة';
      case 'injection':
      case 'حقنة': return 'حقنة';
      default: return 'وحدة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<MedicationProvider>();
    final userId = context.read<AuthProvider>().profile?.id;
    return Scaffold(
      appBar: AppBar(title: Text(l.medicines)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final medicationProvider = context.read<MedicationProvider>();
          final added = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AddMedicationPage()));
          if (!mounted) return;
          if (added == true && userId != null) await medicationProvider.load(userId);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l.newMedicine),
      ),
      body: _buildBody(provider, l),
    );
  }

  Widget _buildBody(MedicationProvider provider, AppLocalizations l) {
    if (provider.isLoading && provider.medications.isEmpty) return const LoadingIndicator();
    if (provider.medications.isEmpty) return EmptyState(icon: Icons.medication_outlined, title: l.noMedicinesYet, subtitle: l.addMedicineHint);

    return RefreshIndicator(
      onRefresh: () async {
        final userId = context.read<AuthProvider>().profile?.id;
        if (userId != null) await provider.load(userId);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: provider.medications.length,
        itemBuilder: (context, index) {
          final medication = provider.medications[index];
          final schedules = provider.schedules.where((s) => s.medicationId == medication.id).toList();
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.medication_outlined)),
                    title: Text(medication.name),
                    subtitle: Text(medication.instructions ?? ''),
                  ),
                  MedicationStockBadge(
                    medication: medication,
                    schedules: schedules,
                    onAdd: () => _addStock(medication),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
