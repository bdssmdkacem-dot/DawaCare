import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../models/medication.dart';

class MedicationStockBadge extends StatelessWidget {
  final Medication medication;
  final VoidCallback? onAdd;

  const MedicationStockBadge({super.key, required this.medication, this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (!medication.stockEnabled) {
      return OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.inventory_2_outlined, size: 17),
        label: const Text('تفعيل عداد المخزون'),
      );
    }

    final quantity = _format(medication.stockQuantity);
    final threshold = medication.lowStockThreshold;
    final low = medication.stockQuantity <= threshold;
    final empty = medication.stockQuantity <= 0;
    final color = empty || low ? Theme.of(context).colorScheme.error : AppColors.primary;
    final label = empty
        ? 'نفد الدواء'
        : 'متبقي $quantity ${_unitLabel(medication.stockUnit)}';

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(empty ? Icons.error_outline_rounded : Icons.inventory_2_outlined, size: 18, color: color),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onAdd != null) ...[
          const SizedBox(width: 6),
          IconButton.filledTonal(
            tooltip: 'إضافة مخزون',
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ],
    );
  }

  String _format(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);

  String _unitLabel(String unit) {
    switch (unit) {
      case 'capsule': return 'كبسولة';
      case 'tablet': return 'قرص';
      case 'ml': return 'مل';
      case 'drop': return 'قطرة';
      case 'injection': return 'حقنة';
      default: return 'وحدة';
    }
  }
}