import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../domain/medication_report.dart';
import '../providers/medication_report_provider.dart';

class MedicationReportsPage extends StatefulWidget {
  final String patientId;
  final String patientName;
  final MedicationReportProvider? provider;

  const MedicationReportsPage({
    super.key,
    required this.patientId,
    required this.patientName,
    this.provider,
  });

  @override
  State<MedicationReportsPage> createState() => _MedicationReportsPageState();
}

class _MedicationReportsPageState extends State<MedicationReportsPage> {
  late final MedicationReportProvider _provider;
  late final bool _ownsProvider;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? MedicationReportProvider();
    _ownsProvider = widget.provider == null;
    if (widget.provider == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _provider.load(widget.patientId);
      });
    }
  }

  @override
  void dispose() {
    if (_ownsProvider) _provider.dispose();
    super.dispose();
  }

  String _tr(String ar, String en, String fr) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'en':
        return en;
      case 'fr':
        return fr;
      default:
        return ar;
    }
  }

  String _periodLabel(ReportPeriod period) {
    switch (period) {
      case ReportPeriod.today:
        return _tr('اليوم', 'Today', "Aujourd'hui");
      case ReportPeriod.week:
        return _tr('هذا الأسبوع', 'This week', 'Cette semaine');
      case ReportPeriod.month:
        return _tr('هذا الشهر', 'This month', 'Ce mois');
    }
  }

  Future<void> _selectPeriod(ReportPeriod period) async {
    if (period == _provider.period && _provider.report != null) return;
    await _provider.load(widget.patientId, selectedPeriod: period);
  }

  Widget _metric({required IconData icon, required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _summary(AdherenceReport report) {
    final percent = (report.adherence * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_tr('نسبة الالتزام', 'Adherence', 'Observance'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('$percent%', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(value: report.adherence, strokeWidth: 8, backgroundColor: AppColors.primary.withValues(alpha: .10)),
                      Text('$percent%', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _metric(icon: Icons.event_available_rounded, label: _tr('مجدولة', 'Scheduled', 'Prévues'), value: '${report.scheduled}'),
                const SizedBox(width: 7),
                _metric(icon: Icons.check_circle_rounded, label: _tr('مأخوذة', 'Taken', 'Prises'), value: '${report.taken}'),
                const SizedBox(width: 7),
                _metric(icon: Icons.warning_amber_rounded, label: _tr('فاتت', 'Missed', 'Manquées'), value: '${report.missed}'),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                _metric(icon: Icons.skip_next_rounded, label: _tr('متجاوزة', 'Skipped', 'Ignorées'), value: '${report.skipped}'),
                const SizedBox(width: 7),
                _metric(icon: Icons.pending_actions_rounded, label: _tr('معلقة', 'Pending', 'En attente'), value: '${report.pending}'),
                const SizedBox(width: 7),
                _metric(icon: Icons.done_all_rounded, label: _tr('محسومة', 'Resolved', 'Résolues'), value: '${report.resolved}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dailyActivity(AdherenceReport report) {
    final days = report.takenByDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (days.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(_tr('لا توجد جرعات مأخوذة في هذه الفترة.', 'No taken doses in this period.', 'Aucune dose prise sur cette période.'), textAlign: TextAlign.center),
        ),
      );
    }
    final maxValue = days.fold<int>(1, (max, item) => item.value > max ? item.value : max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tr('النشاط اليومي', 'Daily activity', 'Activité quotidienne'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 14),
            ...days.map((item) {
              final ratio = item.value / maxValue;
              final date = '${item.key.day.toString().padLeft(2, '0')}/${item.key.month.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(width: 48, child: Text(date, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(value: ratio, minHeight: 10, backgroundColor: AppColors.primary.withValues(alpha: .08)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 28, child: Text('${item.value}', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w900))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _medicationCard(MedicationReport medication) {
    final percent = (medication.adherence * 100).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.medication_rounded, color: AppColors.primary)),
                const SizedBox(width: 11),
                Expanded(child: Text(medication.medicationName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                Text('$percent%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 11),
            LinearProgressIndicator(value: medication.adherence, minHeight: 8, backgroundColor: AppColors.primary.withValues(alpha: .08)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 5,
              children: [
                Text('${_tr('مأخوذة', 'Taken', 'Prises')}: ${medication.taken}'),
                Text('${_tr('فاتت', 'Missed', 'Manquées')}: ${medication.missed}'),
                Text('${_tr('مجدولة', 'Scheduled', 'Prévues')}: ${medication.scheduled}'),
                Text('${_tr('معلقة', 'Pending', 'En attente')}: ${medication.pending}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AdherenceReport report) {
    return RefreshIndicator(
      onRefresh: () => _provider.reload(widget.patientId),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.primaryDark]), borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                const CircleAvatar(radius: 25, backgroundColor: Colors.white24, child: Icon(Icons.analytics_rounded, color: Colors.white)),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tr('تقرير العلاج', 'Treatment report', 'Rapport du traitement'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(widget.patientName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))])),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _summary(report),
          const SizedBox(height: 14),
          _dailyActivity(report),
          const SizedBox(height: 14),
          Text(_tr('حسب الدواء', 'By medication', 'Par médicament'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          if (report.medications.isEmpty)
            Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(_tr('لا توجد بيانات في هذه الفترة.', 'No data for this period.', 'Aucune donnée pour cette période.'), textAlign: TextAlign.center)))
          else
            ...report.medications.map(_medicationCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MedicationReportProvider>.value(
      value: _provider,
      child: Consumer<MedicationReportProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_tr('تقارير الالتزام', 'Adherence reports', 'Rapports d’observance')),
              actions: [IconButton(onPressed: provider.isLoading ? null : () => provider.reload(widget.patientId), icon: const Icon(Icons.refresh_rounded))],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SegmentedButton<ReportPeriod>(
                    segments: ReportPeriod.values.map((period) => ButtonSegment<ReportPeriod>(value: period, label: Text(_periodLabel(period)))).toList(),
                    selected: {provider.period},
                    onSelectionChanged: provider.isLoading ? null : (selection) => _selectPeriod(selection.first),
                  ),
                ),
                Expanded(
                  child: provider.isLoading && provider.report == null
                      ? const LoadingIndicator()
                      : provider.error != null && provider.report == null
                          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, size: 46), const SizedBox(height: 10), Text(provider.error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: () => provider.reload(widget.patientId), child: Text(_tr('إعادة المحاولة', 'Retry', 'Réessayer')))])))
                          : _content(provider.report!),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
