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
      return SizedBox(
        height: 150,
        child: Center(
          child: Text(
            _tr(context, 'لا توجد جرعات مستحقة بعد', 'No due doses yet', 'Aucune dose échue pour le moment'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats.missed > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.danger.withValues(alpha: .18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _tr(
                      context,
                      'هناك ${stats.missed} جرعة فائتة تحتاج إلى الانتباه.',
                      '${stats.missed} missed dose${stats.missed == 1 ? '' : 's'} need attention.',
                      '${stats.missed} dose${stats.missed == 1 ? '' : 's'} manquée${stats.missed == 1 ? '' : 's'} nécessite${stats.missed == 1 ? '' : 'nt'} une attention.',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
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
                    Text('${stats.takenPercent}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                    Text(_tr(context, 'نسبة الالتزام', 'Adherence', 'Observance')),
                    const SizedBox(height: 10),
                    _legendRow(context, 'taken', stats.taken, AppColors.success),
                    _legendRow(context, 'missed', stats.missed, AppColors.danger),
                    _legendRow(context, 'skipped', stats.skipped, AppColors.neutral),
                    if (stats.open > 0) _legendRow(context, 'open', stats.open, AppColors.warning),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendRow(BuildContext context, String key, int value, Color color) {
    final labels = {
      'taken': _tr(context, 'أُخذت', 'Taken', 'Prises'),
      'missed': _tr(context, 'فائتة', 'Missed', 'Manquées'),
      'skipped': _tr(context, 'متخطاة', 'Skipped', 'Ignorées'),
      'open': _tr(context, 'معلقة', 'Open', 'En attente'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('${labels[key]}: $value', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

String _tr(BuildContext context, String ar, String en, String fr) {
  switch (Localizations.localeOf(context).languageCode) {
    case 'en':
      return en;
    case 'fr':
      return fr;
    default:
      return ar;
  }
}
