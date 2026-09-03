import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/caregiver_link.dart';
import '../../../../models/dose_instance.dart';
import '../../../doses/presentation/providers/dose_provider.dart';
import '../../../patient/presentation/widgets/dose_card.dart';
import '../../data/caregiver_repository.dart';
import '../../domain/adherence_calculator.dart';
import '../widgets/adherence_chart.dart';
import 'voice_recorder_page.dart';

class PatientDetailPage extends StatefulWidget {
  final CaregiverLink link;
  final String? initialDoseId;
  const PatientDetailPage({super.key, required this.link, this.initialDoseId});
  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  bool get _canManageDoses => widget.link.role == CaregiverRole.primary || widget.link.role == CaregiverRole.caregiver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<DoseProvider>().load(widget.link.patientId, scheduleReminders: false));
  }

  void _openVoiceRecorder({DoseInstance? dose}) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => VoiceRecorderPage(patientId: widget.link.patientId, patientName: widget.link.patientName, doseId: dose?.id, medicationName: dose?.medicationName, doseAmount: dose?.doseAmount, scheduledAt: dose?.scheduledAt)));
  }

  Widget _sectionHeader(BuildContext context, String title, {required IconData icon}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 19, color: AppColors.primary)), const SizedBox(width: 10), Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)))]));

  Widget _patientHero(BuildContext context) {
    final role = widget.link.role == CaregiverRole.primary ? _tr(context, 'مرافق رئيسي', 'Primary caregiver', 'Accompagnant principal') : widget.link.role == CaregiverRole.viewer ? _tr(context, 'فرد العائلة', 'Family member', 'Membre de la famille') : _tr(context, 'مرافق', 'Caregiver', 'Accompagnant');
    final relationship = widget.link.relationshipLabel;
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.primaryDark]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .16), blurRadius: 20, offset: const Offset(0, 8))]), child: Row(children: [Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), shape: BoxShape.circle), child: const Icon(Icons.person_rounded, color: Colors.white, size: 34)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.link.patientName, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(relationship != null && relationship.isNotEmpty ? '$relationship · $role' : role, style: TextStyle(color: Colors.white.withValues(alpha: .88), fontWeight: FontWeight.w600))]))]));
  }

  Widget _doseCard(DoseInstance dose) => Padding(padding: const EdgeInsets.only(bottom: 10), child: DoseCard(dose: dose, onTap: () => _openVoiceRecorder(dose: dose), onConfirm: _canManageDoses ? () => context.read<DoseProvider>().confirm(dose, source: 'CAREGIVER') : null, onSnooze: _canManageDoses ? () => context.read<DoseProvider>().snooze(dose, source: 'CAREGIVER') : null, onSkip: _canManageDoses ? () => context.read<DoseProvider>().skip(dose, source: 'CAREGIVER') : null));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.watch<DoseProvider>();
    final highlightedDose = widget.initialDoseId == null ? null : p.all.cast<DoseInstance?>().firstWhere((d) => d?.id == widget.initialDoseId, orElse: () => null);
    final todayDoses = p.todayDoses.where((dose) => dose.id != widget.initialDoseId).toList();
    return Scaffold(appBar: AppBar(title: Text(widget.link.patientName)), body: p.isLoading && p.all.isEmpty ? const LoadingIndicator() : RefreshIndicator(onRefresh: () => context.read<DoseProvider>().load(widget.link.patientId, scheduleReminders: false), child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), children: [
      _patientHero(context), const SizedBox(height: 20),
      if (highlightedDose != null) ...[_sectionHeader(context, _tr(context, 'الجرعة المرتبطة بالتنبيه', 'Dose linked to alert', 'Dose liée à l’alerte'), icon: Icons.warning_amber_rounded), Card(color: AppColors.danger.withValues(alpha: .055), child: Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tr(context, 'هذه هي الجرعة المرتبطة بهذا التنبيه.', 'This is the dose linked to this alert.', 'Voici la dose liée à cette alerte.'), style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 8), _doseCard(highlightedDose)]))), const SizedBox(height: 18)],
      _sectionHeader(context, _tr(context, 'نسبة الالتزام', 'Medication adherence', 'Observance du traitement'), icon: Icons.insights_rounded), Card(child: Padding(padding: const EdgeInsets.all(16), child: AdherenceChart(stats: AdherenceCalculator.compute(p.all)))), const SizedBox(height: 18),
      Card(color: AppColors.primary.withValues(alpha: .055), child: InkWell(borderRadius: BorderRadius.circular(20), onTap: () => _openVoiceRecorder(), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .12), shape: BoxShape.circle), child: const Icon(Icons.mic_rounded, color: AppColors.primary)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.sendGeneralVoice, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(_tr(context, 'أرسل رسالة صوتية عامة لهذا الشخص.', 'Send a general voice message to this person.', 'Envoyez un message vocal général à cette personne.'), style: Theme.of(context).textTheme.bodySmall)])), const Icon(Icons.chevron_right_rounded)])))), const SizedBox(height: 20),
      _sectionHeader(context, l.today, icon: Icons.today_rounded), if (p.todayDoses.isEmpty) Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24), child: Column(children: [Container(width: 58, height: 58, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .09), shape: BoxShape.circle), child: const Icon(Icons.medication_outlined, color: AppColors.primary, size: 29)), const SizedBox(height: 12), Text(l.noScheduledMedicines, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))]))) else ...todayDoses.map(_doseCard),
      if (_canManageDoses) ...[const SizedBox(height: 10), Center(child: TextButton.icon(onPressed: () => _confirmUnlink(context), icon: const Icon(Icons.link_off_rounded, color: AppColors.danger), label: Text(l.removeLink, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700))))],
    ])));
  }

  Future<void> _confirmUnlink(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(l.removeLinkTitle), content: Text(l.removeLinkBody(widget.link.patientName)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)), TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.removeLink))]));
    if (confirmed == true && context.mounted) { await CaregiverRepository().unlink(widget.link.id); if (context.mounted) Navigator.of(context).pop(); }
  }
}

String _tr(BuildContext c, String ar, String en, String fr) { switch (Localizations.localeOf(c).languageCode) { case 'en': return en; case 'fr': return fr; default: return ar; } }
