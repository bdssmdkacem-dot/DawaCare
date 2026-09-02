import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/caregiver_link.dart';
import '../../../doses/presentation/providers/dose_provider.dart';
import '../../../patient/presentation/widgets/dose_card.dart';
import '../../data/caregiver_repository.dart';
import '../../domain/adherence_calculator.dart';
import '../widgets/adherence_chart.dart';
import 'voice_recorder_page.dart';

class PatientDetailPage extends StatefulWidget {
  final CaregiverLink link;
  const PatientDetailPage({super.key, required this.link});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A caregiver's phone shouldn't schedule local alarms for someone
      // else's medication — this is purely a read/confirm-on-their-behalf view.
      context.read<DoseProvider>().load(widget.link.patientId, scheduleReminders: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final doseProvider = context.watch<DoseProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.link.patientName)),
      body: doseProvider.isLoading && doseProvider.all.isEmpty
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: () => context.read<DoseProvider>().load(widget.link.patientId, scheduleReminders: false),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: AdherenceChart(stats: AdherenceCalculator.compute(doseProvider.all)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VoiceRecorderPage(
                            patientId: widget.link.patientId,
                            patientName: widget.link.patientName,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.mic_rounded),
                      label: const Text('إرسال رسالة صوتية'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('اليوم', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  if (doseProvider.todayDoses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('لا توجد أدوية مجدولة اليوم')),
                    )
                  else
                    ...doseProvider.todayDoses.map(
                      (dose) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DoseCard(
                          dose: dose,
                          onConfirm: () => context.read<DoseProvider>().confirm(dose, source: 'CAREGIVER'),
                          onSnooze: () => context.read<DoseProvider>().snooze(dose, source: 'CAREGIVER'),
                          onSkip: () => context.read<DoseProvider>().skip(dose, source: 'CAREGIVER'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _confirmUnlink(context),
                    icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent),
                    label: const Text('إزالة الربط', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _confirmUnlink(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة الربط؟'),
        content: Text('لن تتمكن بعد الآن من متابعة أدوية ${widget.link.patientName}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إزالة')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await CaregiverRepository().unlink(widget.link.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
