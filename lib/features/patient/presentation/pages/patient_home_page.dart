import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/caregiver_link.dart';
import '../../../../models/dose_instance.dart';
import '../../../../models/medication.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../caregiver/data/caregiver_repository.dart';
import '../../../doses/data/dose_repository.dart';
import '../../../doses/presentation/providers/dose_provider.dart';
import '../../../medications/data/medication_repository.dart';
import '../../../medications/presentation/providers/medication_provider.dart';
import '../widgets/dose_card.dart';
import 'voice_messages_page.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  final CaregiverRepository _caregiverRepository = CaregiverRepository();
  final DoseRepository _doseRepository = DoseRepository();
  final MedicationRepository _medicationRepository = MedicationRepository();

  bool _loadedOnce = false;
  String? _loadingPatientId;
  String? _loadingMedicationPatientId;
  bool _loadingFollowed = false;
  String? _followedError;
  List<CaregiverLink> _followedPatients = [];
  final Map<String, List<DoseInstance>> _followedDoses = {};
  final Map<String, List<Medication>> _followedMedications = {};

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
        final provider = context.read<DoseProvider>();
        try {
          await provider.load(userId);
        } finally {
          if (mounted && _loadingPatientId == userId) {
            setState(() => _loadingPatientId = null);
          }
        }
      });
    }

    if (!medicationsLoaded && _loadingMedicationPatientId != userId) {
      _loadingMedicationPatientId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final provider = context.read<MedicationProvider>();
        try {
          await provider.load(userId);
        } finally {
          if (mounted && _loadingMedicationPatientId == userId) {
            setState(() => _loadingMedicationPatientId = null);
          }
        }
      });
    }

    if (!_loadingFollowed) {
      _loadFollowedPatients(userId);
    }
  }

  Future<void> _loadFollowedPatients(String caregiverId) async {
    if (_loadingFollowed) return;
    _loadingFollowed = true;
    if (mounted) setState(() => _followedError = null);

    try {
      final links = await _caregiverRepository.fetchLinkedPatients(caregiverId);
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from.add(const Duration(days: 1));

      final doseResults = await Future.wait(
        links.map((link) => _doseRepository.fetchDosesForRange(
              link.patientId,
              from: from,
              to: to,
            )),
      );
      final medicationResults = await Future.wait(
        links.map((link) => _medicationRepository.fetchMedications(link.patientId)),
      );

      if (!mounted) return;
      setState(() {
        _followedPatients = links;
        _followedDoses
          ..clear()
          ..addEntries(
            List.generate(
              links.length,
              (index) => MapEntry(links[index].patientId, doseResults[index]),
            ),
          );
        _followedMedications
          ..clear()
          ..addEntries(
            List.generate(
              links.length,
              (index) => MapEntry(links[index].patientId, medicationResults[index]),
            ),
          );
      });
    } catch (_) {
      if (mounted) {
        setState(() => _followedError = 'تعذّر تحميل أدوية الأشخاص الذين تتابعهم.');
      }
    } finally {
      if (mounted) setState(() => _loadingFollowed = false);
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
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset('assets/icon/app_icon.png'),
            ),
            const SizedBox(width: 10),
            Text(l.today),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (userId == null) return;
          await Future.wait([
            context.read<DoseProvider>().load(userId),
            context.read<MedicationProvider>().load(userId),
            _loadFollowedPatients(userId),
          ]);
        },
        child: !showingOwnDoses || !showingOwnMedications || doseProvider.isLoading || medicationProvider.isLoading
            ? const LoadingIndicator()
            : _buildBody(doseProvider, medicationProvider, l),
      ),
    );
  }

  Widget _buildBody(
    DoseProvider provider,
    MedicationProvider medicationProvider,
    AppLocalizations l,
  ) {
    if ((provider.isLoading || medicationProvider.isLoading) && provider.all.isEmpty) {
      return const LoadingIndicator();
    }
    if (provider.error != null && provider.all.isEmpty) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: provider.error!,
        subtitle: l.pullToRetry,
      );
    }

    final today = provider.todayDoses;
    final hasFollowedDoses = _followedDoses.values.any((doses) => doses.isNotEmpty);
    final hasFollowedPatients = _followedPatients.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _dayHeader(l),
        const SizedBox(height: 16),
        _voiceMessagesButton(l),
        const SizedBox(height: 20),
        _sectionTitle('أدويتي', Icons.person_rounded),
        const SizedBox(height: 10),
        if (today.isEmpty)
          _emptySection('لا توجد جرعات مجدولة لك اليوم.')
        else
          _buildOwnDoses(today, medicationProvider),
        if (_loadingFollowed || hasFollowedPatients) ...[
          const SizedBox(height: 22),
          _sectionTitle('أدوية الأشخاص الذين أتابعهم', Icons.groups_rounded),
          const SizedBox(height: 10),
          if (_loadingFollowed && !hasFollowedPatients)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_followedError != null && !hasFollowedDoses)
            _emptySection(_followedError!)
          else
            _buildFollowedPatients(),
        ],
      ],
    );
  }

  List<Widget> _buildOwnDoses(
    List<DoseInstance> doses,
    MedicationProvider medicationProvider,
  ) {
    final next = doses.firstWhere(
      (d) => d.status == DoseStatus.pending ||
          d.status == DoseStatus.reminderSent ||
          d.status == DoseStatus.snoozed,
      orElse: () => doses.first,
    );

    return doses.map((dose) {
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
          imageUrlFuture: medication == null
              ? null
              : medicationProvider.signedMedicationImageUrl(medication.imageUrl),
          compact: dose.id != next.id &&
              !(dose.status == DoseStatus.pending ||
                  dose.status == DoseStatus.reminderSent ||
                  dose.status == DoseStatus.snoozed),
          onConfirm: () => context.read<DoseProvider>().confirm(dose),
          onSnooze: () => context.read<DoseProvider>().snooze(dose),
          onSkip: () => _confirmSkip(dose),
        ),
      );
    }).toList();
  }

  List<Widget> _buildFollowedPatients() {
    final widgets = <Widget>[];
    for (final link in _followedPatients) {
      final doses = _followedDoses[link.patientId] ?? const <DoseInstance>[];
      if (doses.isEmpty) {
        widgets.add(_patientHeader(link, subtitle: 'لا توجد جرعات مجدولة اليوم'));
        continue;
      }

      widgets.add(_patientHeader(link, subtitle: '${doses.length} جرعة اليوم'));
      final medications = _followedMedications[link.patientId] ?? const <Medication>[];
      for (final dose in doses) {
        Medication? medication;
        for (final item in medications) {
          if (item.id == dose.medicationId) {
            medication = item;
            break;
          }
        }
        final canManage = link.role == CaregiverRole.primary ||
            link.role == CaregiverRole.caregiver;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DoseCard(
              dose: dose,
              medication: medication,
              imageUrlFuture: medication == null
                  ? null
                  : _medicationRepository.signedMedicationImageUrl(medication.imageUrl),
              onConfirm: canManage
                  ? () => _updateFollowedDose(dose, DoseStatus.taken)
                  : null,
              onSnooze: canManage
                  ? () => _updateFollowedDose(dose, DoseStatus.snoozed)
                  : null,
              onSkip: canManage
                  ? () => _updateFollowedDose(dose, DoseStatus.skipped)
                  : null,
            ),
          ),
        );
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Widget _patientHeader(CaregiverLink link, {required String subtitle}) {
    final name = link.patientName.trim().isEmpty ? 'مريض' : link.patientName.trim();
    final initials = _initials(name);
    final avatarUrl = link.patientAvatarUrl;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(initials, style: const TextStyle(fontWeight: FontWeight.w800))
              : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: _roleChip(link.role),
      ),
    );
  }

  Widget _roleChip(CaregiverRole role) {
    final text = switch (role) {
      CaregiverRole.primary => 'مرافق أساسي',
      CaregiverRole.caregiver => 'مرافق',
      CaregiverRole.viewer => 'فرد من العائلة',
    };
    return Chip(
      label: Text(text),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _updateFollowedDose(DoseInstance dose, DoseStatus status) async {
    try {
      final updated = await _doseRepository.updateStatus(
        dose,
        status,
        source: 'CAREGIVER',
      );
      if (!mounted) return;
      final doses = _followedDoses[dose.patientId];
      if (doses != null) {
        final index = doses.indexWhere((item) => item.id == dose.id);
        if (index != -1) doses[index] = updated;
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تحديث حالة الجرعة.')),
      );
    }
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _emptySection(String text) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text),
        ),
      );

  Widget _dayHeader(AppLocalizations l) {
    final date = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_today_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.today, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(DateTimeUtils.relativeDayLabel(date), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const Icon(Icons.medication_rounded, color: Colors.white, size: 28),
        ],
      ),
    );
  }

  Widget _voiceMessagesButton(AppLocalizations l) => Card(
        elevation: 0,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.mic_rounded, color: AppColors.accentDark),
          ),
          title: Text(l.followUpMessages, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(l.followUpMessagesSubtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VoiceMessagesPage()),
          ),
        ),
      );

  Future<void> _confirmSkip(DoseInstance dose) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.skipDoseTitle),
        content: Text(l.skippedDose(dose.medicationName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.skip)),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<DoseProvider>().skip(dose);
    }
  }

  String _initials(String value) {
    final parts = value.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (value.length >= 2) return value.substring(0, 2).toUpperCase();
    return value.isEmpty ? '?' : value[0].toUpperCase();
  }
}
