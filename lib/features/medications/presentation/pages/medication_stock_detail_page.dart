import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/loading_indicator.dart';
import '../../data/medication_repository.dart';
import '../../models/medication.dart';
import '../../models/medication_schedule.dart';
import '../providers/medication_provider.dart';
import '../widgets/medication_stock_badge.dart';

class MedicationStockDetailPage extends StatefulWidget {
  const MedicationStockDetailPage({
    super.key,
    required this.medication,
    required this.schedules,
  });

  final Medication medication;
  final List<MedicationSchedule> schedules;

  @override
  State<MedicationStockDetailPage> createState() => _MedicationStockDetailPageState();
}

class _MedicationStockDetailPageState extends State<MedicationStockDetailPage> {
  late Medication _medication;
  late List<MedicationSchedule> _schedules;
  final _repository = MedicationRepository();
  bool _loadingHistory = true;
  List<Map<String, dynamic>> _transactions = const [];

  @override
  void initState() {
    super.initState();
    _medication = widget.medication;
    _schedules = widget.schedules;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final rows = await _repository.fetchStockTransactions(_medication.id);
      if (!mounted) return;
      setState(() {
        _transactions = rows;
        _loadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
    }
  }

  String _unitLabel(String? value) {
    switch (value) {
      case 'capsule':
        return 'كبسولة';
      case 'tablet':
        return 'قرص';
      case 'ml':
        return 'مل';
      case 'drop':
        return 'قطرة';
      case 'injection':
        return 'حقنة';
      case 'spoon':
        return 'ملعقة';
      default:
        return 'وحدة';
    }
  }

  String _transactionLabel(String? type) {
    switch (type) {
      case 'INITIAL':
        return 'رصيد أولي';
      case 'ADD':
        return 'إضافة مخزون';
      case 'TAKEN':
        return 'استهلاك جرعة';
      case 'ADJUSTMENT':
        return 'تعديل المخزون';
      default:
        return type ?? 'عملية';
    }
  }

  Future<void> _addStock() async {
    final controller = TextEditingController();
    final quantity = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مخزون'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'الكمية',
            suffixText: _unitLabel(_medication.stockUnit),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (value != null && value > 0) Navigator.pop(ctx, value);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (quantity == null || !mounted) return;
    final provider = context.read<MedicationProvider>();
    final ok = await provider.addMedicationStock(
      medication: _medication,
      quantity: quantity,
    );
    if (!mounted) return;
    if (ok) {
      final updated = provider.medications.where((m) => m.id == _medication.id).firstOrNull;
      if (updated != null) setState(() => _medication = updated);
      await _loadHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث المخزون')),
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
                  DropdownMenuItem(value: 'capsule', child: Text('كبسولة')),
                  DropdownMenuItem(value: 'tablet', child: Text('قرص')),
                  DropdownMenuItem(value: 'ml', child: Text('مل')),
                  DropdownMenuItem(value: 'drop', child: Text('قطرة')),
                  DropdownMenuItem(value: 'injection', child: Text('حقنة')),
                  DropdownMenuItem(value: 'spoon', child: Text('ملعقة')),
                  DropdownMenuItem(value: 'unit', child: Text('وحدة')),
                ],
                onChanged: (value) {
                  setDialogState(() => unit = value ?? unit);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: package,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'حجم العبوة (اختياري)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: threshold,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'حد التنبيه للمخزون المنخفض'),
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

    final packageValue = double.tryParse(package.text.trim().replaceAll(',', '.'));
    final thresholdValue = double.tryParse(threshold.text.trim().replaceAll(',', '.'));
    package.dispose();
    threshold.dispose();

    if (result != true || !mounted || thresholdValue == null || thresholdValue < 0) {
      return;
    }

    final provider = context.read<MedicationProvider>();
    final ok = await provider.updateMedicationStockSettings(
      medication: _medication,
      unit: unit,
      packageQuantity: packageValue,
      lowStockThreshold: thresholdValue,
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
    final dailyConsumption = calculateDailyConsumption(_schedules);
    final daysRemaining = dailyConsumption > 0
        ? _medication.stockQuantity / dailyConsumption
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('مخزون ${_medication.name}'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            MedicationStockBadge(
              medication: _medication,
              schedules: _schedules,
              onAdd: _medication.stockEnabled ? _addStock : null,
              onSettings: _editSettings,
              onDetails: null,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ملخص الاستهلاك', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'الاستهلاك اليومي المتوقع', value: dailyConsumption > 0 ? '${_formatNumber(dailyConsumption)} ${_unitLabel(_medication.stockUnit)}' : 'غير محدد'),
                    if (daysRemaining != null) ...[
                      const SizedBox(height: 8),
                      _InfoRow(label: 'المدة التقديرية', value: '${_formatNumber(daysRemaining)} يوم'),
                    ],
                    const SizedBox(height: 8),
                    _InfoRow(label: 'حد التنبيه', value: '${_formatNumber(_medication.lowStockThreshold)} ${_unitLabel(_medication.stockUnit)}'),
                    if (_medication.packageQuantity != null) ...[
                      const SizedBox(height: 8),
                      _InfoRow(label: 'حجم العبوة', value: '${_formatNumber(_medication.packageQuantity!)} ${_unitLabel(_medication.stockUnit)}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('سجل المخزون', style: Theme.of(context).textTheme.titleMedium),
                if (_medication.stockEnabled)
                  FilledButton.tonalIcon(
                    onPressed: _addStock,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingHistory)
              const Padding(
                padding: EdgeInsets.all(24),
                child: LoadingIndicator(),
              )
            else if (_transactions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('لا توجد عمليات مخزون بعد.')),
                ),
              )
            else
              ..._transactions.map(
                (row) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        (row['transaction_type'] as String?) == 'TAKEN'
                            ? Icons.remove_rounded
                            : Icons.add_rounded,
                      ),
                    ),
                    title: Text(_transactionLabel(row['transaction_type'] as String?)),
                    subtitle: Text((row['created_at'] as String?) ?? ''),
                    trailing: Text(
                      '${_formatNumber((row['quantity'] as num?)?.toDouble() ?? 0)} ${_unitLabel(_medication.stockUnit)}',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    );
  }
}

extension on Iterable<Medication> {
  Medication? get firstOrNull => isEmpty ? null : first;
}
