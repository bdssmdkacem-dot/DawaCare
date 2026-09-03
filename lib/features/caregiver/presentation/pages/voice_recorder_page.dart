import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/voice/voice_message_service.dart';

class VoiceRecorderPage extends StatefulWidget {
  const VoiceRecorderPage({super.key, required this.patientId, required this.patientName, this.doseId, this.medicationName, this.doseAmount, this.scheduledAt});
  final String patientId; final String patientName; final String? doseId; final String? medicationName; final String? doseAmount; final DateTime? scheduledAt;
  @override State<VoiceRecorderPage> createState() => _VoiceRecorderPageState();
}

class _VoiceRecorderPageState extends State<VoiceRecorderPage> {
  final _voice = VoiceMessageService.instance; final _player = AudioPlayer();
  Timer? _timer; Stopwatch? _stopwatch; String? _recordedPath; Duration _duration = Duration.zero;
  bool _recording = false; bool _sending = false; bool _playing = false;

  @override void dispose() { _timer?.cancel(); _player.dispose(); super.dispose(); }

  Future<void> _start() async { try { await _voice.startRecording(); if (!mounted) return; setState(() { _recording = true; _recordedPath = null; _duration = Duration.zero; }); _stopwatch = Stopwatch()..start(); _timer?.cancel(); _timer = Timer.periodic(const Duration(milliseconds: 250), (_) async { final elapsed = _stopwatch?.elapsed ?? Duration.zero; if (!mounted) return; setState(() => _duration = elapsed); if (elapsed >= VoiceMessageService.maxDuration) await _stop(); }); } catch (e) { if (mounted) _showError(e.toString()); } }
  Future<void> _stop() async { if (!_recording) return; _timer?.cancel(); _stopwatch?.stop(); final path = await _voice.stopRecording(); if (!mounted) return; setState(() { _recording = false; _recordedPath = path; }); }
  Future<void> _discard() async { _timer?.cancel(); _stopwatch?.stop(); if (_recording) await _voice.cancelRecording(); if (!mounted) return; setState(() { _recording = false; _recordedPath = null; _duration = Duration.zero; }); }
  Future<void> _preview() async { final path = _recordedPath; if (path == null) return; try { if (_playing) { await _player.stop(); } else { await _player.play(DeviceFileSource(path)); } if (mounted) setState(() => _playing = !_playing); } catch (e) { if (mounted) _showError(AppLocalizations.of(context).recordingError); } }
  Future<void> _send() async { final path = _recordedPath; if (path == null || _duration == Duration.zero) return; setState(() => _sending = true); try { await _voice.sendRecording(patientId: widget.patientId, doseId: widget.doseId, localPath: path, durationMs: _duration.inMilliseconds); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✓ ${AppLocalizations.of(context).sendTo(widget.patientName)}'))); Navigator.of(context).pop(true); } catch (e) { if (mounted) _showError(e.toString()); } finally { if (mounted) setState(() => _sending = false); } }
  void _showError(String message) { final clean = message.replaceFirst('VoiceMessageException: ', ''); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(clean))); }
  String _format(Duration d) { final s = d.inSeconds; return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}'; }
  String _time(DateTime v) => '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';

  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); final contextual = widget.doseId != null;
    return Scaffold(appBar: AppBar(title: Text(l.voiceRecorderTitle)), body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 28), child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: Row(children: [
        Container(width: 58, height: 58, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(18)), child: Icon(contextual ? Icons.medication_liquid_rounded : Icons.record_voice_over_rounded, color: Colors.white, size: 32)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(contextual && widget.medicationName != null ? l.voiceAbout(widget.medicationName!) : l.sendTo(widget.patientName), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(contextual ? l.linkedToDose : l.generalVoiceHint, style: TextStyle(color: Colors.white.withValues(alpha: .88)))]))
      ])),
      if (contextual && widget.doseAmount != null && widget.scheduledAt != null) Card(margin: const EdgeInsets.only(top: 12), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [const Icon(Icons.schedule_rounded, color: AppColors.primary), const SizedBox(width: 10), Text('${widget.doseAmount}  •  ${_time(widget.scheduledAt!)}', style: const TextStyle(fontWeight: FontWeight.w700))]))),
      const SizedBox(height: 34),
      Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: _recording ? AppColors.danger.withValues(alpha: .12) : AppColors.primary.withValues(alpha: .09), border: Border.all(color: _recording ? AppColors.danger.withValues(alpha: .45) : AppColors.primary.withValues(alpha: .22), width: 2)), child: Center(child: Text(_format(_duration), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: _recording ? AppColors.danger : AppColors.primary)))),
      const SizedBox(height: 22),
      if (_recording) Text(l.voiceRecorderTitle, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
      const SizedBox(height: 14),
      if (_recordedPath != null && !_recording) Row(mainAxisAlignment: MainAxisAlignment.center, children: [IconButton.filledTonal(onPressed: _preview, icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded), tooltip: l.preview), const SizedBox(width: 12), IconButton(onPressed: _discard, icon: const Icon(Icons.delete_outline_rounded), tooltip: l.delete)]) else IconButton.filled(onPressed: _recording ? _stop : _start, iconSize: 42, icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded)),
      const SizedBox(height: 24),
      if (_recordedPath != null && !_recording) SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded), label: Text(_sending ? l.sending : l.sendVoice))),
    ]))));
  }
}
