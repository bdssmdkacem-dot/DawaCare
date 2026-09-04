import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../models/dose_instance.dart';
import '../../../../models/medication.dart';

class DoseCard extends StatelessWidget {
  final DoseInstance dose;
  final Medication? medication;
  final Future<String?>? imageUrlFuture;
  final VoidCallback? onConfirm;
  final VoidCallback? onSnooze;
  final VoidCallback? onSkip;
  final VoidCallback? onTap;
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
                _MedicationImage(future: imageUrlFuture, compact: compact),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dose.medicationName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('${dose.doseAmount} • ${_time(dose.scheduledAt)}'),
                      if (medication != null) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if ((medication!.genericName ?? '').isNotEmpty)
                              Text(medication!.genericName!, style: theme.textTheme.bodySmall),
                            if ((medication!.strength ?? '').isNotEmpty)
                              Text(medication!.strength!, style: theme.textTheme.bodySmall),
                            if ((medication!.dosageForm ?? '').isNotEmpty)
                              Text(medication!.dosageForm!, style: theme.textTheme.bodySmall),
                          ],
                        ),
                        if ((medication!.instructions ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(medication!.instructions!, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ],
                  ),
                ),
                _StatusChip(
                  status: dose.status,
                  label: l.doseStatus(doseStatusToDb(dose.status)),
                ),
              ],
            ),
            if (actionable && (onConfirm != null || onSnooze != null || onSkip != null)) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onConfirm != null)
                    FilledButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(l.taken),
                    ),
                  if (onSnooze != null)
                    OutlinedButton.icon(
                      onPressed: onSnooze,
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(l.snooze),
                    ),
                  if (onSkip != null)
                    TextButton.icon(
                      onPressed: onSkip,
                      icon: const Icon(Icons.close_rounded),
                      label: Text(l.skip),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: card);
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _MedicationImage extends StatelessWidget {
  final Future<String?>? future;
  final bool compact;

  const _MedicationImage({required this.future, required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 54.0 : 64.0;
    if (future == null) return _placeholder(context, size);

    return FutureBuilder<String?>(
      future: future,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) return _placeholder(context, size);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: compact ? 162 : 192,
            cacheHeight: compact ? 162 : 192,
            errorBuilder: (_, __, ___) => _placeholder(context, size),
          ),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.medication_rounded),
      );
}

class _StatusChip extends StatelessWidget {
  final DoseStatus status;
  final String label;

  const _StatusChip({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(_icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }

  IconData get _icon {
    switch (status) {
      case DoseStatus.taken:
        return Icons.check_circle_rounded;
      case DoseStatus.missed:
        return Icons.warning_rounded;
      case DoseStatus.snoozed:
        return Icons.schedule_rounded;
      case DoseStatus.skipped:
        return Icons.remove_circle_outline_rounded;
      case DoseStatus.cancelled:
        return Icons.cancel_outlined;
      case DoseStatus.reminderSent:
        return Icons.notifications_active_rounded;
      case DoseStatus.pending:
        return Icons.access_time_rounded;
    }
  }
}
