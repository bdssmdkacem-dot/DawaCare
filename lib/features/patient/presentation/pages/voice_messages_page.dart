import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/voice/voice_message_service.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/voice_message.dart';

class VoiceMessagesPage extends StatefulWidget {
  const VoiceMessagesPage({super.key, this.initialMessageId});

  final String? initialMessageId;

  @override
  State<VoiceMessagesPage> createState() => _VoiceMessagesPageState();
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
      _channel = Supabase.instance.client
          .channel('voice-messages-$userId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'voice_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'patient_id',
            value: userId,
          ),
          callback: (_) => _load(),
        )
        ..subscribe();
    }
    _completeSubscription =
        _player.onPlayerComplete.listen((_) => _onPlaybackComplete());
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
      setState(() {
        _messages = messages;
        _loading = false;
      });
      if (widget.initialMessageId != null && _contextMessageId == null) {
        await _selectMessage(widget.initialMessageId!);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectMessage(String id) async {
    final message = _messages
        .where((m) => m.id == id)
        .cast<VoiceMessage?>()
        .firstWhere((m) => m != null, orElse: () => null);

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
      if (mounted) {
        setState(() {
          _contextMedicationName = medication?['name'] as String?;
          _contextStrength = medication?['strength'] as String?;
          _contextDoseAmount = dose?['dose_amount']?.toString();
          _contextScheduledAt = dose?['scheduled_at'] == null
              ? null
              : DateTime.parse(dose!['scheduled_at'] as String)
                  .toLocal()
                  .toString();
          _contextImageUrl = medication?['image_url'] as String?;
        });
      }
    } else if (mounted) {
      setState(() {
        _contextMedicationName = null;
        _contextStrength = null;
        _contextDoseAmount = null;
        _contextScheduledAt = null;
        _contextImageUrl = null;
      });
    }
  }

  Future<void> _play(VoiceMessage message) async {
    try {
      if (_playingId == message.id) {
        await _player.pause();
        if (mounted) {
          setState(() => _playingId = null);
        }
        return;
      }
      await _selectMessage(message.id);
      final url = await _service.signedUrl(message.storagePath);
      await _player.play(UrlSource(url));
      await _service.markRead(message.id);
      if (mounted) {
        setState(() => _playingId = message.id);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).voicePlaybackError),
          ),
        );
      }
    }
  }

  Future<void> _onPlaybackComplete() async {
    final id = _playingId;
    if (id == null) return;
    if (mounted) {
      setState(() => _playingId = null);
    }
    try {
      final result = await _service.completeListen(id);
      if (!mounted) return;
      if (result.deleted) {
        await _service.deleteStorageFile(result.storagePath);
        if (!mounted) return;
        setState(() {
          _messages.removeWhere((m) => m.id == id);
          if (_contextMessageId == id) {
            _contextMessageId = null;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).voiceDeletedAfterTwoListens,
            ),
          ),
        );
      } else {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == id);
          if (index >= 0) {
            final old = _messages[index];
            _messages[index] = VoiceMessage(
              id: old.id,
              senderId: old.senderId,
              patientId: old.patientId,
              doseId: old.doseId,
              storagePath: old.storagePath,
              durationMs: old.durationMs,
              createdAt: old.createdAt,
              readAt: old.readAt,
              completedListens: result.completedListens,
              senderName: old.senderName,
            );
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).voiceListenUpdateError),
          ),
        );
      }
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
    final selected = _contextMessageId == null
        ? null
        : _messages
            .where((m) => m.id == _contextMessageId)
            .cast<VoiceMessage?>()
            .firstWhere((m) => m != null, orElse: () => null);

    return Scaffold(
      appBar: AppBar(title: Text(l.followUpMessages)),
      body: _loading
          ? const LoadingIndicator()
          : Column(
              children: [
                if (selected != null) _buildContextCard(selected, l),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _messages.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 180),
                              Center(child: Text(l.voiceMessagesEmpty)),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) {
                              final m = _messages[i];
                              final unread = m.readAt == null;
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Icon(
                                      _playingId == m.id
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                    ),
                                  ),
                                  title: Text(
                                    m.senderName,
                                    style: TextStyle(
                                      fontWeight: unread
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}  ${_duration(m.durationMs)}  •  ${l.listenLabel(m.completedListens)}',
                                  ),
                                  trailing: unread
                                      ? const Icon(Icons.circle, size: 10)
                                      : null,
                                  onTap: () => _play(m),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildContextCard(VoiceMessage message, AppLocalizations l) {
    final scheduled = _contextScheduledAt;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_contextImageUrl != null && _contextImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _contextImageUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              )
            else
              const CircleAvatar(
                radius: 32,
                child: Icon(Icons.medication_rounded),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _contextMedicationName ?? l.linkedDoseMessage,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  if (_contextStrength?.isNotEmpty == true)
                    Text(_contextStrength!),
                  if (_contextDoseAmount?.isNotEmpty == true)
                    Text(l.doseLabel(_contextDoseAmount!)),
                  if (scheduled != null)
                    Text(
                      l.doseTimeLabel(
                        '${DateTime.parse(scheduled).hour.toString().padLeft(2, '0')}:${DateTime.parse(scheduled).minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  Text(l.listenLabel(message.completedListens)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
