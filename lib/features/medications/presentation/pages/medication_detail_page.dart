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
import '../providers/medication_provider.dart';

class MedicationDetailPage extends StatefulWidget {
  final Medication medication;
  final List<MedicationSchedule> schedules;

  const MedicationDetailPage({super.key, required this.medication, required this.schedules});

  @override
  State<MedicationDetailPage> createState() => _MedicationDetailPageState();
}

class _MedicationDetailPageState extends State<MedicationDetailPage> {
  final DoseRepository _doseRepository = DoseRepository();
  late Future<List<DoseInstance>> _dosesFuture;
  late List<MedicationSchedule> _schedules;

  @override
  void initState() {
    super.initState();
    _schedules = List<MedicationSchedule>.from(widget.schedules);
    _loadDoses();
  }

  void _loadDoses() {
    final now = DateTime.now();
    _dosesFuture = _doseRepository.fetchDosesForRange(
      widget.medication.patientId,
      from: now.subtract(const Duration(days: 30)),
      to: now.add(const Duration(days: 7)),
    );
  }

  String _tr(String ar, String en, String fr) {
    switch (AppLocalizations.of(context).locale.languageCode) {
      case 'en': return en;
      case 'fr': return fr;
      default: return ar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final med = widget.medication;
    return Scaffold(
      appBar: AppBar(title: Text(med.name)),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_loadDoses);
          await _dosesFuture;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            _heroCard(context),
            const SizedBox(height: 14),
            _sectionTitle(context, Icons.insights_rounded, _tr('متابعة العلاج', 'Treatment progress', 'Suivi du traitement')),
            const SizedBox(height: 10),
            FutureBuilder<List<DoseInstance>>(
              future: _dosesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(24), child: LoadingIndicator());
                }
                final doses = (snapshot.data ?? const <DoseInstance>[]).where((d) => d.medicationId == med.id).toList();
                return _progressCard(context, doses);
              },
            ),
            const SizedBox(height: 18),
            _sectionTitle(context, Icons.schedule_rounded, l.frequency),
            const SizedBox(height: 10),
            ..._schedules.map((schedule) => _scheduleCard(context, schedule)),
            if (_schedules.isEmpty)
              _infoCard(context, Icons.info_outline_rounded, _tr('لا يوجد جدول نشط لهذا الدواء.', 'No active schedule for this medicine.', 'Aucun planning actif pour ce médicament.')),
            const SizedBox(height: 18),
            _sectionTitle(context, Icons.event_rounded, _tr('مدة العلاج', 'Treatment period', 'Période de traitement')),
            const SizedBox(height: 10),
            _periodCard(context),
            if (med.instructions != null && med.instructions!.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle(context, Icons.notes_rounded, l.instructionsOptional),
              const SizedBox(height: 10),
              _infoCard(context, Icons.notes_rounded, med.instructions!.trim()),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _confirmDeactivate,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(l.deactivateMedicine),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    final med = widget.medication;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String?>(
              future: context.read<MedicationProvider>().signedMedicationImageUrl(med.imageUrl),
              builder: (context, snapshot) {
                final url = snapshot.data;
                return Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(22)),
                  clipBehavior: Clip.antiAlias,
                  child: url == null
                      ? const Icon(Icons.medication_liquid_rounded, color: AppColors.primary, size: 42)
                      : Image.network(url, fit: BoxFit.cover, cacheWidth: 276, cacheHeight: 276, errorBuilder: (_, __, ___) => const Icon(Icons.medication_liquid_rounded, color: AppColors.primary, size: 42)),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(med.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  if (med.genericName != null && med.genericName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(med.genericName!.trim()),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (med.strength != null && med.strength!.trim().isNotEmpty) _tag(med.strength!.trim()),
                      if (med.dosageForm != null && med.dosageForm!.trim().isNotEmpty) _tag(AppLocalizations.of(context).dosageFormLabel(med.dosageForm!.trim())),
                      _tag(_tr('نشط', 'Active', 'Actif')),
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

  Widget _progressCard(BuildContext context, List<DoseInstance> doses) {
    final today = DateTime.now();
    final todayDoses = doses.where((d) => DateTimeUtils.isSameDate(d.scheduledAt, today)).toList();
    final history = doses.where((d) => d.scheduledAt.isBefore(today.add(const Duration(days: 1)))).toList();
    final taken = history.where((d) => d.status == DoseStatus.taken).length;
    final missed = history.where((d) => d.status == DoseStatus.missed).length;
    final skipped = history.where((d) => d.status == DoseStatus.skipped).length;
    final pending = todayDoses.where((d) => !isResolvedStatus(d.status) && d.status != DoseStatus.missed).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: _metric(context, Icons.today_rounded, AppLocalizations.of(context).today, '${todayDoses.length}')),
              Expanded(child: _metric(context, Icons.check_circle_outline_rounded, _tr('تم أخذها', 'Taken', 'Prises'), '$taken')),
              Expanded(child: _metric(context, Icons.warning_amber_rounded, _tr('فاتت', 'Missed', 'Manquées'), '$missed')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _metric(context, Icons.schedule_rounded, _tr('متبقية اليوم', 'Remaining today', 'Restantes aujourd’hui'), '$pending')),
              Expanded(child: _metric(context, Icons.skip_next_rounded, _tr('متخطاة', 'Skipped', 'Ignorées'), '$skipped')),
              Expanded(child: _metric(context, Icons.calendar_month_rounded, _tr('السجل', 'History', 'Historique'), '${history.length}')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, IconData icon, String label, String value) => Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      );

  Widget _scheduleCard(BuildContext context, MedicationSchedule schedule) {
    final l = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.alarm_rounded)),
        title: Text(_describeSchedule(schedule, l), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text('${l.doseAmount}: ${schedule.doseAmount}')),
        trailing: IconButton(
          tooltip: _tr('تعديل التوقيت والجرعة', 'Edit time and dose', 'Modifier l’heure et la dose'),
          icon: const Icon(Icons.edit_calendar_rounded),
          onPressed: () => _editSchedule(schedule),
        ),
      ),
    );
  }

  String _describeSchedule(MedicationSchedule schedule, AppLocalizations l) {
    switch (schedule.type) {
      case ScheduleType.daily: return '${l.daily} — ${schedule.time}';
      case ScheduleType.weekly:
      case ScheduleType.specificDays: return '${schedule.daysOfWeek.map(l.weekdayLabel).join('، ')} — ${schedule.time}';
      case ScheduleType.interval: return '${l.everyFewDays}: ${schedule.intervalDays ?? 1} — ${schedule.time}';
      case ScheduleType.once: return '${l.once} — ${DateTimeUtils.formatShortDate(schedule.startDate)} ${schedule.time}';
      case ScheduleType.prn: return l.asNeeded;
    }
  }

  Future<void> _editSchedule(MedicationSchedule schedule) async {
    final l = AppLocalizations.of(context);
    final parts = schedule.time.split(':');
    var selectedTime = TimeOfDay(hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8, minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0);
    final doseController = TextEditingController(text: schedule.doseAmount);
    var saving = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_tr('تعديل الجرعة', 'Edit dose', 'Modifier la dose')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: saving ? null : () async {
                  final picked = await showTimePicker(context: dialogContext, initialTime: selectedTime);
                  if (!dialogContext.mounted || picked == null) return;
                  setDialogState(() => selectedTime = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: l.doseTime, prefixIcon: const Icon(Icons.access_time_rounded)),
                  child: Text(selectedTime.format(dialogContext)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: doseController,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.doseAmount, prefixIcon: const Icon(Icons.exposure_plus_1_rounded)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: Text(l.cancel)),
            FilledButton(
              onPressed: saving ? null : () async {
                final amount = doseController.text.trim();
                if (amount.isEmpty) return;
                final provider = context.read<MedicationProvider>();
                setDialogState(() => saving = true);
                final ok = await provider.updateSchedule(
                  schedule,
                  patientId: widget.medication.patientId,
                  time: '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                  doseAmount: amount,
                );
                if (!mounted) return;
                if (ok) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } else {
                  if (dialogContext.mounted) setDialogState(() => saving = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error ?? l.unexpectedError)));
                }
              },
              child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.saveMedicine),
            ),
          ],
        ),
      ),
    );
    doseController.dispose();
    if (!mounted || result != true) return;
    final updatedList = context.read<MedicationProvider>().schedulesByMedicationId[widget.medication.id];
    if (updatedList != null) {
      setState(() {
        _schedules = List<MedicationSchedule>.from(updatedList);
        _loadDoses();
      });
    }
  }

  Widget _periodCard(BuildContext context) {
    final l = AppLocalizations.of(context);
    final med = widget.medication;
    return Card(
      child: Column(
        children: [
          ListTile(leading: const Icon(Icons.event_available_rounded, color: AppColors.primary), title: Text(l.startDate), trailing: Text(DateTimeUtils.formatShortDate(med.startDate), style: const TextStyle(fontWeight: FontWeight.w800))),
          ListTile(leading: const Icon(Icons.event_busy_rounded, color: AppColors.primary), title: Text(l.endDateOptional), trailing: Text(med.endDate == null ? '—' : DateTimeUtils.formatShortDate(med.endDate!), style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String title) => Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))]);
  Widget _infoCard(BuildContext context, IconData icon, String text) => Card(child: ListTile(leading: Icon(icon, color: AppColors.primary), title: Text(text)));
  Widget _tag(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)));

  Future<void> _confirmDeactivate() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deactivateMedicineTitle),
        content: Text(l.deactivateMedicineBody(widget.medication.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.stop)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<MedicationProvider>();
    await provider.deactivate(widget.medication);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }
}
