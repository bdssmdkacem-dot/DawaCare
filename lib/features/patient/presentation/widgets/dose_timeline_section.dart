import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../models/dose_instance.dart';

/// Compact chronological timeline used below the prominent Next Dose card.
class DoseTimelineSection extends StatelessWidget {
  const DoseTimelineSection({
    super.key,
    required this.doses,
  });

  final List<DoseInstance> doses;

  @override
  Widget build(BuildContext context) {
    final ordered = [...doses]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'الجدول اليومي',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < ordered.length; index++)
              _TimelineRow(
                dose: ordered[index],
                isLast: index == ordered.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.dose, required this.isLast});

  final DoseInstance dose;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final resolved = dose.status == DoseStatus.taken ||
        dose.status == DoseStatus.skipped ||
        dose.status == DoseStatus.cancelled;
    final missed = dose.status == DoseStatus.missed;
    final icon = switch (dose.status) {
      DoseStatus.taken => Icons.check_circle_rounded,
      DoseStatus.missed => Icons.warning_amber_rounded,
      DoseStatus.skipped => Icons.skip_next_rounded,
      DoseStatus.cancelled => Icons.cancel_rounded,
      DoseStatus.snoozed => Icons.snooze_rounded,
      DoseStatus.reminderSent => Icons.notifications_active_rounded,
      DoseStatus.pending => Icons.radio_button_unchecked_rounded,
    };

    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: missed
                      ? Theme.of(context).colorScheme.error
                      : resolved
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: .75),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      _formatTime(dose.scheduledAt),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${dose.medicationName} · ${dose.doseAmount}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
