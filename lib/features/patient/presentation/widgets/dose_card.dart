import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../models/dose_instance.dart';
import '../../../../models/medication.dart';

class DoseCard extends StatelessWidget {
  final DoseInstance dose;
  final Medication? medication;
  final Future<String?>? imageUrlFuture;
  final VoidCallback? onConfirm, onSnooze, onSkip, onTap;
  final bool compact;

  const DoseCard({
    super.key,
    required this.dose,
    this.medication,
    this.imageUrlFuture,
    this.onConfirm,
    this.onSnooze,
    this.onSkip,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final statusColor = AppColors.statusColor(_dbStatus);
    final actionable = dose.status == DoseStatus.pending ||
        dose.status == DoseStatus.reminderSent ||
        dose.status == DoseStatus.snoozed;

    final card = Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MedicationImage(
                  imageUrlFuture: imageUrlFuture,
                  size: compact ? 54 : 64,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dose.medicationName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${l.doseAmount}: ${dose.doseAmount} · ${DateTimeUtils.formatTime(dose.scheduledAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (!compact && medication != null) ...[
                        const SizedBox(height: 7),
                        _MedicationDetails(medication: medication!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: dose.status),
              ],
            ),
            if (actionable && !compact) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(_tr(context, 'أخذت الدواء', 'I took it', 'J’ai pris le médicament')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSnooze,
                      child: Text(_tr(context, 'لاحقًا', 'Later', 'Plus tard')),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onSkip,
                child: Text(l.skip),
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: _tr(context, 'فتح ${dose.medicationName}', 'Open ${dose.medicationName}', 'Ouvrir ${dose.medicationName}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: card,
      ),
    );
  }

  String get _dbStatus => switch (dose.status) {
        DoseStatus.pending => 'PENDING',
        DoseStatus.reminderSent => 'REMINDER_SENT',
        DoseStatus.snoozed => 'SNOOZED',
        DoseStatus.taken => 'TAKEN',
        DoseStatus.missed => 'MISSED',
        DoseStatus.skipped => 'SKIPPED',
        DoseStatus.cancelled => 'CANCELLED',
      };
}

class _MedicationImage extends StatelessWidget {
  final Future<String?>? imageUrlFuture;
  final double size;

  const _MedicationImage({required this.imageUrlFuture, required this.size});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.medication_liquid_rounded, color: AppColors.primary, size: size * .48),
    );

    if (imageUrlFuture == null) return placeholder;

    return FutureBuilder<String?>(
      future: imageUrlFuture,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) return placeholder;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            errorBuilder: (_, __, ___) => placeholder,
          ),
        );
      },
    );
  }
}

class _MedicationDetails extends StatelessWidget {
  final Medication medication;
  const _MedicationDetails({required this.medication});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final details = <String>[];
    if (medication.strength?.trim().isNotEmpty == true) details.add(medication.strength!.trim());
    if (medication.dosageForm?.trim().isNotEmpty == true) details.add(l.dosageFormLabel(medication.dosageForm!.trim()));
    if (medication.genericName?.trim().isNotEmpty == true) details.add(medication.genericName!.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (details.isNotEmpty)
          Text(
            details.join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        if (medication.instructions?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 3),
          Text(
            medication.instructions!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

String _tr(BuildContext c, String ar, String en, String fr) =>
    switch (AppLocalizations.of(c).locale.languageCode) {
      'en' => en,
      'fr' => fr,
      _ => ar,
    };

class _StatusChip extends StatelessWidget {
  final DoseStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = switch (status) {
      DoseStatus.taken => AppColors.success,
      DoseStatus.missed => AppColors.danger,
      DoseStatus.snoozed => AppColors.warning,
      DoseStatus.reminderSent => AppColors.warning,
      DoseStatus.skipped => AppColors.neutral,
      DoseStatus.cancelled => AppColors.neutral,
      DoseStatus.pending => AppColors.primary,
    };
    final label = switch (status) {
      DoseStatus.taken => 'TAKEN',
      DoseStatus.missed => 'MISSED',
      DoseStatus.snoozed => 'SNOOZED',
      DoseStatus.reminderSent => 'REMINDER_SENT',
      DoseStatus.skipped => 'SKIPPED',
      DoseStatus.cancelled => 'CANCELLED',
      DoseStatus.pending => 'PENDING',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        l.doseStatus(label),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}
