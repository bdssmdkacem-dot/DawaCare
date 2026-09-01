import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../models/dose_instance.dart';

class DoseCard extends StatelessWidget {
  final DoseInstance dose;
  final VoidCallback? onConfirm;
  final VoidCallback? onSnooze;
  final VoidCallback? onSkip;
  final bool compact;

  const DoseCard({
    super.key,
    required this.dose,
    this.onConfirm,
    this.onSnooze,
    this.onSkip,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = AppColors.statusColor(_dbStatus);
    final isActionable = dose.status == DoseStatus.pending ||
        dose.status == DoseStatus.reminderSent ||
        dose.status == DoseStatus.snoozed;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.medication_liquid_rounded, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dose.medicationName,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text('${dose.doseAmount} — ${DateTimeUtils.formatTime(dose.scheduledAt)}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                _StatusChip(status: dose.status),
              ],
            ),
            if (isActionable && !compact) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('أخذت الدواء'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSnooze,
                      child: const Text('لاحقًا'),
                    ),
                  ),
                ],
              ),
              TextButton(onPressed: onSkip, child: const Text('تخطي هذه الجرعة')),
            ],
          ],
        ),
      ),
    );
  }

  String get _dbStatus {
    switch (dose.status) {
      case DoseStatus.pending:
        return 'PENDING';
      case DoseStatus.reminderSent:
        return 'REMINDER_SENT';
      case DoseStatus.snoozed:
        return 'SNOOZED';
      case DoseStatus.taken:
        return 'TAKEN';
      case DoseStatus.missed:
        return 'MISSED';
      case DoseStatus.skipped:
        return 'SKIPPED';
      case DoseStatus.cancelled:
        return 'CANCELLED';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final DoseStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      DoseStatus.taken => ('أُخذت', AppColors.success),
      DoseStatus.missed => ('فائتة', AppColors.danger),
      DoseStatus.snoozed => ('مؤجلة', AppColors.warning),
      DoseStatus.reminderSent => ('تذكير', AppColors.warning),
      DoseStatus.skipped => ('متخطاة', AppColors.neutral),
      DoseStatus.cancelled => ('ملغاة', AppColors.neutral),
      DoseStatus.pending => ('قادمة', AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
