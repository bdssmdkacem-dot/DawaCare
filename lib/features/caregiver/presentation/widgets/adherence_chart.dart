import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/adherence_calculator.dart';

class AdherenceChart extends StatelessWidget {
  final AdherenceStats stats;

  const AdherenceChart({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.total == 0) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('لا توجد بيانات كافية بعد')),
      );
    }

    return SizedBox(
      height: 160,
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 34,
                sections: [
                  if (stats.taken > 0)
                    PieChartSectionData(value: stats.taken.toDouble(), color: AppColors.success, showTitle: false),
                  if (stats.missed > 0)
                    PieChartSectionData(value: stats.missed.toDouble(), color: AppColors.danger, showTitle: false),
                  if (stats.skipped > 0)
                    PieChartSectionData(value: stats.skipped.toDouble(), color: AppColors.neutral, showTitle: false),
                  if (stats.open > 0)
                    PieChartSectionData(value: stats.open.toDouble(), color: AppColors.warning, showTitle: false),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${stats.takenPercent}%',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const Text('نسبة الالتزام'),
                const SizedBox(height: 10),
                _legendRow('أُخذت', stats.taken, AppColors.success),
                _legendRow('فائتة', stats.missed, AppColors.danger),
                _legendRow('متخطاة', stats.skipped, AppColors.neutral),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label: $value', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
