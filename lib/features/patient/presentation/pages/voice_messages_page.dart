import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/voice/voice_message_service.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/voice_message.dart';

class VoiceMessagesPage extends StatefulWidget {
  const VoiceMessagesPage({super.key, this.initialMessageId});
  final String? initialMessageId;
  @override State<VoiceMessagesPage> createState() => _VoiceMessagesPageState();
}

class _VoiceMessagesPageState extends State<VoiceMessagesPage> {
  final _service = VoiceMessageService.instance;
  final _player = AudioPlayer();
  List<VoiceMessage> _messages = [];
  bool _loading = true;
  String? _playingId;
  String? _contextMessageId;
  String? _contextMedicationName;
  String? _contextStrength;
  String? _contextDoseAmount;
  String? _contextScheduledAt;
  String? _contextImageUrl;
  RealtimeChannel? _channel;
  StreamSubscription<void>? _completeSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _channel = Supabase.instance.client.channel('voice-messages-$userId')
        ..onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'voice_messages', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'patient_id', value: userId), callback: (_) => _load())
        ..subscribe();
    }
    _completeSubscription = _player.onPlayerComplete.listen((_) => _onPlaybackComplete());
  }

  @override
  void dispose() {
    _completeSubscription?.cancel();
    _channel?.unsubscribe();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final messages = await _service.fetchForPatient(userId);
      if (!mounted) return;
      setState(() { _messages = messages; _loading = false; });
      if (widget.initialMessageId != null && _contextMessageId == null) await _selectMessage(widget.initialMessageId!);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectMessage(String id) async {
    final message = _messages.where((m) => m.id == id).cast<VoiceMessage?>().firstWhere((m) => m != null, orElse: () => null);
    if (message == null) {
      final fetched = await _service.fetchById(id);
      if (fetched == null || !mounted) return;
      if (!_messages.any((m) => m.id == fetched.id)) {
        setState(() => _messages = [fetched, ..._messages]);
      }
      await _selectMessage(fetched.id);
      return;
    }
    _contextMessageId = message.id;
    if (message.doseId != null) {
      final context = await _service.fetchDoseContext(message.doseId!);
      final medication = context?['medication'] as Map<String, dynamic>?;
      final dose = context?['dose'] as Map<String, dynamic>?;
      if (mounted) setState(() {
        _contextMedicationName = medication?['name'] as String?;
        _contextStrength = medication?['strength'] as String?;
        _contextDoseAmount = dose?['dose_amount']?.toString();
        _contextScheduledAt = dose?['scheduled_at'] == null ? null : DateTime.parse(dose!['scheduled_at'] as String).toLocal().toString();
        _contextImageUrl = medication?['image_url'] as String?;
      });
    } else if (mounted) {
      setState(() { _contextMedicationName = null; _contextStrength = null; _contextDoseAmount = null; _contextScheduledAt = null; _contextImageUrl = null; });
    }
  }

  Future<void> _play(VoiceMessage message) async {
    try {
      if (_playingId == message.id) { await _player.pause(); if (mounted) setState(() => _playingId = null); return; }
      await _selectMessage(message.id);
      final url = await _service.signedUrl(message.storagePath);
      await _player.play(UrlSource(url));
      await _service.markRead(message.id);
      if (mounted) setState(() => _playingId = message.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).voicePlaybackError)));
    }
  }

  Future<void> _onPlaybackComplete() async {
    final id = _playingId;
    if (id == null) return;
    if (mounted) setState(() => _playingId = null);
    try {
      final result = await _service.completeListen(id);
      if (!mounted) return;
      if (result.deleted) {
        await _service.deleteStorageFile(result.storagePath);
        if (!mounted) return;
        setState(() { _messages.removeWhere((m) => m.id == id); if (_contextMessageId == id) _contextMessageId = null; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).voiceDeletedAfterTwoListens)));
      } else {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == id);
          if (index >= 0) {
            final old = _messages[index];
            _messages[index] = VoiceMessage(id: old.id, senderId: old.senderId, patientId: old.patientId, doseId: old.doseId, storagePath: old.storagePath, durationMs: old.durationMs, createdAt: old.createdAt, readAt: old.readAt, completedListens: result.completedListens, senderName: old.senderName);
          }
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).voiceListenUpdateError)));
    }
  }

  String _duration(int? ms) {
    if (ms == null) return '';
    final s = (ms / 1000).round();
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selected = _contextMessageId == null ? null : _messages.where((m) => m.id == _contextMessageId).cast<VoiceMessage?>().firstWhere((m) => m != null, orElse: () => null);
    return Scaffold(
      appBar: AppBar(title: Text(l.followUpMessages)),
      body: _loading ? const LoadingIndicator() : Column(children: [
        if (selected != null) _buildContextCard(selected, l),
        Expanded(child: RefreshIndicator(onRefresh: _load, child: _messages.isEmpty ? ListView(children: [const SizedBox(height: 110), _EmptyVoiceState(label: l.voiceMessagesEmpty)] ) : ListView.separated(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), itemCount: _messages.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, i) => _buildMessageTile(_messages[i], l)))),
      ]),
    );
  }

  Widget _buildMessageTile(VoiceMessage message, AppLocalizations l) {
    final unread = message.readAt == null;
    final playing = _playingId == message.id;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _play(message),
        child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(color: playing ? AppColors.accent.withValues(alpha: .18) : AppColors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(16)), child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: playing ? AppColors.accentDark : AppColors.primary, size: 30)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(message.senderName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600, fontSize: 16))), if (unread) Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))]),
            const SizedBox(height: 5),
            Text('${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}  •  ${_duration(message.durationMs)}  •  ${l.listenLabel(message.completedListens)}', style: Theme.of(context).textTheme.bodySmall),
          ])),
        ])),
      ),
    );
  }

  Widget _buildContextCard(VoiceMessage message, AppLocalizations l) {
    final scheduled = _contextScheduledAt;
    return Card(margin: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: .12), AppColors.primaryLight.withValues(alpha: .05)], begin: Alignment.topLeft, end: Alignment.bottomRight)), padding: const EdgeInsets.all(16), child: Row(children: [
      if (_contextImageUrl != null && _contextImageUrl!.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(_contextImageUrl!, width: 68, height: 68, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _medIcon())) else _medIcon(),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_contextMedicationName ?? l.linkedDoseMessage, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        if (_contextStrength?.isNotEmpty == true) Text(_contextStrength!, style: Theme.of(context).textTheme.bodySmall),
        if (_contextDoseAmount?.isNotEmpty == true) Text(l.doseLabel(_contextDoseAmount!)),
        if (scheduled != null) Text(l.doseTimeLabel(_formatContextTime(scheduled))),
        const SizedBox(height: 3), Text(l.listenLabel(message.completedListens), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
      ])),
    ])));
  }

  Widget _medIcon() => Container(width: 68, height: 68, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 32));
  String _formatContextTime(String value) { final date = DateTime.parse(value); return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'; }
}

class _EmptyVoiceState extends StatelessWidget {
  const _EmptyVoiceState({required this.label});
  final String label;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .09), shape: BoxShape.circle), child: const Icon(Icons.mic_none_rounded, color: AppColors.primary, size: 36)), const SizedBox(height: 16), Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))]))));
}
