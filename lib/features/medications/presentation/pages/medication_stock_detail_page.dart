import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../data/medication_repository.dart';
import '../providers/medication_provider.dart';

class MedicationStockDetailPage extends StatefulWidget {
  final Medication medication;
  final List<MedicationSchedule> schedules;

  const MedicationStockDetailPage({super.key, required this.medication, required this.schedules});

  @override
  State<MedicationStockDetailPage> createState() => _MedicationStockDetailPageState();
}

class _MedicationStockDetailPageState extends State<MedicationStockDetailPage> {
  final _repo = MedicationRepository();
  late Medication _medication;
  late Future<List<Map<String, dynamic>>> _history;

  @override
  void initState() {
    super.initState();
    _medication = widget.medication;
    _reload();
  }

  void _reload() => _history = _repo.fetchStockTransactions(_medication.id);

  String _unit(String? value) {
    switch (value) {
      case 'capsule': return 'كبسولة';
      case 'tablet': return 'قرص';
      case 'ml': return 'مل';
      case 'drop': return 'قطرة';
      case 'injection': return 'حقنة';
      case 'spoon': return 'ملعقة';
      default: return 'وحدة';
    }
  }

  String _type(String? value) {
    switch (value) {
      case 'INITIAL': return 'رصيد افتتاحي';
      case 'ADD': return 'إضافة مخزون';
      case 'TAKEN': return 'استهلاك جرعة';
      case 'ADJUSTMENT': return 'تعديل الرصيد';
      default: return value ?? 'حركة';
    }
  }

  Color _statusColor(BuildContext context) {
    if (_medication.stockQuantity <= 0) return Theme.of(context).colorScheme.error;
    if (_medication.stockQuantity <= _medication.lowStockThreshold) return Theme.of(context).colorScheme.tertiary;
    return AppColors.primary;
  }

  double _dailyConsumption() {
    double total = 0;
    for (final schedule in widget.schedules) {
      final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(schedule.doseAmount.trim());
      final dose = match == null ? 0 : double.tryParse(match.group(0)!.replaceAll(',', '.')) ?? 0;
      if (dose <= 0) continue;
      switch (schedule.type) {
        case ScheduleType.daily: total += dose; break;
        case ScheduleType.weekly:
        case ScheduleType.specificDays: total += dose * (schedule.daysOfWeek.isEmpty ? 1 : schedule.daysOfWeek.length) / 7; break;
        case ScheduleType.interval: total += dose / (schedule.intervalDays ?? 1); break;
        case ScheduleType.once:
        case ScheduleType.prn: break;
      }
    }
    return total;
  }

  Future<void> _addStock() async {
    final controller = TextEditingController();
    final value = await showDialog<double>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إضافة مخزون'),
      content: TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'الكمية', suffixText: _unit(_medication.stockUnit))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () { final v = double.tryParse(controller.text.trim().replaceAll(',', '.')); if (v != null && v > 0) Navigator.pop(ctx, v); }, child: const Text('إضافة'))],
    ));
    controller.dispose();
    if (value == null || !mounted) return;
    final ok = await context.read<MedicationProvider>().addMedicationStock(medication: _medication, quantity: value);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<MedicationProvider>().error ?? 'تعذر تحديث المخزون')));
      return;
    }
    final provider = context.read<MedicationProvider>();
    _medication = provider.medications.firstWhere((m) => m.id == _medication.id, orElse: () => _medication);
    setState(_reload);
  }

  Future<void> _settings() async {
    final package = TextEditingController(text: _medication.packageQuantity?.toString() ?? '');
    final threshold = TextEditingController(text: _medication.lowStockThreshold.toString());
    var unit = _medication.stockUnit;
    final result = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
      title: const Text('إعدادات المخزون'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: unit, decoration: const InputDecoration(labelText: 'الوحدة'), items: const [DropdownMenuItem(value: 'capsule', child: Text('كبسولة')), DropdownMenuItem(value: 'tablet', child: Text('قرص')), DropdownMenuItem(value: 'ml', child: Text('مل')), DropdownMenuItem(value: 'drop', child: Text('قطرة')), DropdownMenuItem(value: 'injection', child: Text('حقنة')), DropdownMenuItem(value: 'spoon', child: Text('ملعقة')), DropdownMenuItem(value: 'unit', child: Text('وحدة'))], onChanged: (v) => setState(() => unit = v ?? unit)),
        const SizedBox(height: 12),
        TextField(controller: package, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'حجم العبوة (اختياري)')),
        const SizedBox(height: 12),
        TextField(controller: threshold, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'حد التنبيه للمخزون المنخفض')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))],
    )));
    final packageValue = double.tryParse(package.text.trim().replaceAll(',', '.'));
    final thresholdValue = double.tryParse(threshold.text.trim().replaceAll(',', '.'));
    package.dispose();
    threshold.dispose();
    if (result != true || !mounted || thresholdValue == null || thresholdValue < 0) return;
    final ok = await context.read<MedicationProvider>().updateMedicationStockSettings(medication: _medication, unit: unit, packageQuantity: packageValue, threshold: thresholdValue);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<MedicationProvider>().error ?? 'تعذر حفظ الإعدادات')));
      return;
    }
    _medication = context.read<MedicationProvider>().medications.firstWhere((m) => m.id == _medication.id, orElse: () => _medication);
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    final daily = _dailyConsumption();
    final days = daily > 0 ? _medication.stockQuantity / daily : null;
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المخزون'), actions: [IconButton(onPressed: _settings, tooltip: 'إعدادات المخزون', icon: const Icon(Icons.tune_rounded))]),
      body: RefreshIndicator(onRefresh: () async { setState(_reload); await _history; }, child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), physics: const AlwaysScrollableScrollPhysics(), children: [
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
          Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle), child: Icon(_medication.stockQuantity <= 0 ? Icons.error_outline_rounded : Icons.inventory_2_rounded, color: color, size: 28)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_medication.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), Text(_medication.stockQuantity <= 0 ? 'نفد الدواء' : 'المخزون الحالي', style: TextStyle(color: color, fontWeight: FontWeight.w700))])),]),
          const SizedBox(height: 18),
          Text('${_format(_medication.stockQuantity)} ${_unit(_medication.stockUnit)}', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: color)),
          if (days != null) Text(days < 1 ? 'يكفي لأقل من يوم' : 'يكفي تقريبًا لـ ${_format(days)} يوم', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          LinearProgressIndicator(minHeight: 9, value: _medication.lowStockThreshold > 0 ? (_medication.stockQuantity / (_medication.lowStockThreshold * 3)).clamp(0.0, 1.0).toDouble() : 1.0, backgroundColor: color.withValues(alpha: .10), valueColor: AlwaysStoppedAnimation<Color>(color)),
        ]))),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _stat('الحد المنخفض', '${_format(_medication.lowStockThreshold)} ${_unit(_medication.stockUnit)}')), Expanded(child: _stat('العبوة', _medication.packageQuantity == null ? '—' : '${_format(_medication.packageQuantity!)} ${_unit(_medication.stockUnit)}')), Expanded(child: _stat('الاستهلاك اليومي', daily > 0 ? '${_format(daily)}' : '—'))]),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: _addStock, icon: const Icon(Icons.add_rounded), label: const Text('إضافة مخزون')),
        const SizedBox(height: 22),
        Row(children: [const Icon(Icons.history_rounded, color: AppColors.primary), const SizedBox(width: 8), Text('سجل حركات المخزون', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))]),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(future: _history, builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) return const Card(child: ListTile(leading: Icon(Icons.info_outline_rounded), title: Text('لا توجد حركات مسجلة بعد.')));
          return Card(child: Column(children: rows.map((row) => _transactionTile(context, row)).toList()));
        }),
      ])),
    );
  }

  Widget _transactionTile(BuildContext context, Map<String, dynamic> row) {
    final quantity = (row['quantity'] as num?)?.toDouble() ?? 0;
    final type = row['transaction_type']?.toString();
    final isOut = type == 'TAKEN' || type == 'ADJUSTMENT' && quantity < 0;
    final color = isOut ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    final created = row['created_at']?.toString() ?? '';
    return ListTile(leading: CircleAvatar(backgroundColor: color.withValues(alpha: .10), child: Icon(isOut ? Icons.remove_rounded : Icons.add_rounded, color: color)), title: Text(_type(type), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${_date(created)}${row['note'] == null ? '' : ' • ${row['note']}'}'), trailing: Text('${isOut ? '-' : '+'}${_format(quantity)}', style: TextStyle(fontWeight: FontWeight.w900, color: color)));
  }

  Widget _stat(String title, String value) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), child: Column(children: [Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)), const SizedBox(height: 4), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))])));

  String _format(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  String _date(String value) { final parsed = DateTime.tryParse(value); if (parsed == null) return value; final local = parsed.toLocal(); return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}'; }
}
