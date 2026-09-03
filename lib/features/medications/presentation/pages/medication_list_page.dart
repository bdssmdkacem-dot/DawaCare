import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../doses/domain/dose_engine.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../providers/medication_provider.dart';
import 'add_edit_medication_page.dart';
import 'medication_detail_page.dart';

class MedicationListPage extends StatefulWidget {
  const MedicationListPage({super.key});
  @override State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      final userId = context.read<AuthProvider>().profile?.id;
      if (userId != null) context.read<MedicationProvider>().load(userId);
    }
  }

  Future<void> _changeImage(Medication medication) async {
    final l = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.camera_alt_rounded), title: Text(l.cameraMedicine), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_rounded), title: Text(l.galleryMedicine), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
      ])),
    );
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 82);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final ok = await context.read<MedicationProvider>().updateMedicationImage(medication, bytes);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<MedicationProvider>().error ?? l.unexpectedError)));
  }

  Future<void> _removeImage(Medication medication) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.removeMedicineImageTitle),
      content: Text(l.removeMedicineImageBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.deleteImage)),
      ],
    ));
    if (confirmed != true || !mounted) return;
    await context.read<MedicationProvider>().removeMedicationImage(medication);
  }

  Future<void> _openDetails(Medication medication) async {
    final provider = context.read<MedicationProvider>();
    final schedules = provider.schedulesByMedicationId[medication.id] ?? const <MedicationSchedule>[];
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => MedicationDetailPage(medication: medication, schedules: schedules)));
    if (!mounted || changed != true) return;
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId != null) await provider.load(userId);
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
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        itemCount: provider.medications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final med = provider.medications[index];
          final schedules = provider.schedulesByMedicationId[med.id] ?? const <MedicationSchedule>[];
          return _MedicationTile(
            medication: med,
            schedules: schedules,
            imageUrlFuture: provider.signedMedicationImageUrl(med.imageUrl),
            onTap: () => _openDetails(med),
            onChangeImage: () => _changeImage(med),
            onRemoveImage: med.imageUrl == null ? null : () => _removeImage(med),
            onDeactivate: () => _confirmDeactivate(med),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeactivate(Medication medication) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.deactivateMedicineTitle),
      content: Text(l.deactivateMedicineBody(medication.name)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.stop)),
      ],
    ));
    if (!mounted || confirmed != true) return;
    await context.read<MedicationProvider>().deactivate(medication);
  }
}

class _MedicationTile extends StatelessWidget {
  final Medication medication;
  final List<MedicationSchedule> schedules;
  final Future<String?> imageUrlFuture;
  final VoidCallback onTap;
  final VoidCallback onChangeImage;
  final VoidCallback? onRemoveImage;
  final VoidCallback onDeactivate;

  const _MedicationTile({required this.medication, required this.schedules, required this.imageUrlFuture, required this.onTap, required this.onChangeImage, required this.onRemoveImage, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FutureBuilder<String?>(
              future: imageUrlFuture,
              builder: (context, snapshot) {
                final image = snapshot.data;
                return Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(17)),
                  clipBehavior: Clip.antiAlias,
                  child: image == null ? const Icon(Icons.medication_liquid_rounded, color: AppColors.primary, size: 32) : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.medication_liquid_rounded, color: AppColors.primary, size: 32)),
                );
              },
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(medication.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              if (medication.genericName != null && medication.genericName!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(medication.genericName!.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 5),
              Wrap(spacing: 5, runSpacing: 4, children: [
                if (medication.strength != null && medication.strength!.trim().isNotEmpty) _chip(medication.strength!.trim()),
                if (medication.dosageForm != null && medication.dosageForm!.trim().isNotEmpty) _chip(l.dosageFormLabel(medication.dosageForm!.trim())),
                if (schedules.isNotEmpty) _chip(_scheduleCountLabel(l, schedules.length)),
              ]),
              if (schedules.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...schedules.take(2).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• ${DoseEngine.describeSchedule(s)} · ${l.doseAmount}: ${s.doseAmount}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                )),
                if (schedules.length > 2) Text('+ ${schedules.length - 2} ${_tr(context, 'جداول أخرى', 'more schedules', 'autres horaires')}', style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 4),
              Text(_periodLabel(context), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ])),
            PopupMenuButton<String>(
              tooltip: l.medicines,
              onSelected: (value) {
                switch (value) {
                  case 'change_image': onChangeImage(); break;
                  case 'remove_image': onRemoveImage?.call(); break;
                  case 'deactivate': onDeactivate(); break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(value: 'change_image', child: Text(l.changeMedicineImage)),
                if (onRemoveImage != null) PopupMenuItem<String>(value: 'remove_image', child: Text(l.deleteMedicineImage)),
                PopupMenuItem<String>(value: 'deactivate', child: Text(l.deactivateMedicine)),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  String _scheduleCountLabel(AppLocalizations l, int count) {
    if (l.locale.languageCode == 'en') return '$count schedule${count == 1 ? '' : 's'}';
    if (l.locale.languageCode == 'fr') return '$count horaire${count == 1 ? '' : 's'}';
    return '$count ${count == 1 ? 'جدول' : 'جداول'}';
  }

  String _periodLabel(BuildContext context) {
    final l = AppLocalizations.of(context);
    final start = DateTimeUtils.formatShortDate(medication.startDate);
    final end = medication.endDate == null ? '—' : DateTimeUtils.formatShortDate(medication.endDate!);
    if (l.locale.languageCode == 'en') return 'Treatment: $start → $end';
    if (l.locale.languageCode == 'fr') return 'Traitement : $start → $end';
    return 'العلاج: $start ← $end';
  }

  String _tr(BuildContext context, String ar, String en, String fr) {
    switch (AppLocalizations.of(context).locale.languageCode) {
      case 'en': return en;
      case 'fr': return fr;
      default: return ar;
    }
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(18)),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
  );
}
