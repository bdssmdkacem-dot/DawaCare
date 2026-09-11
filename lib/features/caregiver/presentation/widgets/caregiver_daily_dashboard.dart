import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../providers/caregiver_provider.dart';

class CaregiverDailyDashboard extends StatelessWidget {
  final CaregiverProvider provider;
  const CaregiverDailyDashboard({super.key, required this.provider});

  String _tr(BuildContext context, String ar, String en, String fr) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'en': return en;
      case 'fr': return fr;
      default: return ar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final critical = provider.totalMissedDoseCount > 0 || provider.outOfStockMedicationCount > 0;
    final next = provider.nextDoseAt;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(Icons.dashboard_rounded, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_tr(context, 'ملخص الرعاية اليوم', 'Today’s care summary', 'Résumé des soins du jour'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              Text(_tr(context, '${provider.linkedPatients.length} أفراد مرتبطون', '${provider.linkedPatients.length} linked people', '${provider.linkedPatients.length} personnes liées'), style: Theme.of(context).textTheme.bodySmall),
            ])),
            if (provider.isSummariesLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _Metric(label: _tr(context, 'الجرعات', 'Doses', 'Doses'), value: '${provider.totalTodayDoseCount}', icon: Icons.medication_rounded),
            _Metric(label: _tr(context, 'المأخوذة', 'Taken', 'Prises'), value: '${provider.totalTakenDoseCount}', icon: Icons.check_circle_rounded),
            _Metric(label: _tr(context, 'المتبقية', 'Pending', 'En attente'), value: '${provider.totalPendingDoseCount}', icon: Icons.schedule_rounded),
            _Metric(label: _tr(context, 'الفائتة', 'Missed', 'Manquées'), value: '${provider.totalMissedDoseCount}', icon: Icons.warning_amber_rounded),
          ]),
          const SizedBox(height: 14),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: provider.overallAdherence.clamp(0.0, 1.0), minHeight: 8)),
          const SizedBox(height: 7),
          Row(children: [
            Expanded(child: Text(_tr(context, 'الالتزام اليومي', 'Overall adherence', 'Observance globale'))),
            Text('${(provider.overallAdherence * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
          if (next != null) ...[
            const SizedBox(height: 12),
            _StatusTile(icon: Icons.alarm_rounded, title: _tr(context, 'الجرعة القادمة', 'Next dose', 'Prochaine dose'), value: DateTimeUtils.formatTime(next), critical: false),
          ],
          if (provider.lowStockMedicationCount > 0 || provider.outOfStockMedicationCount > 0) ...[
            const SizedBox(height: 8),
            _StatusTile(icon: Icons.inventory_2_rounded, title: _tr(context, 'المخزون', 'Stock', 'Stock'), value: _tr(context, '${provider.lowStockMedicationCount} منخفض · ${provider.outOfStockMedicationCount} منتهٍ', '${provider.lowStockMedicationCount} low · ${provider.outOfStockMedicationCount} out', '${provider.lowStockMedicationCount} faible · ${provider.outOfStockMedicationCount} épuisé'), critical: provider.outOfStockMedicationCount > 0),
          ],
          if (critical) ...[
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)), child: Row(children: [
              Icon(Icons.priority_high_rounded, color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(_tr(context, 'هناك حالة تحتاج إلى انتباهك اليوم.', 'Something needs your attention today.', 'Une situation nécessite votre attention aujourd’hui.'), style: const TextStyle(fontWeight: FontWeight.w800))),
            ])),
          ],
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _Metric({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [Icon(icon, size: 19, color: AppColors.primary), const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)]));
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String title, value;
  final bool critical;
  const _StatusTile({required this.icon, required this.title, required this.value, required this.critical});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: (critical ? AppColors.danger : AppColors.primary).withValues(alpha: .06), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(icon, size: 20, color: critical ? AppColors.danger : AppColors.primary), const SizedBox(width: 9), Expanded(child: Text(title)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]));
}
