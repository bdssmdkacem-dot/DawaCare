import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../doses/domain/dose_engine.dart';
import '../providers/medication_provider.dart';
import '../widgets/medication_stock_badge.dart';
import 'add_edit_medication_page.dart';
import 'medication_detail_page.dart';
import 'medication_stock_detail_page.dart';

enum _MedicationFilter { all, lowStock, outOfStock, noStock }

class MedicationListPage extends StatefulWidget {
  const MedicationListPage({super.key});

  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  bool _loadedOnce = false;
  _MedicationFilter _filter = _MedicationFilter.all;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedOnce) return;
    _loadedOnce = true;
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId != null) {
      context.read<MedicationProvider>().load(userId);
    }
  }

  Future<void> _changeImage(Medication medication) async {
    final l = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text(l.cameraMedicine),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(l.galleryMedicine),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 82,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final ok = await context.read<MedicationProvider>().updateMedicationImage(
          medication,
          bytes,
        );
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<MedicationProvider>().error ?? l.unexpectedError,
        ),
      ),
    );
  }

  Future<void> _removeImage(Medication medication) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.removeMedicineImageTitle),
        content: Text(l.removeMedicineImageBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.deleteImage),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<MedicationProvider>().removeMedicationImage(medication);
  }

  Future<void> _openDetails(Medication medication) async {
    final provider = context.read<MedicationProvider>();
    final schedules = provider.schedulesByMedicationId[medication.id] ??
        const <MedicationSchedule>[];
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MedicationDetailPage(
          medication: medication,
          schedules: schedules,
        ),
      ),
    );
    if (!mounted || changed != true) return;
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId != null) await provider.load(userId);
  }

  Future<void> _openStockDetails(Medication medication) async {
    final provider = context.read<MedicationProvider>();
    final schedules = provider.schedulesByMedicationId[medication.id] ??
        const <MedicationSchedule>[];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationStockDetailPage(
          medication: medication,
          schedules: schedules,
        ),
      ),
    );
    if (!mounted) return;
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId != null) await provider.load(userId);
  }

  Future<void> _addStock(Medication medication) async {
    final controller = TextEditingController();
    final quantity = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          medication.stockEnabled
              ? 'إضافة مخزون ${medication.name}'
              : 'تفعيل عداد ${medication.name}',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: medication.stockEnabled
                ? 'الكمية المضافة'
                : 'الكمية الموجودة الآن',
            suffixText: _unitLabel(
              medication.stockEnabled
                  ? medication.stockUnit
                  : medication.dosageForm,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx).cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (value != null && value > 0) {
                Navigator.pop(ctx, value);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (quantity == null || !mounted) return;
    final ok = await context.read<MedicationProvider>().addMedicationStock(
          medication: medication,
          quantity: quantity,
        );
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<MedicationProvider>().error ?? 'تعذر تحديث المخزون',
        ),
      ),
    );
  }

  String _unitLabel(String? value) {
    switch (value) {
      case 'capsule':
      case 'كبسولة':
        return 'كبسولة';
      case 'tablet':
      case 'قرص':
        return 'قرص';
      case 'ml':
      case 'شراب':
        return 'مل';
      case 'drop':
      case 'قطرة':
        return 'قطرة';
      case 'injection':
      case 'حقنة':
        return 'حقنة';
      default:
        return 'وحدة';
    }
  }

  bool _matches(Medication medication) {
    final q = _query.trim().toLowerCase();
    final searchable = '${medication.name} ${medication.genericName ?? ''} '
        '${medication.strength ?? ''} ${medication.dosageForm ?? ''}'
        .toLowerCase();
    if (q.isNotEmpty && !searchable.contains(q)) return false;

    switch (_filter) {
      case _MedicationFilter.all:
        return true;
      case _MedicationFilter.lowStock:
        return medication.stockEnabled &&
            medication.stockQuantity > 0 &&
            medication.stockQuantity <= medication.lowStockThreshold;
      case _MedicationFilter.outOfStock:
        return medication.stockEnabled && medication.stockQuantity <= 0;
      case _MedicationFilter.noStock:
        return !medication.stockEnabled;
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
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddMedicationPage()),
          );
          if (!mounted) return;
          if (added == true && userId != null) {
            await medicationProvider.load(userId);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l.newMedicine),
      ),
      body: _buildBody(provider, l),
    );
  }

  Widget _buildBody(MedicationProvider provider, AppLocalizations l) {
    if (provider.isLoading && provider.medications.isEmpty) {
      return const LoadingIndicator();
    }
    if (provider.medications.isEmpty) {
      return EmptyState(
        icon: Icons.medication_outlined,
        title: l.noMedicinesYet,
        subtitle: l.addMedicineHint,
      );
    }

    final visible = provider.medications.where(_matches).toList();
    final low = provider.medications
        .where((m) =>
            m.stockEnabled &&
            m.stockQuantity > 0 &&
            m.stockQuantity <= m.lowStockThreshold)
        .length;
    final empty = provider.medications
        .where((m) => m.stockEnabled && m.stockQuantity <= 0)
        .length;

    return RefreshIndicator(
      onRefresh: () async {
        final userId = context.read<AuthProvider>().profile?.id;
        if (userId != null) await provider.load(userId);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          _MedicationOverview(
            total: provider.medications.length,
            low: low,
            empty: empty,
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'ابحث باسم الدواء أو التركيز أو الشكل',
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _query = ''),
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('الكل', _MedicationFilter.all,
                    provider.medications.length),
                const SizedBox(width: 8),
                _filterChip('مخزون منخفض', _MedicationFilter.lowStock, low),
                const SizedBox(width: 8),
                _filterChip('نفد المخزون', _MedicationFilter.outOfStock, empty),
                const SizedBox(width: 8),
                _filterChip(
                  'بدون تتبع',
                  _MedicationFilter.noStock,
                  provider.medications.where((m) => !m.stockEnabled).length,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 42),
                    const SizedBox(height: 10),
                    Text(
                      'لا توجد أدوية مطابقة',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    const Text('جرّب تغيير البحث أو الفلتر.'),
                  ],
                ),
              ),
            )
          else
            ...visible.map((med) {
              final schedules =
                  provider.schedulesByMedicationId[med.id] ??
                      const <MedicationSchedule>[];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MedicationTile(
                  medication: med,
                  schedules: schedules,
                  imageUrlFuture:
                      provider.signedMedicationImageUrl(med.imageUrl),
                  onTap: () => _openDetails(med),
                  onChangeImage: () => _changeImage(med),
                  onRemoveImage: med.imageUrl == null
                      ? null
                      : () => _removeImage(med),
                  onDeactivate: () => _confirmDeactivate(med),
                  onAddStock: () => _addStock(med),
                  onStockDetails: () => _openStockDetails(med),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    _MedicationFilter filter,
    int count,
  ) {
    return FilterChip(
      label: Text('$label ($count)'),
      selected: _filter == filter,
      onSelected: (_) => setState(() => _filter = filter),
    );
  }

  Future<void> _confirmDeactivate(Medication medication) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deactivateMedicineTitle),
        content: Text(l.deactivateMedicineBody(medication.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.stop),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await context.read<MedicationProvider>().deactivate(medication);
  }
}

class _MedicationOverview extends StatelessWidget {
  final int total;
  final int low;
  final int empty;

  const _MedicationOverview({
    required this.total,
    required this.low,
    required this.empty,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _metric(
                context,
                Icons.medication_rounded,
                '$total',
                'الأدوية',
              ),
            ),
            _divider(context),
            Expanded(
              child: _metric(
                context,
                Icons.warning_amber_rounded,
                '$low',
                'منخفض',
              ),
            ),
            _divider(context),
            Expanded(
              child: _metric(
                context,
                Icons.error_outline_rounded,
                '$empty',
                'نفد',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 23),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Theme.of(context).dividerColor,
    );
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
  final VoidCallback onAddStock;
  final VoidCallback onStockDetails;

  const _MedicationTile({
    required this.medication,
    required this.schedules,
    required this.imageUrlFuture,
    required this.onTap,
    required this.onChangeImage,
    required this.onRemoveImage,
    required this.onDeactivate,
    required this.onAddStock,
    required this.onStockDetails,
  });

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<String?>(
                future: imageUrlFuture,
                builder: (context, snapshot) {
                  final image = snapshot.data;
                  return Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: image == null
                        ? const Icon(
                            Icons.medication_liquid_rounded,
                            color: AppColors.primary,
                            size: 32,
                          )
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.medication_liquid_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                  );
                },
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (medication.genericName != null &&
                        medication.genericName!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        medication.genericName!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        if (medication.strength != null &&
                            medication.strength!.trim().isNotEmpty)
                          _chip(medication.strength!.trim()),
                        if (medication.dosageForm != null &&
                            medication.dosageForm!.trim().isNotEmpty)
                          _chip(
                            l.dosageFormLabel(medication.dosageForm!.trim()),
                          ),
                        if (schedules.isNotEmpty)
                          _chip(_scheduleCountLabel(l, schedules.length)),
                      ],
                    ),
                    if (schedules.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...schedules.take(2).map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '• ${DoseEngine.describeSchedule(s)} · ${l.doseAmount}: ${s.doseAmount}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ),
                      if (schedules.length > 2)
                        Text(
                          '+ ${schedules.length - 2} ${_tr(context, 'جداول أخرى', 'more schedules', 'autres horaires')}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _periodLabel(context),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MedicationStockBadge(
                      medication: medication,
                      schedules: schedules,
                      onAdd: onAddStock,
                      onDetails: onStockDetails,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: l.medicines,
                onSelected: (value) {
                  switch (value) {
                    case 'change_image':
                      onChangeImage();
                      break;
                    case 'remove_image':
                      onRemoveImage?.call();
                      break;
                    case 'deactivate':
                      onDeactivate();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'change_image',
                    child: Text(l.changeMedicineImage),
                  ),
                  if (onRemoveImage != null)
                    PopupMenuItem<String>(
                      value: 'remove_image',
                      child: Text(l.deleteMedicineImage),
                    ),
                  PopupMenuItem<String>(
                    value: 'deactivate',
                    child: Text(l.deactivateMedicine),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _scheduleCountLabel(AppLocalizations l, int count) {
    if (l.locale.languageCode == 'en') {
      return '$count schedule${count == 1 ? '' : 's'}';
    }
    if (l.locale.languageCode == 'fr') {
      return '$count horaire${count == 1 ? '' : 's'}';
    }
    return '$count ${count == 1 ? 'جدول' : 'جداول'}';
  }

  String _periodLabel(BuildContext context) {
    final l = AppLocalizations.of(context);
    final start = DateTimeUtils.formatShortDate(medication.startDate);
    final end = medication.endDate == null
        ? '—'
        : DateTimeUtils.formatShortDate(medication.endDate!);
    if (l.locale.languageCode == 'en') return 'Treatment: $start → $end';
    if (l.locale.languageCode == 'fr') return 'Traitement : $start → $end';
    return 'العلاج: $start ← $end';
  }

  String _tr(BuildContext context, String ar, String en, String fr) {
    switch (AppLocalizations.of(context).locale.languageCode) {
      case 'en':
        return en;
      case 'fr':
        return fr;
      default:
        return ar;
    }
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}
