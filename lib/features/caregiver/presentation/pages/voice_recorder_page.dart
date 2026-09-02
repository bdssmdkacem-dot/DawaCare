import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../../core/voice/voice_message_service.dart';

class VoiceRecorderPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const VoiceRecorderPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<VoiceRecorderPage> createState() => _VoiceRecorderPageState();
}

class _VoiceRecorderPageState extends State<VoiceRecorderPage> {
  final _voice = VoiceMessageService.instance;
  final _player = AudioPlayer();
  Timer? _timer;
  Stopwatch? _stopwatch;
  String? _recordedPath;
  Duration _duration = Duration.zero;
  bool _recording = false;
  bool _sending = false;
  bool _playing = false;

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await _voice.startRecording();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordedPath = null;
        _duration = Duration.zero;
      });
      _stopwatch = Stopwatch()..start();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
        final elapsed = _stopwatch?.elapsed ?? Duration.zero;
        if (!mounted) return;
        setState(() => _duration = elapsed);
        if (elapsed >= VoiceMessageService.maxDuration) await _stop();
      });
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _timer?.cancel();
    _stopwatch?.stop();
    final path = await _voice.stopRecording();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordedPath = path;
    });
  }

  Future<void> _discard() async {
    _timer?.cancel();
    _stopwatch?.stop();
    if (_recording) await _voice.cancelRecording();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordedPath = null;
      _duration = Duration.zero;
    });
  }

  Future<void> _preview() async {
    final path = _recordedPath;
    if (path == null) return;
    try {
      if (_playing) {
        await _player.stop();
      } else {
        await _player.play(DeviceFileSource(path));
      }
      if (mounted) setState(() => _playing = !_playing);
    } catch (e) {
      if (mounted) _showError('تعذّر تشغيل التسجيل.');
    }
  }

  Future<void> _send() async {
    final path = _recordedPath;
    if (path == null || _duration == Duration.zero) return;
    setState(() => _sending = true);
    try {
      await _voice.sendRecording(
        patientId: widget.patientId,
        localPath: path,
        durationMs: _duration.inMilliseconds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إرسال الرسالة إلى ${widget.patientName}')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String message) {
    final clean = message.replaceFirst('VoiceMessageException: ', '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(clean)));
  }

  String _format(Duration d) {
    final seconds = d.inSeconds;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رسالة صوتية')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.record_voice_over_rounded, size: 72),
            const SizedBox(height: 16),
            Text('إرسال رسالة إلى ${widget.patientName}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('يمكنك تسجيل رسالة تصل إلى دقيقة واحدة.'),
            const Spacer(),
            Text(_format(_duration), style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 24),
            if (_recordedPath != null && !_recording)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: _preview,
                    icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    tooltip: 'معاينة',
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _discard,
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'حذف',
                  ),
                ],
              )
            else
              IconButton.filled(
                onPressed: _recording ? _stop : _start,
                iconSize: 42,
                icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
              ),
            const SizedBox(height: 28),
            if (_recordedPath != null && !_recording)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال الرسالة'),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
