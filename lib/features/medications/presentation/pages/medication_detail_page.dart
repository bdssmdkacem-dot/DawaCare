import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../models/medication.dart';
import '../../../../models/medication_schedule.dart';
import '../providers/medication_provider.dart';

class MedicationDetailPage extends StatefulWidget {
  final Medication medication;

  const MedicationDetailPage({super.key, required this.medication});

  @override
  State<MedicationDetailPage> createState() => _MedicationDetailPageState();
}

class _MedicationDetailPageState extends State<MedicationDetailPage> {
  List<MedicationSchedule> _schedules = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<MedicationProvider>();
      final schedules = await provider.fetchSchedules(widget.medication.id);
      if (!mounted) return;
      setState(() => _schedules = schedules);
    });
  }

  Future<void> _editSchedule(MedicationSchedule schedule) async {
    final l = AppLocalizations.of(context);
    final provider = context.read<MedicationProvider>();
    final doseController = TextEditingController(text: schedule.doseAmount);
    TimeOfDay selectedTime = _parseTime(schedule.time);
    var saving = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(l.editMedicine),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_rounded),
                  title: Text('${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
                  onTap: saving
                      ? null
                      : () async {
                          final picked = await showTimePicker(context: dialogContext, initialTime: selectedTime);
                          if (!dialogContext.mounted || picked == null) return;
                          setDialogState(() => selectedTime = picked);
                        },
                ),
                TextField(
                  controller: doseController,
                  enabled: !saving,
                  decoration: InputDecoration(labelText: l.doseAmount),
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
                          if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                        } else {
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(provider.error ?? l.unexpectedError)),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.saveMedicine),
              ),
            ],
          );
        },
      ),
    );
    doseController.dispose();
    if (!mounted || result != true) return;
    final schedules = await provider.fetchSchedules(widget.medication.id);
    if (!mounted) return;
    setState(() => _schedules = schedules);
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final medication = widget.medication;
    return Scaffold(
      appBar: AppBar(title: Text(medication.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(medication.name, style: Theme.of(context).textTheme.headlineSmall),
                  if ((medication.genericName ?? '').isNotEmpty) Text(medication.genericName!),
                  if ((medication.strength ?? '').isNotEmpty) Text(medication.strength!),
                  if ((medication.dosageForm ?? '').isNotEmpty) Text(medication.dosageForm!),
                  if ((medication.instructions ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(medication.instructions!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l.schedules, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._schedules.map(
            (schedule) => Card(
              child: ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: Text(schedule.time),
                subtitle: Text(schedule.doseAmount),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () => _editSchedule(schedule),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
