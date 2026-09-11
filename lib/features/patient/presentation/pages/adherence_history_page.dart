import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/dose_instance.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../doses/data/dose_repository.dart';
import '../../../doses/domain/adherence_report.dart';

class AdherenceHistoryPage extends StatefulWidget {
  const AdherenceHistoryPage({super.key});

  @override
  State<AdherenceHistoryPage> createState() => _AdherenceHistoryPageState();
}

class _AdherenceHistoryPageState extends State<AdherenceHistoryPage> {
  final DoseRepository _repository = DoseRepository();
  List<DoseInstance> _doses = const [];
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _error == null && _doses.isEmpty) {
      _load();
    }
  }

  Future<void> _load() async {
    final patientId = context.read<AuthProvider>().profile?.id;
    if (patientId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = today.subtract(const Duration(days: 28));
    final to = today.add(const Duration(days: 1));

    try {
      final doses = await _repository.fetchDosesForRange(
        patientId,
        from: from,
        to: to,
      );
      if (!mounted) return;
      setState(() {
        _doses = doses;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل سجل الالتزام.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingIndicator());
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final currentWeek = AdherenceReportEngine.weekly(
      _doses,
      weekStart: currentWeekStart,
    );
    final medicationReport = AdherenceReportEngine.byMedication(
      _doses,
      from: today.subtract(const Duration(days: 7)),
      to: today.add(const Duration(days: 1)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الالتزام')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _loading = true;
            _error = null;
          });
          await _load();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (_error != null) ...[
              _errorCard(_error!),
              const SizedBox(height: 12),
            ],
            _weekSummary(currentWeek),
            const SizedBox(height: 16),
            _weekChart(currentWeek),
            const SizedBox(height: 18),
            _medicationSection(medicationReport),
          ],
        ),
      ),
    );
  }

  Widget _weekSummary(WeeklyAdherence report) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.insights_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text('هذا الأسبوع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _metric('${report.percentage.round()}%', 'الالتزام', Icons.percent_rounded)),
                Expanded(child: _metric('${report.taken}', 'تم أخذها', Icons.check_circle_rounded)),
                Expanded(child: _metric('${report.missed}', 'فائتة', Icons.warning_rounded)),
                Expanded(child: _metric('${report.pending}', 'مفتوحة', Icons.schedule_rounded)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekChart(WeeklyAdherence report) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الالتزام اليومي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            ...report.days.map(_dayRow),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(DailyAdherence day) {
    final summary = day.summary;
    final progress = summary.resolved == 0 ? 0.0 : summary.percentage / 100;
    final label = _weekday(day.day.weekday);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 42, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: progress, minHeight: 10),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 58,
            child: Text(
              summary.resolved == 0 ? '—' : '${summary.percentage.round()}%',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicationSection(List<MedicationAdherence> report) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الالتزام حسب الدواء', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (report.isEmpty)
              const Text('لا توجد بيانات كافية خلال آخر 7 أيام.')
            else
              ...report.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: .10),
                    child: const Icon(Icons.medication_rounded, color: AppColors.primary),
                  ),
                  title: Text(item.medicationName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${item.summary.taken} مأخوذة · ${item.summary.missed} فائتة'),
                  trailing: Text('${item.percentage.round()}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 21, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _errorCard(String message) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
              TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );

  String _weekday(int value) => switch (value) {
        DateTime.monday => 'الإثنين',
        DateTime.tuesday => 'الثلاثاء',
        DateTime.wednesday => 'الأربعاء',
        DateTime.thursday => 'الخميس',
        DateTime.friday => 'الجمعة',
        DateTime.saturday => 'السبت',
        _ => 'الأحد',
      };
}
