import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../providers/medication_provider.dart';
import '../widgets/medication_stock_history.dart';
import 'edit_medication_page.dart';

class MedicationStockDetailPage extends StatefulWidget {
  final Medication medication;
  final List<MedicationSchedule> schedules;

  const MedicationStockDetailPage({
    super.key,
    required this.medication,
    required this.schedules,
  });

  @override
  State<MedicationStockDetailPage> createState() =>
      _MedicationStockDetailPageState();
}

class _MedicationStockDetailPageState extends State<MedicationStockDetailPage> {
  late Medication _medication;
  late List<MedicationSchedule> _schedules;
  bool _loading = true;
  String? _error;
  final GlobalKey<MedicationStockHistoryState> _historyKey =
      GlobalKey<MedicationStockHistoryState>();

  @override
  void initState() {
    super.initState();
    _medication = widget.medication;
    _schedules = widget.schedules;
    _load();
  }

  Future<void> _load() async {
    try {
      final provider = context.read<MedicationProvider>();
      final schedules = await provider.fetchSchedules(_medication.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _schedules = schedules;
        _loading = false;
        _error = null;
      });
      _historyKey.currentState?.refresh();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل بيانات المخزون.';
      });
    }
  }

  double _calculateDailyConsumption() {
    var total = 0.0;
    for (final s in _schedules) {
      final dose = _extractNumber(s.doseAmount);
      if (dose <= 0) {
        continue;
      }
      switch (s.type) {
        case ScheduleType.daily:
          total += dose;
        case ScheduleType.weekly:
          total += dose / 7;
        case ScheduleType.specificDays:
          if (s.daysOfWeek.isNotEmpty) {
            total += dose * s.daysOfWeek.length / 7;
          }
        case ScheduleType.interval:
          final days = s.intervalDays ?? 1;
          total += dose / (days <= 0 ? 1 : days);
        case ScheduleType.once:
          total += dose / 30;
        case ScheduleType.prn:
          break;
      }
    }
    return total;
  }

  double _extractNumber(String value) {
    final match = RegExp(r'[-+]?\d+(?:[.,]\d+)?').firstMatch(value.trim());
    return match == null
        ? 0
        : double.tryParse(match.group(0)!.replaceAll(',', '.')) ?? 0;
  }

  String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

  String _stockStatus() {
    if (_medication.stockQuantity <= 0) {
      return 'منتهي';
    }
    if (_medication.stockQuantity <= _medication.lowStockThreshold) {
      return 'منخفض';
    }
    return 'جيد';
  }

  Future<void> _editMedication() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditMedicationPage(
          medication: _medication,
          schedules: _schedules,
        ),
      ),
    );
    if (!mounted || changed != true) {
      return;
    }
    final provider = context.read<MedicationProvider>();
    final updated = provider.medications
        .where((m) => m.id == _medication.id)
        .firstOrNull;
    if (updated != null) {
      setState(() => _medication = updated);
    }
    await _load();
  }

  Future<void> _addStock() async {
    final c = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مخزون'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'الكمية (${_medication.stockUnit})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(c.text.trim().replaceAll(',', '.')),
            ),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    c.dispose();
    if (!mounted || result == null || result <= 0) {
      return;
    }
    final provider = context.read<MedicationProvider>();
    final ok = await provider.addMedicationStock(
      medication: _medication,
      quantity: result,
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      final updated = provider.medications
          .where((m) => m.id == _medication.id)
          .firstOrNull;
      if (updated != null) {
        setState(() => _medication = updated);
      }
      _historyKey.currentState?.refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'تعذر تحديث المخزون')),
      );
    }
  }

  Future<void> _editSettings() async {
    final package = TextEditingController(
      text: _medication.packageQuantity?.toString() ?? '',
    );
    final threshold = TextEditingController(
      text: _medication.lowStockThreshold.toString(),
    );
    var unit = _medication.stockUnit;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إعدادات المخزون'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'الوحدة'),
                items: const [
                  DropdownMenuItem(value: 'unit', child: Text('وحدة')),
                  DropdownMenuItem(value: 'tablet', child: Text('قرص')),
                  DropdownMenuItem(value: 'capsule', child: Text('كبسولة')),
                  DropdownMenuItem(value: 'ml', child: Text('مل')),
                  DropdownMenuItem(value: 'drop', child: Text('قطرة')),
                  DropdownMenuItem(value: 'injection', child: Text('حقنة')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => unit = v);
                  }
                },
              ),
              TextField(
                controller: package,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'كمية العبوة'),
              ),
              TextField(
                controller: threshold,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration:
                    const InputDecoration(labelText: 'حد المخزون المنخفض'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    final p = double.tryParse(package.text.trim().replaceAll(',', '.'));
    final t = double.tryParse(threshold.text.trim().replaceAll(',', '.'));
    package.dispose();
    threshold.dispose();
    if (result != true || !mounted || t == null || t < 0) {
      return;
    }
    final provider = context.read<MedicationProvider>();
    final ok = await provider.updateMedicationStockSettings(
      medication: _medication,
      unit: unit,
      packageQuantity: p,
      threshold: t,
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      final updated = provider.medications
          .where((m) => m.id == _medication.id)
          .firstOrNull;
      if (updated != null) {
        setState(() => _medication = updated);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final daily = _calculateDailyConsumption();
    final daysRemaining = daily > 0
        ? _medication.stockQuantity / daily
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_medication.name),
        actions: [
          IconButton(
            tooltip: 'تعديل الدواء',
            onPressed: _editMedication,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'المخزون الحالي',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Chip(label: Text(_stockStatus())),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${_formatNumber(_medication.stockQuantity)} ${_medication.stockUnit}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 12),
                              _InfoRow(
                                label: 'حد المخزون المنخفض',
                                value:
                                    '${_formatNumber(_medication.lowStockThreshold)} ${_medication.stockUnit}',
                              ),
                              if (_medication.packageQuantity != null)
                                _InfoRow(
                                  label: 'كمية العبوة',
                                  value:
                                      '${_formatNumber(_medication.packageQuantity!)} ${_medication.stockUnit}',
                                ),
                              _InfoRow(
                                label: 'الاستهلاك اليومي المتوقع',
                                value: daily > 0
                                    ? '${_formatNumber(daily)} ${_medication.stockUnit}'
                                    : 'غير متاح',
                              ),
                              if (daysRemaining != null)
                                _InfoRow(
                                  label: 'الأيام المتبقية تقديريًا',
                                  value: _formatNumber(daysRemaining),
                                ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _addStock,
                                      icon: const Icon(Icons.add),
                                      label: const Text('إضافة مخزون'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _editSettings,
                                      icon: const Icon(Icons.settings),
                                      label: const Text('الإعدادات'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      MedicationStockHistory(
                        key: _historyKey,
                        medicationId: _medication.id,
                        unit: _medication.stockUnit,
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Flexible(child: Text(value, textAlign: TextAlign.end)),
          ],
        ),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
