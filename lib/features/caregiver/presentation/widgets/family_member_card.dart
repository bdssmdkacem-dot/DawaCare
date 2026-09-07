import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../models/caregiver_link.dart';

/// Presentation-only card for a linked family member.
///
/// It deliberately contains no Supabase/network calls so it is safe to render
/// in widget tests and keeps the Family page independent from backend state.
class FamilyMemberCard extends StatelessWidget {
  final CaregiverLink link;
  final VoidCallback onOpen;
  final VoidCallback onProfile;

  const FamilyMemberCard({
    super.key,
    required this.link,
    required this.onOpen,
    required this.onProfile,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'م';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
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
    if (days <= 0) return _tr(context, 'اليوم', 'Today', "Aujourd’hui");
    if (days == 1) return _tr(context, 'منذ يوم', '1 day ago', 'Il y a 1 jour');
    if (days < 7) return _tr(context, 'منذ $days أيام', '$days days ago', 'Il y a $days jours');
    final weeks = days ~/ 7;
    if (weeks == 1) return _tr(context, 'منذ أسبوع', '1 week ago', 'Il y a 1 semaine');
    if (weeks < 5) return _tr(context, 'منذ $weeks أسابيع', '$weeks weeks ago', 'Il y a $weeks semaines');
    final months = days ~/ 30;
    if (months == 1) return _tr(context, 'منذ شهر', '1 month ago', 'Il y a 1 mois');
    return _tr(context, 'منذ $months أشهر', '$months months ago', 'Il y a $months mois');
  }

  String _tr(BuildContext context, String ar, String en, String fr) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'en':
        return en;
      case 'fr':
        return fr;
      default:
        return ar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final relationship = link.relationshipLabel?.trim();
    final role = _roleLabel(context);
    final hasAvatar = link.patientAvatarUrl?.trim().isNotEmpty == true;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onProfile,
                    child: CircleAvatar(
                      radius: 29,
                      backgroundColor: AppColors.primary.withValues(alpha: .10),
                      backgroundImage: hasAvatar ? NetworkImage(link.patientAvatarUrl!.trim()) : null,
                      onBackgroundImageError: hasAvatar ? (_, __) {} : null,
                      child: hasAvatar
                          ? null
                          : Text(
                              _initials(link.patientName),
                              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          link.patientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          relationship != null && relationship.isNotEmpty ? '$relationship · $role' : role,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .055),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _tr(context, 'الرابط نشط', 'Connection active', 'Liaison active'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      _createdLabel(context),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
