import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../models/dose_instance.dart';
import '../../../../models/medication.dart';
import '../../../medications/presentation/widgets/medication_avatar.dart';

/// Prominent presentation for the single dose the patient should act on next.
/// Actions remain optional so the same widget is safe for Viewer/caregiver
/// read-only contexts.
class NextDoseCard extends StatelessWidget {
  const NextDoseCard({
    super.key,
    required this.dose,
    this.medication,
    this.imageUrlFuture,
    this.onConfirm,
    this.onSnooze,
    this.onSkip,
  });

  final DoseInstance dose;
  final Medication? medication;
  final Future<String?>? imageUrlFuture;
  final VoidCallback? onConfirm;
  final VoidCallback? onSnooze;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final actionable = onConfirm != null || onSnooze != null || onSkip != null;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primary.withValues(alpha: .20)),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: .12),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (medication != null)
                  FutureBuilder<String?>(
                    future: imageUrlFuture,
                    builder: (context, snapshot) => MedicationAvatar(
                      name: medication!.name,
                      imageUrl: snapshot.data,
                      size: 42,
                      radius: 14,
                    ),
                  )
                else
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.tr('الجرعة التالية', 'Next dose', 'Prochaine dose'),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  _formatTime(dose.scheduledAt, l),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              dose.medicationName,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              dose.doseAmount,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (actionable) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (onConfirm != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onConfirm,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(l.tr('تم أخذها', 'Taken', 'Prise')),
                      ),
                    ),
                  if (onConfirm != null && onSnooze != null) const SizedBox(width: 8),
                  if (onSnooze != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSnooze,
                        icon: const Icon(Icons.snooze_rounded),
                        label: Text(l.tr('تأجيل', 'Snooze', 'Reporter')),
                      ),
                    ),
                ],
              ),
              if (onSkip != null) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: onSkip,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: Text(l.tr('تخطي الجرعة', 'Skip dose', 'Ignorer la dose')),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime value, AppLocalizations l) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? l.tr('م', 'PM', 'PM') : l.tr('ص', 'AM', 'AM');
    return '$hour:$minute $suffix';
  }
}
