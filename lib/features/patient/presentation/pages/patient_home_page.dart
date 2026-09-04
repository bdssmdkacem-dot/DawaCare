import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/dose_instance.dart';
import '../../../../models/medication.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../doses/presentation/providers/dose_provider.dart';
import '../../../medications/presentation/providers/medication_provider.dart';
import '../widgets/dose_card.dart';
import 'voice_messages_page.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});
  @override State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  bool _loadedOnce = false;
  String? _loadingPatientId;
  String? _loadingMedicationPatientId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureOwnDataLoaded();
  }

  void _ensureOwnDataLoaded() {
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId == null) return;

    final doseProvider = context.read<DoseProvider>();
    final medicationProvider = context.read<MedicationProvider>();
    final dosesLoaded = doseProvider.patientId == userId;
    final medicationsLoaded = medicationProvider.patientId == userId;

    if ((!_loadedOnce || !dosesLoaded) && _loadingPatientId != userId) {
      _loadedOnce = true;
      _loadingPatientId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await context.read<DoseProvider>().load(userId);
        } finally {
          if (mounted && _loadingPatientId == userId) _loadingPatientId = null;
        }
      });
    }

    if (!medicationsLoaded && _loadingMedicationPatientId != userId) {
      _loadingMedicationPatientId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await context.read<MedicationProvider>().load(userId);
        } finally {
          if (mounted && _loadingMedicationPatientId == userId) _loadingMedicationPatientId = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final doseProvider = context.watch<DoseProvider>();
    final medicationProvider = context.watch<MedicationProvider>();
    final userId = auth.profile?.id;

    if (userId != null && doseProvider.patientId != userId) _ensureOwnDataLoaded();
    if (userId != null && medicationProvider.patientId != userId) _ensureOwnDataLoaded();

    final showingOwnDoses = userId != null && doseProvider.patientId == userId;
    final showingOwnMedications = userId != null && medicationProvider.patientId == userId;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(children: [
          Container(width: 34, height: 34, padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: Image.asset('assets/icon/app_icon.png')),
          const SizedBox(width: 10),
          Text(l.today),
        ]),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (userId != null) {
            await Future.wait([
              context.read<DoseProvider>().load(userId),
              context.read<MedicationProvider>().load(userId),
            ]);
          }
        },
        child: !showingOwnDoses || !showingOwnMedications || doseProvider.isLoading || medicationProvider.isLoading
            ? const LoadingIndicator()
            : _buildBody(doseProvider, medicationProvider, l),
      ),
    );
  }

  Widget _buildBody(DoseProvider provider, MedicationProvider medicationProvider, AppLocalizations l) {
    if ((provider.isLoading || medicationProvider.isLoading) && provider.all.isEmpty) return const LoadingIndicator();
    if (provider.error != null && provider.all.isEmpty) return EmptyState(icon: Icons.wifi_off_rounded, title: provider.error!, subtitle: l.pullToRetry);

    final today = provider.todayDoses;
    if (today.isEmpty) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 32), children: [
        _dayHeader(l),
        const SizedBox(height: 16),
        _voiceMessagesButton(l),
        const SizedBox(height: 28),
        EmptyState(icon: Icons.check_circle_outline_rounded, title: l.noScheduledMedicines, subtitle: l.addFirstMedicine),
      ]);
    }

    final now = DateTime.now();
    final next = today.firstWhere(
      (d) => d.status == DoseStatus.pending || d.status == DoseStatus.reminderSent || d.status == DoseStatus.snoozed,
      orElse: () => today.first,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _dayHeader(l, now: now),
        const SizedBox(height: 16),
        _voiceMessagesButton(l),
        const SizedBox(height: 16),
        ...today.map((dose) {
          Medication? medication;
          for (final item in medicationProvider.medications) {
            if (item.id == dose.medicationId) {
              medication = item;
              break;
            }
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DoseCard(
              dose: dose,
              medication: medication,
              imageUrlFuture: medication == null ? null : medicationProvider.signedMedicationImageUrl(medication.imageUrl),
              compact: dose.id != next.id && !(dose.status == DoseStatus.pending || dose.status == DoseStatus.reminderSent || dose.status == DoseStatus.snoozed),
              onConfirm: () => context.read<DoseProvider>().confirm(dose),
              onSnooze: () => context.read<DoseProvider>().snooze(dose),
              onSkip: () => _confirmSkip(dose),
            ),
          );
        }),
      ],
    );
  }

  Widget _dayHeader(AppLocalizations l, {DateTime? now}) {
    final date = now ?? DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .16), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.calendar_today_rounded, color: Colors.white)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.today, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(DateTimeUtils.relativeDayLabel(date), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))])),
        const Icon(Icons.medication_rounded, color: Colors.white, size: 28),
      ]),
    );
  }

  Widget _voiceMessagesButton(AppLocalizations l) => Card(
    elevation: 0,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.mic_rounded, color: AppColors.accentDark)),
      title: Text(l.followUpMessages, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(l.followUpMessagesSubtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VoiceMessagesPage())),
    ),
  );

  Future<void> _confirmSkip(DoseInstance dose) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(l.skipDoseTitle), content: Text(l.skippedDose(dose.medicationName)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)), TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.skip))]));
    if (confirmed == true && mounted) await context.read<DoseProvider>().skip(dose);
  }
}
