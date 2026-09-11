import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../models/dose_instance.dart';
import '../../domain/adherence_calculator.dart';

class PatientStatusHeader extends StatelessWidget {
  final AdherenceStats stats;
  final DoseInstance? nextDose;
  final int lowStockCount;
  final int outOfStockCount;
  final String Function(String ar, String en, String fr) tr;
  final VoidCallback? onNextDose;
  final VoidCallback? onReports;

  const PatientStatusHeader({
    super.key,
    required this.stats,
    required this.nextDose,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.tr,
    this.onNextDose,
    this.onReports,
  });

  String _nextDoseLabel(BuildContext context) {
    final dose = nextDose;
    if (dose == null) {
      return tr('لا توجد جرعة قادمة', 'No upcoming dose', 'Aucune dose à venir');
    }
    final time = TimeOfDay.fromDateTime(dose.scheduledAt).format(context);
    return '${dose.medicationName} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final dueStats = stats.taken + stats.missed + stats.skipped + stats.open;
    final adherence = dueStats == 0 ? 0.0 : stats.takenPercent;
    final stockRisk = lowStockCount + outOfStockCount;
    final critical = stats.missed > 0 || outOfStockCount > 0;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: .12),
              critical ? AppColors.danger.withValues(alpha: .07) : AppColors.primary.withValues(alpha: .03),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(critical ? Icons.warning_rounded : Icons.health_and_safety_rounded, color: critical ? AppColors.danger : AppColors.primary),
            const SizedBox(width: 9),
            Expanded(child: Text(tr('الحالة اليومية', 'Daily status', 'État quotidien'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            if (onReports != null)
              IconButton(tooltip: tr('التقارير', 'Reports', 'Rapports'), onPressed: onReports, icon: const Icon(Icons.analytics_outlined)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _metric('${adherence.toStringAsFixed(0)}%', tr('التزام', 'Adherence', 'Observance'))),
            Expanded(child: _metric('${stats.missed}', tr('فائتة', 'Missed', 'Manquées'), danger: stats.missed > 0)),
            Expanded(child: _metric('${stats.taken}', tr('مأخوذة', 'Taken', 'Prises'))),
            Expanded(child: _metric('$stockRisk', tr('مخزون', 'Stock risk', 'Risque stock'), danger: stockRisk > 0)),
          ]),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onNextDose,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .72), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.schedule_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('الجرعة القادمة', 'Next dose', 'Prochaine dose'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(_nextDoseLabel(context), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                ])),
                if (onNextDose != null) const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
          if (outOfStockCount > 0 || lowStockCount > 0) ...[
            const SizedBox(height: 9),
            Wrap(spacing: 7, runSpacing: 7, children: [
              if (outOfStockCount > 0) _riskChip(Icons.production_quantity_limits_rounded, '${tr('نافد', 'Out', 'Épuisé')} $outOfStockCount'),
              if (lowStockCount > 0) _riskChip(Icons.warning_amber_rounded, '${tr('منخفض', 'Low', 'Faible')} $lowStockCount'),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _metric(String value, String label, {bool danger = false}) => Column(children: [
    Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: danger ? AppColors.danger : null)),
    const SizedBox(height: 2),
    Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
  ]);

  Widget _riskChip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: AppColors.danger),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
    ]),
  );
}
