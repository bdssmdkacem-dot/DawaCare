import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/dose_instance.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../doses/presentation/providers/dose_provider.dart';
import '../../../medications/domain/stock_intelligence.dart';
import '../../../medications/presentation/pages/medication_detail_page.dart';
import '../../../medications/presentation/pages/medication_list_page.dart';
import '../../../medications/presentation/providers/medication_provider.dart';
import '../../../settings/presentation/pages/profile_page.dart';
import '../widgets/next_dose_card.dart';

class PatientOverviewPage extends StatefulWidget {
  const PatientOverviewPage({super.key});

  @override
  State<PatientOverviewPage> createState() => _PatientOverviewPageState();
}

class _PatientOverviewPageState extends State<PatientOverviewPage> {
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) return;
    final userId = context.read<AuthProvider>().profile?.id;
    final doses = context.read<DoseProvider>();
    final medications = context.read<MedicationProvider>();
    if (userId != null && (doses.patientId != userId || medications.patientId != userId)) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await Future.wait([
            doses.load(userId),
            medications.load(userId),
          ]);
        } finally {
          if (mounted) setState(() => _loading = false);
        }
      });
    }
  }

  Future<void> _refresh() async {
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId == null) return;
    await Future.wait([
      context.read<DoseProvider>().load(userId),
      context.read<MedicationProvider>().load(userId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final doses = context.watch<DoseProvider>();
    final medications = context.watch<MedicationProvider>();

    if (profile == null || (doses.isLoading && doses.all.isEmpty)) {
      return const Scaffold(body: LoadingIndicator());
    }

    final today = doses.todayDoses;
    final taken = today.where((d) => d.status == DoseStatus.taken).length;
    final missed = today.where((d) => d.status == DoseStatus.missed).length;
    final pending = today.where((d) => d.status == DoseStatus.pending || d.status == DoseStatus.reminderSent || d.status == DoseStatus.snoozed).length;
    final next = today.cast<DoseInstance?>().firstWhere(
      (d) => d != null && (d.status == DoseStatus.pending || d.status == DoseStatus.reminderSent || d.status == DoseStatus.snoozed),
      orElse: () => null,
    );
    final progress = today.isEmpty ? 0.0 : taken / today.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حالتي اليوم'),
        actions: [
          IconButton(
            tooltip: 'الملف الشخصي',
            icon: _avatar(profile.avatarUrl, 20),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _welcome(profile.fullName),
            const SizedBox(height: 16),
            _todayCard(taken: taken, total: today.length, missed: missed, pending: pending, progress: progress),
            const SizedBox(height: 16),
            if (next != null)
              NextDoseCard(
                dose: next,
                onConfirm: () async { await doses.confirm(next); },
                onSnooze: () async { await doses.snooze(next); },
                onSkip: () async { await doses.skip(next); },
              )
            else
              _allDone(today.isNotEmpty),
            const SizedBox(height: 18),
            _sectionHeader('أدويتي', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MedicationListPage()))),
            const SizedBox(height: 10),
            if (medications.isLoading && medications.medications.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (medications.medications.isEmpty)
              _emptyCard('لا توجد أدوية مسجلة حاليًا.')
            else
              ...medications.medications.take(4).map((medication) {
                final schedules = medications.schedulesByMedicationId[medication.id] ?? const [];
                final days = StockIntelligence.daysRemaining(medication: medication, schedules: schedules);
                final low = StockIntelligence.isLowStock(medication);
                final empty = StockIntelligence.isOutOfStock(medication);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    elevation: 0,
                    child: ListTile(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MedicationDetailPage(medication: medication, schedules: schedules))),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: .10),
                        child: const Icon(Icons.medication_rounded, color: AppColors.primary),
                      ),
                      title: Text(medication.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(medication.strength?.isNotEmpty == true ? '${medication.strength}${medication.dosageForm == null ? '' : ' · ${medication.dosageForm}'}' : (medication.dosageForm ?? '')),
                      trailing: _stockSummary(medication, days, low, empty),
                    ),
                  ),
                );
              }),
            if (medications.medications.length > 4)
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MedicationListPage())),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('عرض كل الأدوية'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _welcome(String name) => Card(
        elevation: 0,
        color: AppColors.primary.withValues(alpha: .08),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              _avatar(context.read<AuthProvider>().profile?.avatarUrl, 28),
              const SizedBox(width: 12),
              Expanded(child: Text('مرحبًا، ${name.trim().isEmpty ? 'عزيزي' : name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            ],
          ),
        ),
      );

  Widget _todayCard({required int taken, required int total, required int missed, required int pending, required double progress}) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [const Icon(Icons.today_rounded, color: AppColors.primary), const SizedBox(width: 8), const Text('ملخص اليوم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const Spacer(), Text('$taken / $total', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary))]),
              const SizedBox(height: 14),
              ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 9)),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _metric(Icons.check_circle_rounded, '$taken', 'تم أخذها', AppColors.success)), Expanded(child: _metric(Icons.schedule_rounded, '$pending', 'متبقية', AppColors.warning)), Expanded(child: _metric(Icons.warning_rounded, '$missed', 'فائتة', AppColors.danger))]),
            ],
          ),
        ),
      );

  Widget _metric(IconData icon, String value, String label, Color color) => Column(children: [Icon(icon, size: 22, color: color), const SizedBox(height: 3), Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color)), Text(label, style: const TextStyle(fontSize: 11))]);

  Widget _allDone(bool hadDoses) => Card(
        elevation: 0,
        child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [Icon(hadDoses ? Icons.celebration_rounded : Icons.event_available_rounded, size: 40, color: AppColors.success), const SizedBox(height: 8), Text(hadDoses ? 'أكملت جرعات اليوم 🎉' : 'لا توجد جرعات اليوم', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(hadDoses ? 'أحسنت، استمر على هذا الالتزام.' : 'يمكنك مراجعة أدويتك أو إضافة دواء جديد.')])),
      );

  Widget _sectionHeader(String title, VoidCallback onMore) => Row(children: [Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const Spacer(), TextButton(onPressed: onMore, child: const Text('عرض الكل'))]);

  Widget _emptyCard(String text) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Text(text)));

  Widget _stockSummary(dynamic medication, double? days, bool low, bool empty) {
    if (!medication.stockEnabled) return const Icon(Icons.inventory_2_outlined, size: 22);
    if (empty) return const Tooltip(message: 'نفد المخزون', child: Icon(Icons.error_rounded, color: AppColors.danger));
    if (low) return Tooltip(message: 'المخزون منخفض', child: Icon(Icons.warning_rounded, color: AppColors.warning));
    if (days != null) return Text('${days.floor()} يوم', style: const TextStyle(fontWeight: FontWeight.w800));
    return Text('${medication.stockQuantity}', style: const TextStyle(fontWeight: FontWeight.w800));
  }

  Widget _avatar(String? url, double radius) {
    final has = url != null && url.isNotEmpty;
    return CircleAvatar(radius: radius, backgroundColor: AppColors.primary.withValues(alpha: .12), backgroundImage: has ? NetworkImage(url!) : null, child: has ? null : Icon(Icons.person_rounded, color: AppColors.primary, size: radius * 1.15));
  }
}
