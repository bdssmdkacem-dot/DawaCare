import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../models/caregiver_link.dart';
import '../../../../models/family_member_summary.dart';
import '../providers/caregiver_provider.dart';

/// Presentation card for a linked family member.
///
/// Summary data is read from an optional [CaregiverProvider] already present
/// above the page. No network request is started by the card itself.
class FamilyMemberCard extends StatelessWidget {
  final CaregiverLink link;
  final FamilyMemberSummary? summary;
  final bool summaryLoading;
  final VoidCallback onOpen;
  final VoidCallback onProfile;

  const FamilyMemberCard({
    super.key,
    required this.link,
    this.summary,
    this.summaryLoading = false,
    required this.onOpen,
    required this.onProfile,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'م';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.first.toString() + parts.last.characters.first.toString()).toUpperCase();
  }

  String _roleLabel(BuildContext context) {
    switch (link.role) {
      case CaregiverRole.viewer:
        return _tr(context, 'فرد العائلة', 'Family member', 'Membre de la famille');
      case CaregiverRole.primary:
        return _tr(context, 'مرافق رئيسي', 'Primary caregiver', 'Accompagnant principal');
      case CaregiverRole.caregiver:
        return _tr(context, 'مرافق', 'Caregiver', 'Accompagnant');
    }
  }

  String _createdLabel(BuildContext context) {
    final elapsed = DateTime.now().difference(link.createdAt);
    final days = elapsed.inDays;
    if (days <= 0) return _tr(context, 'اليوم', 'Today', 'Aujourd’hui');
    if (days == 1) return _tr(context, 'منذ يوم', '1 day ago', 'Il y a 1 jour');
    if (days < 7) return _tr(context, 'منذ $days أيام', '$days days ago', 'Il y a $days jours');
    final weeks = days ~/ 7;
    if (weeks == 1) return _tr(context, 'منذ أسبوع', '1 week ago', 'Il y a 1 semaine');
    if (weeks < 5) return _tr(context, 'منذ $weeks أسابيع', '$weeks weeks ago', 'Il y a $weeks semaines');
    final months = days ~/ 30;
    if (months == 1) return _tr(context, 'منذ شهر', '1 month ago', 'Il y a 1 mois');
    return _tr(context, 'منذ $months أشهر', '$months months ago', 'Il y a $months months');
  }

  String _tr(BuildContext context, String ar, String en, String fr) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'en': return en;
      case 'fr': return fr;
      default: return ar;
    }
  }

  Widget _metric(BuildContext context, IconData icon, String value, String label) {
    return Expanded(child: Column(children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
    ]));
  }

  Widget _summary(BuildContext context, FamilyMemberSummary? data, bool loading) {
    if (loading && data == null) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(minHeight: 3));
    }
    final summary = data ?? const FamilyMemberSummary.empty();
    final adherence = (summary.adherence * 100).round();
    return Column(children: [
      const Divider(height: 20),
      Row(children: [
        _metric(context, Icons.medication_outlined, '${summary.activeMedicationCount}', _tr(context, 'أدوية نشطة', 'Active meds', 'Médicaments actifs')),
        _metric(context, Icons.today_rounded, '${summary.todayDoseCount}', _tr(context, 'جرعات اليوم', 'Today', 'Aujourd’hui')),
        _metric(context, Icons.check_circle_outline_rounded, '$adherence%', _tr(context, 'الالتزام', 'Adherence', 'Observance')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Icon(summary.missedDoseCount > 0 ? Icons.warning_amber_rounded : Icons.verified_rounded, size: 17, color: summary.missedDoseCount > 0 ? Colors.orange : AppColors.primary),
        const SizedBox(width: 6),
        Expanded(child: Text(
          summary.missedDoseCount > 0
              ? _tr(context, '${summary.missedDoseCount} جرعات فائتة اليوم', '${summary.missedDoseCount} missed doses today', '${summary.missedDoseCount} doses manquées aujourd’hui')
              : _tr(context, 'لا توجد جرعات فائتة اليوم', 'No missed doses today', 'Aucune dose manquée aujourd’hui'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        )),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final relationship = link.relationshipLabel?.trim();
    final role = _roleLabel(context);
    final hasAvatar = link.patientAvatarUrl?.trim().isNotEmpty == true;
    final provider = context.read<CaregiverProvider?>();
    final providerSummary = provider?.summaryFor(link.patientId);
    final effectiveSummary = summary ?? providerSummary;
    final effectiveLoading = summaryLoading || (provider?.isSummariesLoading == true && providerSummary == null);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onOpen,
        child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          Row(children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onProfile,
              child: CircleAvatar(
                radius: 29,
                backgroundColor: AppColors.primary.withValues(alpha: .10),
                backgroundImage: hasAvatar ? NetworkImage(link.patientAvatarUrl!.trim()) : null,
                onBackgroundImageError: hasAvatar ? (_, __) {} : null,
                child: hasAvatar ? null : Text(_initials(link.patientName), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(link.patientName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              Text(relationship != null && relationship.isNotEmpty ? '$relationship · $role' : role, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ])),
            const Icon(Icons.chevron_right_rounded),
          ]),
          _summary(context, effectiveSummary, effectiveLoading),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .055), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(_tr(context, 'الرابط نشط', 'Connection active', 'Liaison active'), style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(_createdLabel(context), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ])),
      ),
    );
  }
}
