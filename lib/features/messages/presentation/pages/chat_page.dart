import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/message_service.dart';

class ChatPage extends StatefulWidget {
  final String patientId;
  final String otherUserId;
  final String otherName;
  const ChatPage({super.key, required this.patientId, required this.otherUserId, required this.otherName});
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
  bool _loading = true, _sending = false, _refreshing = false;
  int _loadGeneration = 0;
  String? _playing;
  RealtimeChannel? _channel;
  StreamSubscription<void>? _playerComplete;

  @override
  void initState() {
    super.initState();
    _load(scrollToBottom: true);
    _channel = _db.channel('chat-${widget.patientId}-${widget.otherUserId}')
      ..onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'messages', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'patient_id', value: widget.patientId), callback: (_) => _load(scrollToBottom: true))
      ..onPostgresChanges(event: PostgresChangeEvent.update, schema: 'public', table: 'messages', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'patient_id', value: widget.patientId), callback: (_) => _load())
      ..subscribe();
  }

  @override
  void dispose() {
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
      final filtered = rows.where((m) => (m.senderId == widget.otherUserId && m.recipientId == me) || (m.senderId == me && m.recipientId == widget.otherUserId)).toList();
      setState(() => _messages = filtered);
      for (final m in filtered.where((m) => m.recipientId == me && m.readAt == null)) {
        try {
          await _service.markRead(m.id);
        } catch (e) {
          debugPrint('chat mark-read: $e');
        }
      }
    } catch (e) {
      debugPrint('chat load: $e');
      if (mounted && _messages.isEmpty) {
        _error(AppLocalizations.of(context).tr('تعذر تحميل المحادثة.', 'Could not load conversation.', 'Impossible de charger la conversation.'));
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
    await _load();
  }

  void _bottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    }
  }

  Future<void> _sendText() async {
    final v = _text.text.trim();
    if (v.isEmpty || _sending) return;
    await _run(() => _service.sendText(patientId: widget.patientId, recipientId: widget.otherUserId, text: v), clearText: true);
  }

  Future<void> _sendImage() async {
    if (_sending) return;
    final image = await _service.pickImage();
    if (image == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).tr('تأكيد إرسال الصورة', 'Confirm image send', 'Confirmer l’envoi de l’image')),
        content: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(image.path), height: 280, fit: BoxFit.contain)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context).cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppLocalizations.of(context).tr('إرسال', 'Send', 'Envoyer'))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(() => _service.sendImage(patientId: widget.patientId, recipientId: widget.otherUserId, image: image));
    }
  }

  Future<void> _run(Future<ChatMessage> Function() action, {bool clearText = false}) async {
    final l = AppLocalizations.of(context);
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      final m = await action();
      if (mounted) {
        setState(() => _messages = [..._messages, m]);
        if (clearText) {
          _text.clear();
        }
        _signedUrls.remove(m.storagePath);
        WidgetsBinding.instance.addPostFrameCallback((_) => _bottom());
      }
    } catch (e, stack) {
      debugPrint('chat send error: $e');
      debugPrintStack(stackTrace: stack);
      if (e is ChatSendException) {
        _error(e.diagnostic);
      } else if (e is StateError) {
        _error(l.tr('خطأ في الإرسال: ${e.message}', 'Send error: ${e.message}', 'Erreur d’envoi : ${e.message}'));
      } else {
        _error(l.tr('خطأ في الإرسال: $e', 'Send error: $e', 'Erreur d’envoi : $e'));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _error(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 8)));
    }
  }

  Future<String> _urlFor(String path) => _signedUrls.putIfAbsent(path, () => _service.signedUrl(path));

  Future<void> _play(ChatMessage m) async {
    final l = AppLocalizations.of(context);
    try {
      if (_playing == m.id) {
        await _player.stop();
        if (mounted) {
          setState(() => _playing = null);
        }
        return;
      }
      await _playerComplete?.cancel();
      final url = await _urlFor(m.storagePath!);
      await _player.play(UrlSource(url));
      if (mounted) {
        setState(() => _playing = m.id);
      }
      if (m.readAt == null && m.recipientId == _db.auth.currentUser?.id) {
        try {
          await _service.markRead(m.id);
        } catch (_) {}
      }
      _playerComplete = _player.onPlayerComplete.listen((_) {
        if (mounted && _playing == m.id) {
          setState(() => _playing = null);
        }
      });
    } catch (e) {
      _error(l.tr('تعذر تشغيل الرسالة الصوتية: $e', 'Could not play voice message: $e', 'Impossible de lire le message vocal : $e'));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.otherName)),
    body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), children: _messages.isEmpty ? [SizedBox(height: 300, child: Center(child: Text(AppLocalizations.of(context).tr('لا توجد رسائل بعد.', 'No messages yet.', 'Aucun message pour le moment.'))))] : _messages.map(_bubble).toList()),
    ),
    bottomNavigationBar: _composer(),
  );

  String _dayKey(DateTime value) => '${value.year}-${value.month}-${value.day}';

  String _dateLabel(DateTime value, AppLocalizations l) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return l.tr('اليوم', 'Today', 'Aujourd’hui');
    if (difference == 1) return l.tr('أمس', 'Yesterday', 'Hier');
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.runes.take(2).map(String.fromCharCode).join().toUpperCase();
    return '${String.fromCharCode(parts.first.runes.first)}${String.fromCharCode(parts.last.runes.first)}'.toUpperCase();
  }

  Widget _bubble(ChatMessage m) {
    final l = AppLocalizations.of(context);
    final mine = m.senderId == _db.auth.currentUser?.id;
    final read = m.readAt != null;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: EdgeInsets.only(bottom: 8, left: mine ? 42 : 0, right: mine ? 0 : 42),
        padding: const EdgeInsets.fromLTRB(13, 11, 11, 8),
        decoration: BoxDecoration(
          color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 5), bottomRight: Radius.circular(mine ? 5 : 18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m.type == 'text') Text(m.body!),
          if (m.type == 'image') FutureBuilder<String>(
            future: _urlFor(m.storagePath!),
            builder: (c, s) => s.hasData ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(s.data!, width: 250, height: 250, fit: BoxFit.cover)) : SizedBox(width: 250, height: 100, child: Center(child: s.hasError ? const Icon(Icons.broken_image_outlined) : const CircularProgressIndicator())),
          ),
          if (m.type == 'voice') Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(onPressed: () => _play(m), icon: Icon(_playing == m.id ? Icons.stop_circle_outlined : Icons.play_circle_fill_rounded, size: 38)),
            if (m.durationMs != null) Text('${(m.durationMs! / 1000).ceil()} ${l.tr('ث', 's', 's')}'),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_time(m.createdAt), style: Theme.of(context).textTheme.labelSmall),
            if (mine) ...[
              const SizedBox(width: 5),
              Icon(read ? Icons.done_all_rounded : Icons.done_rounded, size: 16, color: read ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 3),
              Text(read ? l.tr('مقروءة', 'Read', 'Lu') : l.tr('مرسلة', 'Sent', 'Envoyée'), style: Theme.of(context).textTheme.labelSmall),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _composer() => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 8), child: Row(children: [
    IconButton(onPressed: _sending ? null : _sendImage, icon: const Icon(Icons.image_rounded), tooltip: AppLocalizations.of(context).tr('صورة', 'Image', 'Image')),
    Expanded(child: TextField(controller: _text, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendText(), decoration: InputDecoration(hintText: AppLocalizations.of(context).tr('اكتب رسالة...', 'Write a message...', 'Écrire un message...'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)))),
    const SizedBox(width: 5),
    IconButton(onPressed: _sending ? null : _sendText, icon: const Icon(Icons.send_rounded), tooltip: AppLocalizations.of(context).tr('إرسال', 'Send', 'Envoyer')),
  ])));
  Widget _composer() => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 8), child: Row(children: [
    IconButton(onPressed: _sending || _recording ? null : _sendImage, icon: const Icon(Icons.image_rounded)),
    IconButton(onPressed: _sending ? null : _toggleRecording, icon: Icon(_recording ? Icons.stop_circle_rounded : Icons.mic_rounded)),
    Expanded(child: TextField(controller: _text, enabled: !_recording, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendText(), decoration: InputDecoration(hintText: AppLocalizations.of(context).tr('اكتب رسالة...', 'Write a message...', 'Écrire un message...'), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)))),
    const SizedBox(width: 5), IconButton(onPressed: _sending || _recording ? null : _sendText, icon: const Icon(Icons.send_rounded)),
  ])));
}
