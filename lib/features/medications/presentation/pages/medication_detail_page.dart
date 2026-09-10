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
  late Future<List<Map<String, dynamic>>> _stockFuture;
  late List<MedicationSchedule> _schedules;

  @override
  void initState() {
    super.initState();
    _schedules = List<MedicationSchedule>.from(widget.schedules);
    _reload();
  }

  void _reload() {
    final now = DateTime.now();
    _dosesFuture = _doseRepository.fetchDosesForRange(
      widget.medication.patientId,
      from: now.subtract(const Duration(days: 30)),
      to: now.add(const Duration(days: 14)),
    );
    _stockFuture = context.read<MedicationProvider>().fetchStockTransactions(widget.medication.id);
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
    final med = widget.medication;
    return Scaffold(
      appBar: AppBar(
        title: Text(med.name),
        actions: [
          IconButton(
            tooltip: _tr('تحديث', 'Refresh', 'Actualiser'),
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
          children: [
            _heroCard(context),
            const SizedBox(height: 12),
            FutureBuilder<List<DoseInstance>>(
              future: _dosesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(20), child: LoadingIndicator());
                }
                final doses = (snapshot.data ?? const <DoseInstance>[]).where((d) => d.medicationId == med.id).toList();
                return _nextDoseAndTodayCard(context, doses);
              },
            ),
            const SizedBox(height: 16),
            _sectionTitle(context, Icons.inventory_2_rounded, _tr('المخزون', 'Stock', 'Stock')),
            const SizedBox(height: 8),
            _stockCard(context),
            const SizedBox(height: 16),
            _sectionTitle(context, Icons.schedule_rounded, _tr('جدول الجرعات', 'Dose schedule', 'Planning des doses')),
            const SizedBox(height: 8),
            ..._schedules.map((schedule) => _scheduleCard(context, schedule)),
            if (_schedules.isEmpty)
              _infoCard(context, Icons.info_outline_rounded, _tr('لا يوجد جدول نشط لهذا الدواء.', 'No active schedule for this medicine.', 'Aucun planning actif pour ce médicament.')),
            const SizedBox(height: 16),
            _sectionTitle(context, Icons.insights_rounded, _tr('متابعة العلاج', 'Treatment progress', 'Suivi du traitement')),
            const SizedBox(height: 8),
            FutureBuilder<List<DoseInstance>>(
              future: _dosesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
                final doses = (snapshot.data ?? const <DoseInstance>[]).where((d) => d.medicationId == med.id).toList();
                return _progressCard(context, doses);
              },
            ),
            const SizedBox(height: 16),
            _sectionTitle(context, Icons.event_rounded, _tr('مدة العلاج', 'Treatment period', 'Période de traitement')),
            const SizedBox(height: 8),
            _periodCard(context),
            if (med.instructions != null && med.instructions!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _sectionTitle(context, Icons.notes_rounded, AppLocalizations.of(context).instructionsOptional),
              const SizedBox(height: 8),
              _infoCard(context, Icons.notes_rounded, med.instructions!.trim()),
            ],
            const SizedBox(height: 16),
            _sectionTitle(context, Icons.history_rounded, _tr('حركات المخزون', 'Stock history', 'Historique du stock')),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _stockFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(18), child: LoadingIndicator());
                final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) return _infoCard(context, Icons.inventory_outlined, _tr('لا توجد حركات مخزون بعد.', 'No stock movements yet.', 'Aucun mouvement de stock.'));
                return _stockHistory(context, rows.take(20).toList());
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _confirmDeactivate,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(AppLocalizations.of(context).deactivateMedicine),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String?>(
                  future: context.read<MedicationProvider>().signedMedicationImageUrl(med.imageUrl),
                  builder: (context, snapshot) {
                    final url = snapshot.data;
                    return Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(20)),
                      clipBehavior: Clip.antiAlias,
                      child: url == null
                          ? const Icon(Icons.medication_liquid_rounded, color: AppColors.primary, size: 38)
                          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.medication_liquid_rounded, color: AppColors.primary, size: 38)),
                    );
                  },
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      if (med.genericName?.trim().isNotEmpty == true) Text(med.genericName!.trim(), style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 7),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        if (med.strength?.trim().isNotEmpty == true) _tag(med.strength!.trim()),
                        if (med.dosageForm?.trim().isNotEmpty == true) _tag(AppLocalizations.of(context).dosageFormLabel(med.dosageForm!.trim())),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _doseSummary(context),
          ],
        ),
      ),
    );
  }

  Widget _doseSummary(BuildContext context) {
    final l = AppLocalizations.of(context);
    final active = _schedules.where((s) => s.type != ScheduleType.prn).toList();
    if (active.isEmpty) return _tag(_tr('عند الحاجة PRN', 'As needed (PRN)', 'Si besoin (PRN)'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_tr('الجرعة', 'Dose', 'Dose'), style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        ...active.take(4).map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text('• ${s.doseAmount} · ${_describeSchedule(s, l)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        )),
        if (active.length > 4) Text('+ ${active.length - 4} ${_tr('مواعيد أخرى', 'more times', 'autres horaires')}'),
      ],
    );
  }

  Widget _nextDoseAndTodayCard(BuildContext context, List<DoseInstance> doses) {
    final now = DateTime.now();
    final upcoming = doses.where((d) => !isResolvedStatus(d.status) && !d.scheduledAt.isBefore(now)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final next = upcoming.isEmpty ? null : upcoming.first;
    final today = doses.where((d) => DateTimeUtils.isSameDate(d.scheduledAt, now)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(_tr('الجرعة القادمة', 'Next dose', 'Prochaine dose'), style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          if (next == null)
            Text(_schedules.any((s) => s.type == ScheduleType.prn)
                ? _tr('عند الحاجة — لا توجد جرعة مجدولة تلقائيًا.', 'As needed — no automatic dose scheduled.', 'Si besoin — aucune dose automatique.')
                : _tr('لا توجد جرعة قادمة في الفترة الحالية.', 'No upcoming dose in the current window.', 'Aucune dose à venir dans la période.'))
          else
            Row(children: [
              Text(DateTimeUtils.formatShortDate(next.scheduledAt), style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              Text(_time(next.scheduledAt), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const Spacer(),
              _tag(next.status == DoseStatus.taken ? _tr('تم أخذها', 'Taken', 'Prise') : '${next.doseAmount}'),
            ]),
          if (today.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(_tr('اليوم', 'Today', "Aujourd’hui"), style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Wrap(spacing: 7, runSpacing: 7, children: today.map((d) => _dosePill(context, d)).toList()),
          ],
        ]),
      ),
    );
  }

  Widget _dosePill(BuildContext context, DoseInstance dose) {
    final taken = dose.status == DoseStatus.taken;
    final missed = dose.status == DoseStatus.missed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: (taken ? Colors.green : missed ? Theme.of(context).colorScheme.error : AppColors.primary).withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('${_time(dose.scheduledAt)}  ${taken ? '✓' : missed ? '!' : '○'}', style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _stockCard(BuildContext context) {
    final med = widget.medication;
    if (!med.stockEnabled) {
      return Card(child: ListTile(leading: const Icon(Icons.inventory_outlined), title: Text(_tr('تتبع المخزون غير مفعّل', 'Stock tracking is off', 'Suivi du stock désactivé')), subtitle: Text(_tr('فعّله من زر المخزون في القائمة.', 'Enable it from the stock action on the list.', 'Activez-le depuis la liste.'))));
    }
    final daily = _dailyConsumption();
    final days = daily == null || daily <= 0 ? null : med.stockQuantity / daily;
    final ratio = med.lowStockThreshold <= 0 ? (med.stockQuantity > 0 ? 1.0 : 0.0) : (med.stockQuantity / (med.stockQuantity + med.lowStockThreshold)).clamp(0.0, 1.0);
    final empty = med.stockQuantity <= 0;
    final low = !empty && med.stockQuantity <= med.lowStockThreshold;
    final status = empty ? _tr('يحتاج إعادة شراء', 'Needs refill', 'À renouveler') : low ? _tr('قريب من النفاد', 'Low stock', 'Stock faible') : _tr('كافٍ', 'Enough', 'Suffisant');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${_formatNumber(med.stockQuantity)} ${_unitLabel(med.stockUnit)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            _statusChip(context, status, empty || low),
          ]),
          const SizedBox(height: 9),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: ratio, minHeight: 8)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(days == null ? _tr('الاستهلاك اليومي غير محسوب', 'Daily use cannot be calculated', 'Consommation quotidienne non calculable') : '${_tr('يكفي تقريبًا', 'About', 'Environ')} ${_formatDays(days)} ${_tr('يومًا', 'days', 'jours')}')),
            Text('${_tr('الحد', 'Threshold', 'Seuil')}: ${_formatNumber(med.lowStockThreshold)}', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ]),
      ),
    );
  }

  double? _dailyConsumption() {
    double total = 0;
    var found = false;
    for (final s in _schedules) {
      if (s.type == ScheduleType.prn) continue;
      final amount = double.tryParse(s.doseAmount.trim().replaceAll(',', '.'));
      if (amount == null || amount <= 0) continue;
      found = true;
      switch (s.type) {
        case ScheduleType.daily:
        case ScheduleType.once: total += amount; break;
        case ScheduleType.weekly:
        case ScheduleType.specificDays: total += amount * (s.daysOfWeek.isEmpty ? 1 : s.daysOfWeek.length) / 7; break;
        case ScheduleType.interval: total += amount / (s.intervalDays ?? 1).clamp(1, 365); break;
        case ScheduleType.prn: break;
      }
    }
    return found && total > 0 ? total : null;
  }

  Widget _progressCard(BuildContext context, List<DoseInstance> doses) {
    final today = DateTime.now();
    final history = doses.where((d) => d.scheduledAt.isBefore(today.add(const Duration(days: 1)))).toList();
    final todayDoses = history.where((d) => DateTimeUtils.isSameDate(d.scheduledAt, today)).toList();
    final taken = history.where((d) => d.status == DoseStatus.taken).length;
    final missed = history.where((d) => d.status == DoseStatus.missed).length;
    final skipped = history.where((d) => d.status == DoseStatus.skipped).length;
    final pending = todayDoses.where((d) => !isResolvedStatus(d.status) && d.status != DoseStatus.missed).length;
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
      Row(children: [
        Expanded(child: _metric(context, Icons.today_rounded, _tr('اليوم', 'Today', 'Aujourd’hui'), '${todayDoses.length}')),
        Expanded(child: _metric(context, Icons.check_circle_outline_rounded, _tr('تم أخذها', 'Taken', 'Prises'), '$taken')),
        Expanded(child: _metric(context, Icons.warning_amber_rounded, _tr('فاتت', 'Missed', 'Manquées'), '$missed')),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _metric(context, Icons.schedule_rounded, _tr('متبقية اليوم', 'Remaining', 'Restantes'), '$pending')),
        Expanded(child: _metric(context, Icons.skip_next_rounded, _tr('متخطاة', 'Skipped', 'Ignorées'), '$skipped')),
        Expanded(child: _metric(context, Icons.history_rounded, _tr('السجل', 'History', 'Historique'), '${history.length}')),
      ]),
    ])));
  }

  Widget _metric(BuildContext context, IconData icon, String label, String value) => Column(children: [Icon(icon, color: AppColors.primary, size: 22), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)]);

  Widget _scheduleCard(BuildContext context, MedicationSchedule schedule) {
    final l = AppLocalizations.of(context);
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(child: Icon(schedule.type == ScheduleType.prn ? Icons.touch_app_rounded : Icons.alarm_rounded)),
      title: Text(_describeSchedule(schedule, l), style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${l.doseAmount}: ${schedule.doseAmount}'),
      trailing: IconButton(icon: const Icon(Icons.edit_calendar_rounded), tooltip: _tr('تعديل التوقيت والجرعة', 'Edit time and dose', 'Modifier l’heure et la dose'), onPressed: () => _editSchedule(schedule)),
    ));
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
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(_tr('تعديل الجرعة', 'Edit dose', 'Modifier la dose')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          InkWell(onTap: saving ? null : () async { final picked = await showTimePicker(context: dialogContext, initialTime: selectedTime); if (dialogContext.mounted && picked != null) setDialogState(() => selectedTime = picked); }, child: InputDecorator(decoration: InputDecoration(labelText: l.doseTime), child: Text(selectedTime.format(dialogContext)))),
          const SizedBox(height: 12),
          TextField(controller: doseController, enabled: !saving, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l.doseAmount)),
        ]),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: Text(l.cancel)),
          FilledButton(onPressed: saving ? null : () async {
            final amount = doseController.text.trim();
            if (amount.isEmpty) return;
            setDialogState(() => saving = true);
            final ok = await context.read<MedicationProvider>().updateSchedule(schedule, patientId: widget.medication.patientId, time: '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}', doseAmount: amount);
            if (!mounted) return;
            if (ok) { if (dialogContext.mounted) Navigator.pop(dialogContext, true); } else { if (dialogContext.mounted) setDialogState(() => saving = false); }
          }, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.saveMedicine)),
        ],
      )),
    );
    doseController.dispose();
    if (!mounted || result != true) return;
    final updated = context.read<MedicationProvider>().schedulesByMedicationId[widget.medication.id];
    if (updated != null) setState(() { _schedules = List<MedicationSchedule>.from(updated); _reload(); });
  }

  Widget _periodCard(BuildContext context) => Card(child: Column(children: [
    ListTile(leading: const Icon(Icons.event_available_rounded, color: AppColors.primary), title: Text(AppLocalizations.of(context).startDate), trailing: Text(DateTimeUtils.formatShortDate(widget.medication.startDate), style: const TextStyle(fontWeight: FontWeight.w800))),
    ListTile(leading: const Icon(Icons.event_busy_rounded, color: AppColors.primary), title: Text(AppLocalizations.of(context).endDateOptional), trailing: Text(widget.medication.endDate == null ? '—' : DateTimeUtils.formatShortDate(widget.medication.endDate!), style: const TextStyle(fontWeight: FontWeight.w800))),
  ]));

  Widget _stockHistory(BuildContext context, List<Map<String, dynamic>> rows) => Card(child: Column(children: rows.map((row) {
    final qty = (row['quantity'] as num?)?.toDouble() ?? 0;
    final type = '${row['transaction_type'] ?? ''}';
    final date = row['created_at'] == null ? null : DateTime.tryParse('${row['created_at']}')?.toLocal();
    final positive = !type.toUpperCase().contains('DOSE') && !type.toUpperCase().contains('REMOVE');
    final label = type == 'INITIAL' ? _tr('بداية المخزون', 'Initial stock', 'Stock initial') : type == 'ADD' ? _tr('إضافة مخزون', 'Stock added', 'Ajout de stock') : type;
    return ListTile(
      dense: true,
      leading: Icon(positive ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded, color: positive ? Colors.green : Theme.of(context).colorScheme.error),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(date == null ? '' : DateTimeUtils.formatShortDate(date)),
      trailing: Text('${positive ? '+' : '-'}${_formatNumber(qty)}', style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }).toList()));

  String _unitLabel(String value) {
    switch (value) {
      case 'tablet': return 'قرص';
      case 'capsule': return 'كبسولة';
      case 'ml': return 'مل';
      case 'drop': return 'قطرة';
      case 'injection': return 'حقنة';
      default: return 'وحدة';
    }
  }

  Widget _statusChip(BuildContext context, String text, bool alert) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: (alert ? Theme.of(context).colorScheme.error : Colors.green).withValues(alpha: .10), borderRadius: BorderRadius.circular(18)), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)));
  Widget _tag(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(18)), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)));
  Widget _sectionTitle(BuildContext context, IconData icon, String title) => Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))]);
  Widget _infoCard(BuildContext context, IconData icon, String text) => Card(child: ListTile(leading: Icon(icon, color: AppColors.primary), title: Text(text)));
  String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  String _formatNumber(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
  String _formatDays(double value) => value < 1 ? '<1' : value < 10 ? value.toStringAsFixed(1) : value.round().toString();

  Future<void> _confirmDeactivate() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.deactivateMedicineTitle),
      content: Text(l.deactivateMedicineBody(widget.medication.name)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)), TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.stop))],
    ));
    if (confirmed != true || !mounted) return;
    await context.read<MedicationProvider>().deactivate(widget.medication);
    if (mounted) Navigator.of(context).pop(true);
  }
}
