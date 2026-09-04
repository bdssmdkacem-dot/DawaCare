import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/caregiver_link.dart';
import '../../../../models/dose_instance.dart';
import '../../../../models/medication.dart';
import '../../../doses/presentation/providers/dose_provider.dart';
import '../../../medications/presentation/providers/medication_provider.dart';
import '../../../patient/presentation/widgets/dose_card.dart';
import '../../data/caregiver_repository.dart';
import '../../domain/adherence_calculator.dart';
import '../widgets/adherence_chart.dart';
import 'caregiver_medication_detail_page.dart';
import 'voice_recorder_page.dart';

class PatientDetailPage extends StatefulWidget {
  final CaregiverLink link;
  final String? initialDoseId;

  const PatientDetailPage({super.key, required this.link, this.initialDoseId});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  late final DoseProvider _patientDoseProvider;
  late final MedicationProvider _patientMedicationProvider;

  bool get _canManageDoses =>
      widget.link.role == CaregiverRole.primary ||
      widget.link.role == CaregiverRole.caregiver;

  @override
  void initState() {
    super.initState();
    _patientDoseProvider = DoseProvider();
    _patientMedicationProvider = MedicationProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPatientData();
    });
  }

  Future<void> _loadPatientData() async {
    await Future.wait([
      _patientDoseProvider.load(widget.link.patientId, scheduleReminders: false),
      _patientMedicationProvider.load(widget.link.patientId),
    ]);
  }

  @override
  void dispose() {
    _patientDoseProvider.dispose();
    _patientMedicationProvider.dispose();
    super.dispose();
  }

  void _openVoiceRecorder({DoseInstance? dose}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VoiceRecorderPage(
        patientId: widget.link.patientId,
        patientName: widget.link.patientName,
        doseId: dose?.id,
        medicationName: dose?.medicationName,
        doseAmount: dose?.doseAmount,
        scheduledAt: dose?.scheduledAt,
      ),
    ));
  }

  void _openMedication(Medication medication) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CaregiverMedicationDetailPage(
        medication: medication,
        patientName: widget.link.patientName,
        canManageDoses: _canManageDoses,
      ),
    ));
  }

  Medication? _medicationFor(DoseInstance dose) {
    for (final medication in _patientMedicationProvider.medications) {
      if (medication.id == dose.medicationId) return medication;
    }
    return null;
  }

  Widget _sectionHeader(BuildContext context, String title, {required IconData icon}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        ]),
      );

  Widget _patientHero(BuildContext context) {
    final role = widget.link.role == CaregiverRole.primary
        ? _tr(context, 'مرافق رئيسي', 'Primary caregiver', 'Accompagnant principal')
        : widget.link.role == CaregiverRole.viewer
            ? _tr(context, 'فرد العائلة', 'Family member', 'Membre de la famille')
            : _tr(context, 'مرافق', 'Caregiver', 'Accompagnant');
    final relationship = widget.link.relationshipLabel;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        const CircleAvatar(radius: 32, backgroundColor: Color(0x33FFFFFF), child: Icon(Icons.person_rounded, color: Colors.white, size: 34)),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.link.patientName, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(relationship != null && relationship.isNotEmpty ? '$relationship · $role' : role, style: TextStyle(color: Colors.white.withValues(alpha: .88), fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }

  Widget _medicationTile(Medication medication) {
    final imageFuture = _patientMedicationProvider.signedMedicationImageUrl(medication.imageUrl);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openMedication(medication),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            FutureBuilder<String?>(
              future: imageFuture,
              builder: (context, snapshot) {
                final url = snapshot.data;
                return Container(
                  width: 64,
                  height: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)),
                  child: url == null || url.isEmpty
                      ? const Icon(Icons.medication_rounded, color: AppColors.primary)
                      : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.medication_rounded, color: AppColors.primary)),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(medication.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              if ((medication.genericName ?? '').trim().isNotEmpty) Text(medication.genericName!.trim(), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text([
                if ((medication.strength ?? '').trim().isNotEmpty) medication.strength!.trim(),
                if ((medication.dosageForm ?? '').trim().isNotEmpty) medication.dosageForm!.trim(),
              ].join(' • ')),
            ])),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      ),
    );
  }

  Widget _doseCard(DoseInstance dose) {
    final medication = _medicationFor(dose);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DoseCard(
        dose: dose,
        medication: medication,
        imageUrlFuture: medication == null ? null : _patientMedicationProvider.signedMedicationImageUrl(medication.imageUrl),
        onTap: medication == null ? () => _openVoiceRecorder(dose: dose) : () => _openMedication(medication),
        onConfirm: _canManageDoses ? () => _patientDoseProvider.confirm(dose, source: 'CAREGIVER') : null,
        onSnooze: _canManageDoses ? () => _patientDoseProvider.snooze(dose, source: 'CAREGIVER') : null,
        onSkip: _canManageDoses ? () => _patientDoseProvider.skip(dose, source: 'CAREGIVER') : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DoseProvider>.value(value: _patientDoseProvider),
        ChangeNotifierProvider<MedicationProvider>.value(value: _patientMedicationProvider),
      ],
      child: Consumer2<DoseProvider, MedicationProvider>(
        builder: (context, p, medications, _) {
          final loading = p.isLoading || medications.isLoading;
          final highlightedDose = widget.initialDoseId == null ? null : p.all.cast<DoseInstance?>().firstWhere((d) => d?.id == widget.initialDoseId, orElse: () => null);
          final todayDoses = p.todayDoses.where((d) => d.id != widget.initialDoseId).toList();
          return Scaffold(
            appBar: AppBar(title: Text(widget.link.patientName)),
            body: loading && p.all.isEmpty && medications.medications.isEmpty
                ? const LoadingIndicator()
                : RefreshIndicator(
                    onRefresh: _loadPatientData,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                      children: [
                        _patientHero(context),
                        const SizedBox(height: 18),
                        _sectionHeader(context, _tr(context, 'أدوية المريض', 'Patient medications', 'Médicaments du patient'), icon: Icons.medication_rounded),
                        if (medications.medications.isEmpty)
                          Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(l.noScheduledMedicines, textAlign: TextAlign.center)))
                        else
                          ...medications.medications.map(_medicationTile),
                        const SizedBox(height: 10),
                        _sectionHeader(context, _tr(context, 'نسبة الالتزام', 'Medication adherence', 'Observance du traitement'), icon: Icons.insights_rounded),
                        Card(child: Padding(padding: const EdgeInsets.all(16), child: AdherenceChart(stats: AdherenceCalculator.compute(p.all)))),
                        const SizedBox(height: 18),
                        _sectionHeader(context, l.today, icon: Icons.today_rounded),
                        if (highlightedDose != null) _doseCard(highlightedDose),
                        if (todayDoses.isEmpty && highlightedDose == null)
                          Card(child: Padding(padding: const EdgeInsets.all(22), child: Text(l.noScheduledMedicines, textAlign: TextAlign.center)))
                        else
                          ...todayDoses.map(_doseCard),
                        const SizedBox(height: 12),
                        Card(
                          color: AppColors.primary.withValues(alpha: .055),
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.mic_rounded)),
                            title: Text(l.sendGeneralVoice, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(_tr(context, 'أرسل رسالة صوتية عامة للمريض.', 'Send a general voice message to the patient.', 'Envoyer un message vocal général au patient.')),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _openVoiceRecorder(),
                          ),
                        ),
                        if (_canManageDoses) ...[
                          const SizedBox(height: 8),
                          Center(child: TextButton.icon(
                            onPressed: () => _confirmUnlink(context),
                            icon: const Icon(Icons.link_off_rounded, color: AppColors.danger),
                            label: Text(l.removeLink, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                          )),
                        ],
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Future<void> _confirmUnlink(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.removeLinkTitle),
        content: Text(l.removeLinkBody(widget.link.patientName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.removeLink)),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await CaregiverRepository().unlink(widget.link.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

String _tr(BuildContext c, String ar, String en, String fr) {
  switch (Localizations.localeOf(c).languageCode) {
    case 'en': return en;
    case 'fr': return fr;
    default: return ar;
  }
}
