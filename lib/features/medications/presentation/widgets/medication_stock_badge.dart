import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../../domain/stock_intelligence.dart';

class MedicationStockBadge extends StatelessWidget {
  final Medication medication;
  final List<MedicationSchedule> schedules;
  final VoidCallback? onAdd;
  final VoidCallback? onSettings;
  final VoidCallback? onDetails;
  final double? threshold;
  final double? lowStockThreshold;

  const MedicationStockBadge({
    super.key,
    required this.medication,
    this.schedules = const [],
    this.onAdd,
    this.onSettings,
    this.onDetails,
    this.threshold,
    this.lowStockThreshold,
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
    final effectiveThreshold = lowStockThreshold ?? threshold ?? medication.lowStockThreshold;
    final empty = StockIntelligence.isOutOfStock(medication);
    final low = !empty && quantity <= effectiveThreshold;
    final days = StockIntelligence.daysRemaining(
      medication: medication,
      schedules: schedules,
    );
    final color = empty
        ? theme.colorScheme.error
        : low
            ? theme.colorScheme.tertiary
            : AppColors.primary;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      empty ? Icons.error_outline_rounded : Icons.inventory_2_rounded,
                      size: 19,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          empty
                              ? 'نفد الدواء'
                              : 'متبقي ${_format(quantity)} ${_unitLabel(medication.stockUnit)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          empty
                              ? 'أضف المخزون قبل الجرعة القادمة'
                              : low
                                  ? 'المخزون منخفض • الحد ${_format(effectiveThreshold)}'
                                  : 'المخزون بحالة جيدة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onSettings != null)
                    IconButton(
                      tooltip: 'إعدادات المخزون',
                      visualDensity: VisualDensity.compact,
                      onPressed: onSettings,
                      icon: const Icon(Icons.tune_rounded, size: 19),
                    ),
                  if (onAdd != null)
                    IconButton.filledTonal(
                      tooltip: 'إضافة مخزون',
                      visualDensity: VisualDensity.compact,
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded, size: 20),
                    ),
                ],
              ),
              if (!empty) ...[
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: effectiveThreshold > 0
                        ? (quantity / (effectiveThreshold * 3)).clamp(0.0, 1.0).toDouble()
                        : 1.0,
                    backgroundColor: color.withValues(alpha: .10),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        days == null
                            ? 'لا يمكن تقدير الأيام المتبقية'
                            : days < 1
                                ? 'يكفي لأقل من يوم'
                                : 'يكفي تقريبًا لـ ${_formatDays(days)} ${days >= 2 ? 'أيام' : 'يوم'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'عبوة: ${medication.packageQuantity == null ? '—' : _format(medication.packageQuantity!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

  String _formatDays(double value) => value < 10
      ? value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')
      : value.floor().toString();

  String _unitLabel(String? unit) {
    switch (unit) {
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
}
