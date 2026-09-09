import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/message_service.dart';

class ChatPage extends StatefulWidget {
  final String patientId;
  final String otherUserId;
  final String otherName;

  const ChatPage({
    super.key,
    required this.patientId,
    required this.otherUserId,
    required this.otherName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _service = MessageService.instance;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _player = AudioPlayer();
  final _db = Supabase.instance.client;

  List<ChatMessage> _messages = [];
  final Map<String, Future<String>> _signedUrls = {};
  bool _loading = true;
  bool _sending = false;
  bool _recording = false;
  bool _refreshing = false;
  int _loadGeneration = 0;
  DateTime? _recordStarted;
  String? _playing;
  RealtimeChannel? _channel;
  StreamSubscription<void>? _playerComplete;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _db.channel('chat-${widget.patientId}-${widget.otherUserId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'patient_id',
          value: widget.patientId,
        ),
        callback: (_) => _load(scrollToBottom: true),
      )
      ..subscribe();
  }

  @override
  void dispose() {
    if (_recording) {
      unawaited(_service.cancelVoiceRecording());
    }
    _playerComplete?.cancel();
    _channel?.unsubscribe();
    _text.dispose();
    _scroll.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load({bool scrollToBottom = false}) async {
    final me = _db.auth.currentUser?.id;
    if (me == null) {
      if (mounted) {
        setState(() {
          _messages = [];
          _loading = false;
          _refreshing = false;
        });
      }
      return;
    }

    final generation = ++_loadGeneration;
    try {
      final rows = await _service.fetch(widget.patientId);
      if (!mounted || generation != _loadGeneration) return;

      final filtered = rows
          .where(
            (m) =>
                (m.senderId == widget.otherUserId && m.recipientId == me) ||
                (m.senderId == me && m.recipientId == widget.otherUserId),
          )
          .toList();

      setState(() => _messages = filtered);

      final unread = filtered.where(
        (m) => m.recipientId == me && m.readAt == null,
      );
      for (final m in unread) {
        try {
          await _service.markRead(m.id);
        } catch (e) {
          debugPrint('chat mark-read: $e');
        }
      }

      if (scrollToBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _bottom());
      }
    } catch (e) {
      debugPrint('chat load: $e');
      if (mounted && _messages.isEmpty) {
        _error('تعذر تحميل المحادثة.');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
      if (scrollToBottom && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _bottom());
      }
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _load(scrollToBottom: false);
  }

  void _bottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendText() async {
    final v = _text.text.trim();
    if (v.isEmpty || _sending) return;
    await _run(
      () => _service.sendText(
        patientId: widget.patientId,
        recipientId: widget.otherUserId,
        text: v,
      ),
      clearText: true,
    );
  }

  Future<void> _sendImage() async {
    final image = await _service.pickImage();
    if (image == null || _sending) return;
    await _run(
      () => _service.sendImage(
        patientId: widget.patientId,
        recipientId: widget.otherUserId,
        image: image,
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_sending) return;
    if (_recording) {
      final path = await _service.stopVoiceRecording();
      final started = _recordStarted;
      if (mounted) {
        setState(() {
          _recording = false;
          _recordStarted = null;
        });
      }
      if (path != null && started != null) {
        final ms = DateTime.now().difference(started).inMilliseconds;
        if (ms > 0) {
          await _run(
            () => _service.sendVoice(
              patientId: widget.patientId,
              recipientId: widget.otherUserId,
              localPath: path,
              durationMs: ms,
            ),
          );
        }
      }
    } else {
      try {
        await _service.startVoiceRecording();
        if (mounted) {
          setState(() {
            _recordStarted = DateTime.now();
            _recording = true;
          });
        }
      } catch (_) {
        _error('تعذر بدء التسجيل.');
      }
    }
  }

  Future<void> _run(
    Future<ChatMessage> Function() action, {
    bool clearText = false,
  }) async {
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      final m = await action();
      if (mounted) {
        setState(() => _messages = [..._messages, m]);
        if (clearText) _text.clear();
        _signedUrls.remove(m.storagePath);
        WidgetsBinding.instance.addPostFrameCallback((_) => _bottom());
      }
    } catch (e) {
      debugPrint('chat send: $e');
      _error('تعذر إرسال الرسالة.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _error(String t) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
    }
  }

  Future<String> _urlFor(String path) {
    return _signedUrls.putIfAbsent(path, () => _service.signedUrl(path));
  }

  Future<void> _play(ChatMessage m) async {
    try {
      if (_playing == m.id) {
        await _player.stop();
        if (mounted) setState(() => _playing = null);
        return;
      }
      await _playerComplete?.cancel();
      final url = await _urlFor(m.storagePath!);
      await _player.play(UrlSource(url));
      if (mounted) setState(() => _playing = m.id);
      if (m.readAt == null && m.recipientId == _db.auth.currentUser?.id) {
        try {
          await _service.markRead(m.id);
        } catch (e) {
          debugPrint('chat voice mark-read: $e');
        }
      }
      _playerComplete = _player.onPlayerComplete.listen((_) {
        if (mounted && _playing == m.id) setState(() => _playing = null);
      });
    } catch (_) {
      _error('تعذر تشغيل الرسالة الصوتية.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                children: [
                  if (_messages.isEmpty)
                    const SizedBox(
                      height: 300,
                      child: Center(child: Text('لا توجد رسائل بعد.')),
                    )
                  else
                    ..._messages.map(_bubble),
                ],
              ),
            ),
      bottomNavigationBar: _composer(),
    );
  }

  Widget _bubble(ChatMessage m) {
    final mine = m.senderId == _db.auth.currentUser?.id;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: mine
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.type == 'text') Text(m.body!),
            if (m.type == 'image')
              FutureBuilder<String>(
                future: _urlFor(m.storagePath!),
                builder: (c, s) {
                  if (s.hasError) {
                    return const SizedBox(
                      width: 250,
                      height: 100,
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    );
                  }
                  return s.hasData
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            s.data!,
                            width: 250,
                            height: 250,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 250,
                              height: 100,
                              child: Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(
                          width: 250,
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        );
                },
              ),
            if (m.type == 'voice')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _play(m),
                    icon: Icon(
                      _playing == m.id
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_fill_rounded,
                      size: 38,
                    ),
                  ),
                  if (m.durationMs != null)
                    Text('${(m.durationMs! / 1000).ceil()} ث'),
                ],
              ),
            Text(
              '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: _sending || _recording ? null : _sendImage,
              icon: const Icon(Icons.image_rounded),
            ),
            IconButton(
              onPressed: _sending ? null : _toggleRecording,
              icon: Icon(
                _recording
                    ? Icons.stop_circle_rounded
                    : Icons.mic_rounded,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _text,
                enabled: !_recording,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالة...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            IconButton(
              onPressed: _sending || _recording ? null : _sendText,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
