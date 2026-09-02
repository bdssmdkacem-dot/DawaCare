import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/voice/voice_message_service.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/voice_message.dart';

class VoiceMessagesPage extends StatefulWidget {
  const VoiceMessagesPage({super.key});

  @override
  State<VoiceMessagesPage> createState() => _VoiceMessagesPageState();
}

class _VoiceMessagesPageState extends State<VoiceMessagesPage> {
  final _service = VoiceMessageService.instance;
  final _player = AudioPlayer();
  List<VoiceMessage> _messages = [];
  bool _loading = true;
  String? _playingId;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _channel = Supabase.instance.client
          .channel('voice-messages-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'voice_messages',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'patient_id', value: userId),
            callback: (_) => _load(),
          )
          .subscribe();
    }
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final messages = await _service.fetchForPatient(userId);
      if (mounted) setState(() { _messages = messages; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _play(VoiceMessage message) async {
    try {
      if (_playingId == message.id) {
        await _player.stop();
        if (mounted) setState(() => _playingId = null);
        return;
      }
      final url = await _service.signedUrl(message.storagePath);
      await _player.play(UrlSource(url));
      await _service.markRead(message.id);
      if (mounted) setState(() => _playingId = message.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر تشغيل الرسالة الصوتية.')));
    }
  }

  String _duration(int? ms) {
    if (ms == null) return '';
    final s = (ms / 1000).round();
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رسائل المتابعة')),
      body: _loading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _load,
              child: _messages.isEmpty
                  ? ListView(children: const [SizedBox(height: 180), Center(child: Text('لا توجد رسائل صوتية بعد'))])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final unread = m.readAt == null;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Icon(_playingId == m.id ? Icons.stop_rounded : Icons.play_arrow_rounded)),
                            title: Text(m.senderName, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w500)),
                            subtitle: Text('${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}  ${_duration(m.durationMs)}'),
                            trailing: unread ? const Icon(Icons.circle, size: 10) : null,
                            onTap: () => _play(m),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
