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
import '../../domain/stock_intelligence.dart';
import '../providers/medication_provider.dart';
import '../widgets/medication_stock_badge.dart';
import 'add_edit_medication_page.dart';
import 'edit_medication_page.dart';
import 'medication_detail_page.dart';
import 'medication_stock_detail_page.dart';

enum _MedicationFilter { all, attention, lowStock, outOfStock, endingSoon, noStock }
enum _MedicationSort { nextDose, name, stock, daysRemaining }

class MedicationListPage extends StatefulWidget {
  const MedicationListPage({super.key});

  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  bool _loadedOnce = false;
  _MedicationFilter _filter = _MedicationFilter.all;
  _MedicationSort _sort = _MedicationSort.nextDose;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedOnce) return;
    _loadedOnce = true;
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId != null) context.read<MedicationProvider>().load(userId);
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
    final ok = await context.read<MedicationProvider>().updateMedicationImage(medication, bytes);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.read<MedicationProvider>().error ?? l.unexpectedError)),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.deleteImage)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<MedicationProvider>().removeMedicationImage(medication);
  }

  Future<void> _openDetails(Medication medication) async {
    final provider = context.read<MedicationProvider>();
    final schedules = provider.schedulesByMedicationId[medication.id] ?? const <MedicationSchedule>[];
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MedicationDetailPage(medication: medication, schedules: schedules)),
    );
    if (!mounted || changed != true) return;
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId != null) await provider.load(userId);
  }

  Future<void> _editMedication(Medication medication) async {
    final provider = context.read<MedicationProvider>();
    final schedules = provider.schedulesByMedicationId[medication.id] ?? const <MedicationSchedule>[];
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditMedicationPage(medication: medication, schedules: schedules)),
    );
    if (!mounted || changed != true) return;
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId != null) await provider.load(userId);
  }

  Future<void> _openStockDetails(Medication medication) async {
    final provider = context.read<MedicationProvider>();
    final schedules = provider.schedulesByMedicationId[medication.id] ?? const <MedicationSchedule>[];
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MedicationStockDetailPage(medication: medication, schedules: schedules)),
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
        title: Text(medication.stockEnabled ? 'إضافة مخزون ${medication.name}' : 'تفعيل عداد ${medication.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: medication.stockEnabled ? 'الكمية المضافة' : 'الكمية الموجودة الآن',
            suffixText: _unitLabel(medication.stockEnabled ? medication.stockUnit : medication.dosageForm),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.read<MedicationProvider>().error ?? 'تعذر تحديث المخزون')),
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

  bool _matches(Medication medication, _MedicationInsights info) {
    final q = _query.trim().toLowerCase();
    final searchable = '${medication.name} ${medication.genericName ?? ''} ${medication.strength ?? ''} ${medication.dosageForm ?? ''}'.toLowerCase();
    if (q.isNotEmpty && !searchable.contains(q)) return false;
    switch (_filter) {
      case _MedicationFilter.all: return true;
      case _MedicationFilter.attention: return info.status != _MedicationStatus.active;
      case _MedicationFilter.lowStock: return info.status == _MedicationStatus.lowStock;
      case _MedicationFilter.outOfStock: return info.status == _MedicationStatus.outOfStock;
      case _MedicationFilter.endingSoon: return info.status == _MedicationStatus.endingSoon;
      case _MedicationFilter.noStock: return !medication.stockEnabled;
    }
  }

  List<_MedicationItem> _buildItems(MedicationProvider provider) {
    final now = DateTime.now();
    final items = provider.medications.map((medication) {
      final schedules = provider.schedulesByMedicationId[medication.id] ?? const <MedicationSchedule>[];
      return _MedicationItem(medication: medication, schedules: schedules, info: _MedicationInsights.from(medication, schedules, now));
    }).where((item) => _matches(item.medication, item.info)).toList();

    items.sort((a, b) {
      switch (_sort) {
        case _MedicationSort.name: return a.medication.name.toLowerCase().compareTo(b.medication.name.toLowerCase());
        case _MedicationSort.stock: return b.medication.stockQuantity.compareTo(a.medication.stockQuantity);
        case _MedicationSort.daysRemaining: return (a.info.daysRemaining ?? double.infinity).compareTo(b.info.daysRemaining ?? double.infinity);
        case _MedicationSort.nextDose: return (a.info.nextDose ?? DateTime(9999)).compareTo(b.info.nextDose ?? DateTime(9999));
      }
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<MedicationProvider>();
    final userId = context.read<AuthProvider>().profile?.id;
    final items = _buildItems(provider);
    final allItems = provider.medications.map((m) {
      final schedules = provider.schedulesByMedicationId[m.id] ?? const <MedicationSchedule>[];
      return _MedicationInsights.from(m, schedules, DateTime.now());
    }).toList();
    final low = allItems.where((i) => i.status == _MedicationStatus.lowStock).length;
    final out = allItems.where((i) => i.status == _MedicationStatus.outOfStock).length;
    final ending = allItems.where((i) => i.status == _MedicationStatus.endingSoon).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.medicines),
        actions: [
          PopupMenuButton<_MedicationSort>(
            tooltip: 'ترتيب',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _MedicationSort.nextDose, child: Text('أقرب جرعة')),
              PopupMenuItem(value: _MedicationSort.name, child: Text('الاسم')),
              PopupMenuItem(value: _MedicationSort.stock, child: Text('المخزون')),
              PopupMenuItem(value: _MedicationSort.daysRemaining, child: Text('الأيام المتبقية')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AddMedicationPage()));
          if (!mounted || added != true || userId == null) return;
          await provider.load(userId);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l.newMedicine),
      ),
      body: _buildBody(provider, items, total: provider.medications.length, low: low, out: out, ending: ending),
    );
  }

  Widget _buildBody(MedicationProvider provider, List<_MedicationItem> items, {required int total, required int low, required int out, required int ending}) {
    if (provider.isLoading && provider.medications.isEmpty) return const LoadingIndicator();
    if (provider.medications.isEmpty) {
      final l = AppLocalizations.of(context);
      return EmptyState(icon: Icons.medication_outlined, title: l.noMedicinesYet, subtitle: l.addMedicineHint);
    }

    final userId = context.read<AuthProvider>().profile?.id;
    return RefreshIndicator(
      onRefresh: () async { if (userId != null) await provider.load(userId); },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          _SmartOverview(total: total, low: low, out: out, ending: ending),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'ابحث باسم الدواء أو التركيز أو الشكل',
              suffixIcon: _query.isEmpty ? null : IconButton(onPressed: () => setState(() => _query = ''), icon: const Icon(Icons.clear_rounded)),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip('الكل', _MedicationFilter.all, total),
              const SizedBox(width: 8),
              _filterChip('يحتاج انتباه', _MedicationFilter.attention, low + out + ending),
              const SizedBox(width: 8),
              _filterChip('منخفض', _MedicationFilter.lowStock, low),
              const SizedBox(width: 8),
              _filterChip('نفد', _MedicationFilter.outOfStock, out),
              const SizedBox(width: 8),
              _filterChip('ينتهي قريبًا', _MedicationFilter.endingSoon, ending),
              const SizedBox(width: 8),
              _filterChip('بدون تتبع', _MedicationFilter.noStock, provider.medications.where((m) => !m.stockEnabled).length),
            ]),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
              const Icon(Icons.search_off_rounded, size: 42),
              const SizedBox(height: 10),
              Text('لا توجد أدوية مطابقة', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('جرّب تغيير البحث أو الفلتر.'),
            ])))
          else
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SmartMedicationTile(
                item: item,
                imageUrlFuture: provider.signedMedicationImageUrl(item.medication.imageUrl),
                onTap: () => _openDetails(item.medication),
                onEdit: () => _editMedication(item.medication),
                onChangeImage: () => _changeImage(item.medication),
                onRemoveImage: item.medication.imageUrl == null ? null : () => _removeImage(item.medication),
                onDeactivate: () => _confirmDeactivate(item.medication),
                onAddStock: () => _addStock(item.medication),
                onStockDetails: () => _openStockDetails(item.medication),
              ),
            )),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _MedicationFilter filter, int count) => FilterChip(label: Text('$label ($count)'), selected: _filter == filter, onSelected: (_) => setState(() => _filter = filter));

  Future<void> _confirmDeactivate(Medication medication) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deactivateMedicineTitle),
        content: Text(l.deactivateMedicineBody(medication.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.stop)),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await context.read<MedicationProvider>().deactivate(medication);
  }
}

class _MedicationItem {
  final Medication medication;
  final List<MedicationSchedule> schedules;
  final _MedicationInsights info;
  const _MedicationItem({required this.medication, required this.schedules, required this.info});
}

enum _MedicationStatus { active, lowStock, outOfStock, endingSoon }

class _MedicationInsights {
  final DateTime? nextDose;
  final double? daysRemaining;
  final double dailyConsumption;
  final _MedicationStatus status;

  const _MedicationInsights({required this.nextDose, required this.daysRemaining, required this.dailyConsumption, required this.status});

  factory _MedicationInsights.from(Medication medication, List<MedicationSchedule> schedules, DateTime now) {
    DateTime? next;
    final windowEnd = now.add(const Duration(days: 30));
    for (final schedule in schedules) {
      final occurrences = DoseEngine.computeOccurrences(schedule: schedule, windowStart: now, windowEnd: windowEnd);
      for (final occurrence in occurrences) {
        if (!occurrence.isBefore(now) && (next == null || occurrence.isBefore(next))) next = occurrence;
      }
    }

    final daily = StockIntelligence.dailyConsumption(medication: medication, schedules: schedules);
    final daysRemaining = StockIntelligence.daysRemaining(medication: medication, schedules: schedules);
    final status = !medication.active
        ? _MedicationStatus.endingSoon
        : StockIntelligence.isOutOfStock(medication)
            ? _MedicationStatus.outOfStock
            : StockIntelligence.isLowStock(medication)
                ? _MedicationStatus.lowStock
                : medication.endDate != null && medication.endDate!.difference(now).inDays <= 7
                    ? _MedicationStatus.endingSoon
                    : _MedicationStatus.active;

    return _MedicationInsights(nextDose: next, daysRemaining: daysRemaining, dailyConsumption: daily, status: status);
  }
}

class _SmartOverview extends StatelessWidget {
  final int total;
  final int low;
  final int out;
  final int ending;
  const _SmartOverview({required this.total, required this.low, required this.out, required this.ending});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Expanded(child: _metric(context, Icons.medication_rounded, '$total', 'الأدوية')),
        _divider(context),
        Expanded(child: _metric(context, Icons.warning_amber_rounded, '${low + out}', 'المخزون')),
        _divider(context),
        Expanded(child: _metric(context, Icons.event_busy_rounded, '$ending', 'ينتهي قريبًا')),
      ]),
    ));
  }

  Widget _metric(BuildContext context, IconData icon, String value, String label) => Column(children: [
    Icon(icon, color: AppColors.primary, size: 22),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
    Text(label, style: Theme.of(context).textTheme.bodySmall),
  ]);

  Widget _divider(BuildContext context) => Container(width: 1, height: 42, margin: const EdgeInsets.symmetric(horizontal: 4), color: Theme.of(context).dividerColor);
}

class _SmartMedicationTile extends StatelessWidget {
  final _MedicationItem item;
  final Future<String?> imageUrlFuture;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onChangeImage;
  final VoidCallback? onRemoveImage;
  final VoidCallback onDeactivate;
  final VoidCallback onAddStock;
  final VoidCallback onStockDetails;

  const _SmartMedicationTile({required this.item, required this.imageUrlFuture, required this.onTap, required this.onEdit, required this.onChangeImage, required this.onRemoveImage, required this.onDeactivate, required this.onAddStock, required this.onStockDetails});

  @override
  Widget build(BuildContext context) {
    final medication = item.medication;
    final info = item.info;
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Card(child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FutureBuilder<String?>(
              future: imageUrlFuture,
              builder: (context, snapshot) {
                final image = snapshot.data;
                return Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: image == null
                      ? const Icon(Icons.medication_liquid_rounded, color: AppColors.primary, size: 30)
                      : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.medication_liquid_rounded, color: AppColors.primary, size: 30)),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(medication.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                _StatusChip(status: info.status),
              ]),
              if (medication.genericName != null && medication.genericName!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(medication.genericName!.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 5),
              Wrap(spacing: 5, runSpacing: 4, children: [
                if (medication.strength != null && medication.strength!.trim().isNotEmpty) _chip(medication.strength!.trim()),
                if (medication.dosageForm != null && medication.dosageForm!.trim().isNotEmpty) _chip(l.dosageFormLabel(medication.dosageForm!.trim())),
                if (item.schedules.isNotEmpty) _chip('${item.schedules.length} ${item.schedules.length == 1 ? 'جدول' : 'جداول'}'),
              ]),
            ])),
            PopupMenuButton<String>(
              tooltip: l.medicines,
              onSelected: (value) {
                switch (value) {
                  case 'edit': onEdit(); break;
                  case 'change_image': onChangeImage(); break;
                  case 'remove_image': onRemoveImage?.call(); break;
                  case 'deactivate': onDeactivate(); break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل الدواء')),
                PopupMenuItem(value: 'change_image', child: Text(l.changeMedicineImage)),
                if (onRemoveImage != null) PopupMenuItem(value: 'remove_image', child: Text(l.deleteMedicineImage)),
                PopupMenuItem(value: 'deactivate', child: Text(l.deactivateMedicine)),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          _NextDoseRow(nextDose: info.nextDose, schedules: item.schedules),
          const SizedBox(height: 8),
          _StockSummary(medication: medication, daysRemaining: info.daysRemaining, dailyConsumption: info.dailyConsumption, schedules: item.schedules, onAdd: onAddStock, onDetails: onStockDetails),
        ]),
      ),
    ));
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(18)),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
  );
}

class _NextDoseRow extends StatelessWidget {
  final DateTime? nextDose;
  final List<MedicationSchedule> schedules;
  const _NextDoseRow({required this.nextDose, required this.schedules});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (schedules.any((s) => s.type == ScheduleType.prn) && nextDose == null) {
      return Row(children: [const Icon(Icons.event_available_rounded, size: 19), const SizedBox(width: 7), Text('الجرعة التالية: عند الحاجة', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))]);
    }
    if (nextDose == null) return Row(children: [const Icon(Icons.event_busy_rounded, size: 19), const SizedBox(width: 7), Text('لا توجد جرعة قادمة', style: theme.textTheme.bodyMedium)]);
    final now = DateTime.now();
    final sameDay = DateTimeUtils.isSameDate(nextDose!, now);
    final date = DateTimeUtils.formatShortDate(nextDose!);
    final time = '${nextDose!.hour.toString().padLeft(2, '0')}:${nextDose!.minute.toString().padLeft(2, '0')}';
    final label = sameDay ? 'اليوم $time' : '$date · $time';
    return Row(children: [const Icon(Icons.schedule_rounded, size: 19), const SizedBox(width: 7), Expanded(child: Text('الجرعة التالية: $label', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)))]);
  }
}

class _StockSummary extends StatelessWidget {
  final Medication medication;
  final double? daysRemaining;
  final double dailyConsumption;
  final List<MedicationSchedule> schedules;
  final VoidCallback onAdd;
  final VoidCallback onDetails;
  const _StockSummary({required this.medication, required this.daysRemaining, required this.dailyConsumption, required this.schedules, required this.onAdd, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    if (!medication.stockEnabled) return MedicationStockBadge(medication: medication, schedules: schedules, onAdd: onAdd, onDetails: onDetails);
    final unit = _unit(medication.stockUnit);
    final stock = _format(medication.stockQuantity);
    final days = daysRemaining == null ? 'غير محسوب' : daysRemaining! <= 0 ? 'نفد' : daysRemaining! < 1 ? '< يوم' : '${daysRemaining!.floor()} يوم';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onDetails,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.inventory_2_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('المخزون: $stock $unit', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(dailyConsumption > 0 ? 'يكفي تقريبًا $days · استهلاك ${_format(dailyConsumption)}/يوم' : 'لا يمكن تقدير الاستهلاك اليومي', style: Theme.of(context).textTheme.bodySmall),
          ])),
          IconButton(tooltip: 'إضافة مخزون', onPressed: onAdd, icon: const Icon(Icons.add_box_outlined)),
        ]),
      ),
    );
  }

  String _unit(String value) {
    switch (value) {
      case 'tablet': return 'قرص';
      case 'capsule': return 'كبسولة';
      case 'ml': return 'مل';
      case 'drop': return 'قطرة';
      case 'injection': return 'حقنة';
      default: return 'وحدة';
    }
  }

  String _format(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}

class _StatusChip extends StatelessWidget {
  final _MedicationStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (status) {
      _MedicationStatus.active => ('نشط', Icons.check_circle_outline_rounded),
      _MedicationStatus.lowStock => ('مخزون منخفض', Icons.warning_amber_rounded),
      _MedicationStatus.outOfStock => ('نفد المخزون', Icons.error_outline_rounded),
      _MedicationStatus.endingSoon => ('ينتهي قريبًا', Icons.event_busy_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14), const SizedBox(width: 3), Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))]),
    );
  }
}
