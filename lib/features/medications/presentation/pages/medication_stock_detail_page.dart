import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../providers/medication_provider.dart';

class MedicationStockDetailPage extends StatefulWidget {
  final Medication medication;

  const MedicationStockDetailPage({super.key, required this.medication});

  @override
  State<MedicationStockDetailPage> createState() => _MedicationStockDetailPageState();
}

class _MedicationStockDetailPageState extends State<MedicationStockDetailPage> {
  late Medication _medication;
  List<MedicationSchedule> _schedules = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _medication = widget.medication;
    _load();
  }

  Future<void> _load() async {
    try {
      final provider = context.read<MedicationProvider>();
      final schedules = await provider.fetchSchedules(_medication.id);
      if (!mounted) return;
      setState(() {
        _schedules = schedules;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل بيانات المخزون.';
      });
    }
  }

  double _calculateDailyConsumption() {
    var total = 0.0;
    for (final schedule in _schedules) {
      final dose = _extractNumber(schedule.doseAmount);
      if (dose <= 0) continue;
      switch (schedule.type.toLowerCase()) {
        case 'daily':
          total += dose;
          break;
        case 'weekly':
          total += dose / 7;
          break;
        case 'monthly':
          total += dose / 30;
          break;
        case 'interval':
          final days = schedule.intervalDays <= 0 ? 1 : schedule.intervalDays;
          total += dose / days;
          break;
        default:
          total += dose;
      }
    }
    return total;
  }

  double _extractNumber(String value) {
    final match = RegExp(r'[-+]?\d+(?:[.,]\d+)?').firstMatch(value.trim());
    if (match == null) return 0;
    return double.tryParse(match.group(0)!.replaceAll(',', '.')) ?? 0;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  String _stockStatus() {
    final quantity = _medication.stockQuantity;
    final threshold = _medication.lowStockThreshold;
    if (quantity <= 0) return 'منتهي';
    if (quantity <= threshold) return 'منخفض';
    return 'جيد';
  }

  Future<void> _addStock() async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مخزون'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'الكمية (${_medication.stockUnit})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              Navigator.pop(ctx, value);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || result == null || result <= 0) return;
    final provider = context.read<MedicationProvider>();
    final ok = await provider.addMedicationStock(medication: _medication, quantity: result);
    if (!mounted) return;
    if (ok) {
      final updated = provider.medications.where((m) => m.id == _medication.id).firstOrNull;
      if (updated != null) setState(() => _medication = updated);
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
          content: SingleChildScrollView(
            child: Column(
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
                  onChanged: (value) {
                    if (value != null) setDialogState(() => unit = value);
                  },
                ),
                TextField(
                  controller: package,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'كمية العبوة'),
                ),
                TextField(
                  controller: threshold,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'حد المخزون المنخفض'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );

    final packageValue = double.tryParse(package.text.trim().replaceAll(',', '.'));
    final thresholdValue = double.tryParse(threshold.text.trim().replaceAll(',', '.'));
    package.dispose();
    threshold.dispose();

    if (result != true || !mounted || thresholdValue == null || thresholdValue < 0) return;

    final provider = context.read<MedicationProvider>();
    final ok = await provider.updateMedicationStockSettings(
      medication: _medication,
      unit: unit,
      packageQuantity: packageValue,
      threshold: thresholdValue,
    );
    if (!mounted) return;
    if (ok) {
      final updated = provider.medications.where((m) => m.id == _medication.id).firstOrNull;
      if (updated != null) setState(() => _medication = updated);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ إعدادات المخزون')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final daily = _calculateDailyConsumption();
    final daysRemaining = daily > 0 ? _medication.stockQuantity / daily : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_medication.name),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('المخزون الحالي', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Chip(label: Text(_stockStatus())),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${_formatNumber(_medication.stockQuantity)} ${_medication.stockUnit}',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 12),
                              _InfoRow(label: 'حد المخزون المنخفض', value: '${_formatNumber(_medication.lowStockThreshold)} ${_medication.stockUnit}'),
                              if (_medication.packageQuantity != null)
                                _InfoRow(label: 'كمية العبوة', value: '${_formatNumber(_medication.packageQuantity!)} ${_medication.stockUnit}'),
                              _InfoRow(label: 'الاستهلاك اليومي المتوقع', value: daily > 0 ? '${_formatNumber(daily)} ${_medication.stockUnit}' : 'غير متاح'),
                              if (daysRemaining != null)
                                _InfoRow(label: 'الأيام المتبقية تقديريًا', value: _formatNumber(daysRemaining)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: FilledButton.icon(onPressed: _addStock, icon: const Icon(Icons.add), label: const Text('إضافة مخزون'))),
                                  const SizedBox(width: 8),
                                  Expanded(child: OutlinedButton.icon(onPressed: _editSettings, icon: const Icon(Icons.settings), label: const Text('الإعدادات'))),
                                ],
                              ),
                            ],
                          ),
                        ),
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
  Widget build(BuildContext context) {
    return Padding(
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
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
