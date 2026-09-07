import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';

class MedicationStockBadge extends StatelessWidget {
  final Medication medication;
  final List<MedicationSchedule> schedules;
  final VoidCallback? onAdd;
  final VoidCallback? onSettings;
  final VoidCallback? onDetails;

  const MedicationStockBadge({
    super.key,
    required this.medication,
    this.schedules = const [],
    this.onAdd,
    this.onSettings,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!medication.stockEnabled) {
      return OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.inventory_2_outlined, size: 18),
        label: const Text('تفعيل عداد المخزون'),
      );
    }

    final quantity = medication.stockQuantity;
    final threshold = medication.lowStockThreshold;
    final empty = quantity <= 0;
    final low = !empty && quantity <= threshold;
    final daily = _dailyConsumption();
    final days = daily > 0 ? quantity / daily : null;
    final color = empty ? theme.colorScheme.error : low ? theme.colorScheme.tertiary : AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onDetails,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: .07),
            border: Border.all(color: color.withValues(alpha: .18)),
          ),
          padding: const EdgeInsets.fromLTRB(11, 10, 7, 9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle), child: Icon(empty ? Icons.error_outline_rounded : Icons.inventory_2_rounded, size: 19, color: color)),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(empty ? 'نفد الدواء' : 'متبقي ${_format(quantity)} ${_unitLabel(medication.stockUnit)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
                const SizedBox(height: 2),
                Text(empty ? 'أضف المخزون قبل الجرعة القادمة' : low ? 'المخزون منخفض • الحد ${_format(threshold)}' : 'المخزون بحالة جيدة', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ])),
              if (onSettings != null) IconButton(tooltip: 'إعدادات المخزون', visualDensity: VisualDensity.compact, onPressed: onSettings, icon: const Icon(Icons.tune_rounded, size: 19)),
              if (onAdd != null) IconButton.filledTonal(tooltip: 'إضافة مخزون', visualDensity: VisualDensity.compact, onPressed: onAdd, icon: const Icon(Icons.add_rounded, size: 20)),
            ]),
            if (!empty) ...[
              const SizedBox(height: 9),
              ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(minHeight: 6, value: threshold > 0 ? (quantity / (threshold * 3)).clamp(0.0, 1.0).toDouble() : 1.0, backgroundColor: color.withValues(alpha: .10), valueColor: AlwaysStoppedAnimation<Color>(color))),
              const SizedBox(height: 7),
              Row(children: [
                Icon(Icons.schedule_rounded, size: 15, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Expanded(child: Text(days == null ? 'لا يمكن تقدير الأيام المتبقية' : days < 1 ? 'يكفي لأقل من يوم' : 'يكفي تقريبًا لـ ${_formatDays(days)} ${days >= 2 ? 'أيام' : 'يوم'}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
                Text('عبوة: ${medication.packageQuantity == null ? '—' : _format(medication.packageQuantity!)}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  double _dailyConsumption() {
    double total = 0;
    for (final schedule in schedules) {
      final dose = _extractNumber(schedule.doseAmount);
      if (dose <= 0 || schedule.type == ScheduleType.prn) continue;
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

  double _extractNumber(String value) {
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(value.trim());
    return match == null ? 0 : double.tryParse(match.group(0)!.replaceAll(',', '.')) ?? 0;
  }

  String _format(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  String _formatDays(double value) => value < 10 ? value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '') : value.floor().toString();

  String _unitLabel(String? unit) {
    switch (unit) {
      case 'capsule': return 'كبسولة';
      case 'tablet': return 'قرص';
      case 'ml': return 'مل';
      case 'drop': return 'قطرة';
      case 'injection': return 'حقنة';
      case 'spoon': return 'ملعقة';
      default: return 'وحدة';
    }
  }
}
