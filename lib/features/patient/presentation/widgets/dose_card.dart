import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/voice/voice_message_service.dart';
import '../../../../models/dose_instance.dart';
import '../../../../models/medication.dart';
import '../../../../models/voice_message.dart';

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

  bool get _isFollowedDose {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      return currentUserId != null && currentUserId != dose.patientId;
    } catch (_) {
      return false;
    }
  }

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
                      Text(dose.medicationName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${dose.doseAmount} • ${_time(dose.scheduledAt)}'),
                      if (medication != null) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if ((medication!.genericName ?? '').isNotEmpty) Text(medication!.genericName!, style: theme.textTheme.bodySmall),
                            if ((medication!.strength ?? '').isNotEmpty) Text(medication!.strength!, style: theme.textTheme.bodySmall),
                            if ((medication!.dosageForm ?? '').isNotEmpty) Text(medication!.dosageForm!, style: theme.textTheme.bodySmall),
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
                _StatusChip(status: dose.status, label: l.doseStatus(doseStatusToDb(dose.status))),
              ],
            ),
            if (actionable && (onConfirm != null || onSnooze != null || onSkip != null)) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onConfirm != null) FilledButton.icon(onPressed: onConfirm, icon: const Icon(Icons.check_rounded), label: Text(l.doseStatus('TAKEN'))),
                  if (onSnooze != null) OutlinedButton.icon(onPressed: onSnooze, icon: const Icon(Icons.schedule_rounded), label: Text(l.doseStatus('SNOOZED'))),
                  if (onSkip != null) TextButton.icon(onPressed: onSkip, icon: const Icon(Icons.close_rounded), label: Text(l.skip)),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    // A followed dose always keeps its exact-dose voice interaction, even
    // when the caller also supplies an onTap for medication navigation.
    final tap = _isFollowedDose ? () => _showFollowedDoseVoice(context) : onTap;
    if (tap == null) return card;
    return InkWell(onTap: tap, borderRadius: BorderRadius.circular(16), child: card);
  }

  Future<void> _showFollowedDoseVoice(BuildContext context) async {
    try {
      final messages = await VoiceMessageService.instance.fetchForDose(dose.patientId, dose.id);
      if (!context.mounted) return;
      if (messages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد تسجيل صوتي مرتبط بهذه الجرعة.')));
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => _DoseVoiceSheet(messages: messages),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر تحميل التسجيل الصوتي لهذه الجرعة.')));
    }
  }

  String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _DoseVoiceSheet extends StatefulWidget {
  const _DoseVoiceSheet({required this.messages});
  final List<VoiceMessage> messages;
  @override
  State<_DoseVoiceSheet> createState() => _DoseVoiceSheetState();
}

class _DoseVoiceSheetState extends State<_DoseVoiceSheet> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingId;
  @override
  void dispose() { _player.dispose(); super.dispose(); }

  Future<void> _toggle(VoiceMessage message) async {
    try {
      if (_playingId == message.id) {
        await _player.pause();
        if (mounted) setState(() => _playingId = null);
        return;
      }
      final url = await VoiceMessageService.instance.signedUrl(message.storagePath);
      await _player.play(UrlSource(url));
      await VoiceMessageService.instance.markRead(message.id);
      if (mounted) setState(() => _playingId = message.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر تشغيل التسجيل الصوتي.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('التسجيل الصوتي للجرعة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...widget.messages.map((message) {
              final playing = _playingId == message.id;
              return Card(child: ListTile(
                leading: CircleAvatar(child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded)),
                title: Text(message.senderName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${_duration(message.durationMs)} • استماع ${message.completedListens}/2'),
                onTap: () => _toggle(message),
              ));
            }),
          ],
        ),
      ),
    );
  }

  String _duration(int? ms) {
    if (ms == null) return '00:00';
    final seconds = (ms / 1000).round();
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
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
          child: Image.network(url, width: size, height: size, fit: BoxFit.cover, cacheWidth: compact ? 162 : 192, cacheHeight: compact ? 162 : 192, errorBuilder: (_, __, ___) => _placeholder(context, size)),
        );
      },
    );
  }
  Widget _placeholder(BuildContext context, double size) => Container(width: size, height: size, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.medication_rounded));
}

class _StatusChip extends StatelessWidget {
  final DoseStatus status;
  final String label;
  const _StatusChip({required this.status, required this.label});
  @override
  Widget build(BuildContext context) => Chip(avatar: Icon(_icon, size: 16), label: Text(label), visualDensity: VisualDensity.compact);
  IconData get _icon {
    switch (status) {
      case DoseStatus.taken: return Icons.check_circle_rounded;
      case DoseStatus.missed: return Icons.warning_rounded;
      case DoseStatus.snoozed: return Icons.schedule_rounded;
      case DoseStatus.skipped: return Icons.remove_circle_outline_rounded;
      case DoseStatus.cancelled: return Icons.cancel_outlined;
      case DoseStatus.reminderSent: return Icons.notifications_active_rounded;
      case DoseStatus.pending: return Icons.access_time_rounded;
    }
  }
}
