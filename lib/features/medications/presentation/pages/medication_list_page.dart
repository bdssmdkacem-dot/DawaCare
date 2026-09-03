import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/medication.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../doses/domain/dose_engine.dart';
import '../providers/medication_provider.dart';
import 'add_edit_medication_page.dart';

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
    if (provider.medications.isEmpty) {
      return EmptyState(icon: Icons.medication_outlined, title: l.noMedicinesYet, subtitle: l.addMedicineHint);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      itemCount: provider.medications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final med = provider.medications[index];
        final schedules = provider.schedulesByMedicationId[med.id] ?? const [];
        return _MedicationTile(
          medication: med,
          scheduleLabel: schedules.isNotEmpty ? DoseEngine.describeSchedule(schedules.first) : null,
          imageUrlFuture: provider.signedMedicationImageUrl(med.imageUrl),
          onChangeImage: () => _changeImage(med),
          onRemoveImage: med.imageUrl == null ? null : () => _removeImage(med),
          onDeactivate: () => _confirmDeactivate(med),
        );
      },
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
  final String? scheduleLabel;
  final Future<String?> imageUrlFuture;
  final VoidCallback onChangeImage;
  final VoidCallback? onRemoveImage;
  final VoidCallback onDeactivate;

  const _MedicationTile({required this.medication, required this.scheduleLabel, required this.imageUrlFuture, required this.onChangeImage, required this.onRemoveImage, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final subtitleParts = <String>[
      if (medication.strength != null && medication.strength!.isNotEmpty) medication.strength!,
      if (scheduleLabel != null && scheduleLabel!.isNotEmpty) scheduleLabel!,
    ];
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(children: [
            FutureBuilder<String?>(
              future: imageUrlFuture,
              builder: (context, snapshot) {
                final image = snapshot.data;
                return Container(
                  width: 62, height: 62,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: image == null
                      ? const Icon(Icons.medication_liquid_rounded, color: AppColors.primary, size: 30)
                      : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.medication_liquid_rounded, color: AppColors.primary, size: 30)),
                );
              },
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(medication.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (subtitleParts.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(subtitleParts.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ],
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
}
