import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../../../../utils/date_time_utils.dart';
import '../providers/medication_provider.dart';

class MedicationDetailPage extends StatefulWidget {
  final Medication medication;

  const MedicationDetailPage({super.key, required this.medication});

  @override
  State<MedicationDetailPage> createState() => _MedicationDetailPageState();
}

class _MedicationDetailPageState extends State<MedicationDetailPage> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<MedicationProvider>();
    final schedules = provider.schedulesByMedicationId[widget.medication.id] ?? const <MedicationSchedule>[];

    return Scaffold(
      appBar: AppBar(title: Text(widget.medication.name)),
      body: RefreshIndicator(
        onRefresh: () => provider.load(widget.medication.patientId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _heroCard(context, l, provider),
            const SizedBox(height: 16),
            Text(l.schedules, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (schedules.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l.noSchedules)))
            else
              ...schedules.map((schedule) => _scheduleCard(context, l, schedule)),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, AppLocalizations l, MedicationProvider provider) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String?>(
            future: provider.signedMedicationImageUrl(widget.medication.imageUrl),
            builder: (context, snapshot) {
              final url = snapshot.data;
              if (url == null || url.isEmpty) {
                return Container(
                  height: 190,
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.medication_rounded, size: 72),
                );
              }
              return Image.network(
                url,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 900,
                errorBuilder: (_, __, ___) => Container(
                  height: 190,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.medication_rounded, size: 72),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.medication.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                if ((widget.medication.genericName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(widget.medication.genericName!),
                ],
                if ((widget.medication.strength ?? '').isNotEmpty || (widget.medication.dosageForm ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text([widget.medication.strength, widget.medication.dosageForm].whereType<String>().where((v) => v.isNotEmpty).join(' • ')),
                ],
                if ((widget.medication.instructions ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(widget.medication.instructions!),
                ],
                const SizedBox(height: 10),
                Text('${l.treatmentPeriod}: ${DateTimeUtils.formatShortDate(widget.medication.startDate)}${widget.medication.endDate == null ? '' : ' — ${DateTimeUtils.formatShortDate(widget.medication.endDate!)}'}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(BuildContext context, AppLocalizations l, MedicationSchedule schedule) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.schedule_rounded)),
        title: Text(_scheduleTitle(l, schedule)),
        subtitle: Text('${l.doseAmount}: ${schedule.doseAmount}'),
        trailing: IconButton(
          tooltip: l.edit,
          icon: const Icon(Icons.edit_rounded),
          onPressed: () => _editSchedule(schedule),
        ),
      ),
    );
  }

  String _scheduleTitle(AppLocalizations l, MedicationSchedule schedule) {
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

  Future<void> _editSchedule(MedicationSchedule schedule) async {
    final l = AppLocalizations.of(context);
    final provider = context.read<MedicationProvider>();
    final parts = schedule.time.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
    final doseController = TextEditingController(text: schedule.doseAmount);
    var selectedTime = initialTime;
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
                borderRadius: BorderRadius.circular(14),
                onTap: saving
                    ? null
                    : () async {
                        final picked = await showTimePicker(context: dialogContext, initialTime: selectedTime);
                        if (picked != null) setDialogState(() => selectedTime = picked);
                      },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l.doseTime,
                    prefixIcon: const Icon(Icons.access_time_rounded),
                  ),
                  child: Text(selectedTime.format(dialogContext)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: doseController,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l.doseAmount,
                  prefixIcon: const Icon(Icons.exposure_plus_1_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final amount = doseController.text.trim();
                      if (amount.isEmpty) return;
                      setDialogState(() => saving = true);
                      final ok = await provider.updateSchedule(
                        schedule,
                        patientId: widget.medication.patientId,
                        time: '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                        doseAmount: amount,
                      );
                      if (!mounted) return;
                      if (ok) {
                        Navigator.pop(dialogContext, true);
                      } else {
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text(provider.error ?? l.unexpectedError)),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l.saveMedicine),
            ),
          ],
        ),
      ),
    );
    doseController.dispose();
    if (!mounted || result != true) return;

    final updatedList = provider.schedulesByMedicationId[widget.medication.id];
    if (updatedList != null) {
      setState(() {});
    }
  }

  String _tr(String ar, String en, String fr) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'fr') return fr;
    if (locale == 'en') return en;
    return ar;
  }
}
