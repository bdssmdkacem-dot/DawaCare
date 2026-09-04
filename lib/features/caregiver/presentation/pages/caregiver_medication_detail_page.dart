import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/dose_instance.dart';
import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../../../doses/data/dose_repository.dart';
import '../../../medications/presentation/providers/medication_provider.dart';
import 'voice_recorder_page.dart';

class CaregiverMedicationDetailPage extends StatefulWidget {
  final Medication medication;
  final String patientName;
  final bool canManageDoses;

  const CaregiverMedicationDetailPage({
    super.key,
    required this.medication,
    required this.patientName,
    required this.canManageDoses,
  });

  @override
  State<CaregiverMedicationDetailPage> createState() =>
      _CaregiverMedicationDetailPageState();
}

class _CaregiverMedicationDetailPageState
    extends State<CaregiverMedicationDetailPage> {
  final DoseRepository _doseRepository = DoseRepository();
  late Future<_MedicationDetailData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_MedicationDetailData> _loadData() async {
    final medication = await _loadFreshMedication();
    final schedules = await _loadSchedules(medication.id);
    final now = DateTime.now();
    final doses = await _doseRepository.fetchDosesForRange(
      medication.patientId,
      from: now.subtract(const Duration(days: 30)),
      to: now.add(const Duration(days: 7)),
    );
    return _MedicationDetailData(
      medication: medication,
      schedules: schedules,
      doses: doses.where((d) => d.medicationId == medication.id).toList(),
    );
  }

  Future<Medication> _loadFreshMedication() async {
    final provider = context.read<MedicationProvider>();
    await provider.load(widget.medication.patientId);
    for (final medication in provider.medications) {
      if (medication.id == widget.medication.id) return medication;
    }
    return widget.medication;
  }

  Future<List<MedicationSchedule>> _loadSchedules(String medicationId) async {
    final provider = context.read<MedicationProvider>();
    final cached = provider.schedulesByMedicationId[medicationId];
    if (cached != null) return List<MedicationSchedule>.from(cached);
    return provider.fetchSchedules(medicationId);
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MedicationDetailData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.medication.name)),
            body: const LoadingIndicator(),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.medication.name)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _tr(
                        'تعذر تحميل معلومات الدواء.',
                        'Unable to load medication information.',
                        'Impossible de charger les informations du médicament.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _dataFuture = _loadData()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(_tr('إعادة المحاولة', 'Retry', 'Réessayer')),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        return Scaffold(
          appBar: AppBar(title: Text(data.medication.name)),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() => _dataFuture = _loadData());
              await _dataFuture;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                _hero(data.medication),
                const SizedBox(height: 18),
                _section(
                  Icons.medical_information_rounded,
                  _tr('معلومات الدواء', 'Medication information', 'Informations du médicament'),
                ),
                const SizedBox(height: 8),
                _infoGrid(data.medication),
                const SizedBox(height: 18),
                _section(Icons.schedule_rounded, _tr('جدول الدواء', 'Medication schedule', 'Planning du médicament')),
                const SizedBox(height: 8),
                if (data.schedules.isEmpty)
                  _infoCard(Icons.info_outline_rounded, _tr('لا يوجد جدول محفوظ.', 'No saved schedule.', 'Aucun planning enregistré.'))
                else
                  ...data.schedules.map(_scheduleCard),
                const SizedBox(height: 18),
                _section(Icons.medication_rounded, _tr('الجرعات والسجل', 'Doses and history', 'Prises et historique')),
                const SizedBox(height: 8),
                _doseSummary(data.doses),
                const SizedBox(height: 10),
                if (data.doses.isEmpty)
                  _infoCard(Icons.history_rounded, _tr('لا توجد جرعات مسجلة للفترة الحالية.', 'No doses recorded for the current period.', 'Aucune prise enregistrée pour la période actuelle.'))
                else
                  ...data.doses.reversed.take(20).map(_doseHistoryCard),
                const SizedBox(height: 18),
                if ((data.medication.instructions ?? '').trim().isNotEmpty) ...[
                  _section(Icons.notes_rounded, _tr('تعليمات الاستخدام', 'Instructions', 'Instructions d’utilisation')),
                  const SizedBox(height: 8),
                  _infoCard(Icons.notes_rounded, data.medication.instructions!.trim()),
                  const SizedBox(height: 18),
                ],
                _section(Icons.mic_rounded, _tr('رسالة صوتية', 'Voice message', 'Message vocal')),
                const SizedBox(height: 8),
                Card(
                  color: AppColors.primary.withValues(alpha: .055),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.mic_rounded)),
                    title: Text(_tr('إرسال رسالة صوتية', 'Send a voice message', 'Envoyer un message vocal'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(widget.patientName),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VoiceRecorderPage(
                          patientId: data.medication.patientId,
                          patientName: widget.patientName,
                          medicationName: data.medication.name,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _tr(
                    'هذه الصفحة للمتابعة فقط. بيانات الدواء المعروضة مأخوذة من سجل المريض.',
                    'This page is read-only. Medication data comes from the patient record.',
                    'Cette page est en lecture seule. Les données proviennent du dossier du patient.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _hero(Medication medication) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String?>(
              future: context.read<MedicationProvider>().signedMedicationImageUrl(medication.imageUrl),
              builder: (context, snapshot) {
                final url = snapshot.data;
                return Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: url == null || url.isEmpty
                      ? const Icon(Icons.medication_liquid_rounded, color: AppColors.primary, size: 48)
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          cacheWidth: 312,
                          cacheHeight: 312,
                          errorBuilder: (_, __, ___) => const Icon(Icons.medication_liquid_rounded, color: AppColors.primary, size: 48),
                        ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(medication.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  if ((medication.genericName ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(medication.genericName!.trim(), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if ((medication.strength ?? '').trim().isNotEmpty) _tag(medication.strength!.trim()),
                      if ((medication.dosageForm ?? '').trim().isNotEmpty) _tag(AppLocalizations.of(context).dosageFormLabel(medication.dosageForm!.trim())),
                      _tag(medication.active ? _tr('نشط', 'Active', 'Actif') : _tr('متوقف', 'Inactive', 'Inactif')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoGrid(Medication medication) {
    final l = AppLocalizations.of(context);
    return Card(
      child: Column(
        children: [
          _detailRow(Icons.person_outline_rounded, _tr('المريض', 'Patient', 'Patient'), widget.patientName),
          if ((medication.genericName ?? '').trim().isNotEmpty) _detailRow(Icons.science_outlined, _tr('الاسم العلمي', 'Generic name', 'Nom générique'), medication.genericName!.trim()),
          if ((medication.strength ?? '').trim().isNotEmpty) _detailRow(Icons.straighten_rounded, _tr('التركيز', 'Strength', 'Dosage'), medication.strength!.trim()),
          if ((medication.dosageForm ?? '').trim().isNotEmpty) _detailRow(Icons.category_outlined, l.dosageForm, l.dosageFormLabel(medication.dosageForm!.trim())),
          _detailRow(Icons.event_available_rounded, l.startDate, DateTimeUtils.formatShortDate(medication.startDate)),
          _detailRow(Icons.event_busy_rounded, l.endDateOptional, medication.endDate == null ? '—' : DateTimeUtils.formatShortDate(medication.endDate!)),
          _detailRow(Icons.toggle_on_rounded, _tr('الحالة', 'Status', 'Statut'), medication.active ? _tr('نشط', 'Active', 'Actif') : _tr('متوقف', 'Inactive', 'Inactif')),
        ],
      ),
    );
  }

  Widget _scheduleCard(MedicationSchedule schedule) {
    final l = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.alarm_rounded)),
        title: Text(_describeSchedule(schedule, l), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${l.doseAmount}: ${schedule.doseAmount}'),
      ),
    );
  }

  String _describeSchedule(MedicationSchedule schedule, AppLocalizations l) {
    switch (schedule.type) {
      case ScheduleType.daily:
        return '${l.daily} — ${schedule.time}';
      case ScheduleType.weekly:
      case ScheduleType.specificDays:
        return '${schedule.daysOfWeek.map(l.weekdayLabel).join('، ')} — ${schedule.time}';
      case ScheduleType.interval:
        return '${l.everyFewDays}: ${schedule.intervalDays ?? 1} — ${schedule.time}';
      case ScheduleType.once:
        return '${l.once} — ${DateTimeUtils.formatShortDate(schedule.startDate)} ${schedule.time}';
      case ScheduleType.prn:
        return l.asNeeded;
    }
  }

  Widget _doseSummary(List<DoseInstance> doses) {
    final taken = doses.where((d) => d.status == DoseStatus.taken).length;
    final missed = doses.where((d) => d.status == DoseStatus.missed).length;
    final pending = doses.where((d) => d.status == DoseStatus.pending || d.status == DoseStatus.reminderSent || d.status == DoseStatus.snoozed).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: _metric(Icons.check_circle_outline_rounded, _tr('تم أخذها', 'Taken', 'Prises'), '$taken')),
            Expanded(child: _metric(Icons.warning_amber_rounded, _tr('فاتت', 'Missed', 'Manquées'), '$missed')),
            Expanded(child: _metric(Icons.schedule_rounded, _tr('متبقية', 'Pending', 'En attente'), '$pending')),
          ],
        ),
      ),
    );
  }

  Widget _doseHistoryCard(DoseInstance dose) {
    final l = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      child: ListTile(
        leading: Icon(_statusIcon(dose.status), color: AppColors.primary),
        title: Text('${DateTimeUtils.formatShortDate(dose.scheduledAt)} • ${_time(dose.scheduledAt)}'),
        subtitle: Text('${dose.doseAmount} • ${l.doseStatus(doseStatusToDb(dose.status))}'),
      ),
    );
  }

  IconData _statusIcon(DoseStatus status) {
    switch (status) {
      case DoseStatus.taken: return Icons.check_circle_rounded;
      case DoseStatus.missed: return Icons.warning_rounded;
      case DoseStatus.snoozed: return Icons.schedule_rounded;
      case DoseStatus.skipped: return Icons.remove_circle_outline_rounded;
      case DoseStatus.cancelled: return Icons.cancel_outlined;
      case DoseStatus.reminderSent: return Icons.notifications_active_rounded;
      case DoseStatus.pending: return Icons.access_time_rounded;
    }
  }

  String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Widget _metric(IconData icon, String label, String value) => Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 21),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      );

  Widget _section(IconData icon, String title) => Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      );

  Widget _infoCard(IconData icon, String text) => Card(child: ListTile(leading: Icon(icon, color: AppColors.primary), title: Text(text)));

  Widget _detailRow(IconData icon, String label, String value) => ListTile(
        dense: true,
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

class _MedicationDetailData {
  final Medication medication;
  final List<MedicationSchedule> schedules;
  final List<DoseInstance> doses;

  const _MedicationDetailData({required this.medication, required this.schedules, required this.doses});
}
