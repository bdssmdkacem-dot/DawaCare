import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/voice_message.dart';

class VoiceMessageService {
  VoiceMessageService._();
  static final instance = VoiceMessageService._();

  static const bucket = 'voice-messages';
  static const maxDuration = Duration(seconds: 60);

  final AudioRecorder _recorder = AudioRecorder();
  final SupabaseClient _client = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> startRecording() async {
    if (!await _recorder.hasPermission()) {
      throw const VoiceMessageException('لا يمكن التسجيل بدون إذن الميكروفون.');
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/dawacare_${_uuid.v4()}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: path,
    );
  }

  Future<String?> stopRecording() => _recorder.stop();

  Future<void> cancelRecording() async {
    await _recorder.cancel();
  }

  Future<bool> isRecording() => _recorder.isRecording();

  Future<VoiceMessage> sendRecording({
    required String patientId,
    String? doseId,
    required String localPath,
    required int durationMs,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) throw const VoiceMessageException('يجب تسجيل الدخول أولاً.');
    if (durationMs <= 0) throw const VoiceMessageException('التسجيل فارغ.');
    if (durationMs > maxDuration.inMilliseconds) {
      throw const VoiceMessageException('الرسالة الصوتية يجب ألا تتجاوز دقيقة واحدة.');
    }

    final file = File(localPath);
    if (!await file.exists()) throw const VoiceMessageException('ملف التسجيل غير موجود.');

    final messageId = _uuid.v4();
    final storagePath = '$patientId/$senderId/$messageId.m4a';

    try {
      await _client.storage.from(bucket).upload(
        storagePath,
        file,
        fileOptions: const FileOptions(contentType: 'audio/mp4', upsert: false),
      );

      final row = await _client.from('voice_messages').insert({
        'id': messageId,
        'sender_id': senderId,
        'patient_id': patientId,
        'dose_id': doseId,
        'storage_path': storagePath,
        'duration_ms': durationMs,
      }).select('*, sender:profiles!sender_id(full_name)').single();

      try {
        final response = await _client.functions.invoke(
          'voice-message-notify',
          body: {'voice_message_id': messageId},
        );

        debugPrint(
          'DawaCare FCM notify: status=${response.status}, data=${response.data}',
        );

        if (response.status < 200 || response.status >= 300) {
          throw VoiceMessageException(
            'تم حفظ الرسالة، لكن فشل إرسال الإشعار (HTTP ${response.status}).',
          );
        }
      } catch (error, stackTrace) {
        debugPrint('DawaCare FCM notify failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        // The voice message is already stored safely. Do not delete it just
        // because push delivery failed; the patient can still receive it from
        // the in-app voice-message inbox.
      }

      return VoiceMessage.fromMap(row);
    } catch (_) {
      try {
        await _client.storage.from(bucket).remove([storagePath]);
      } catch (_) {}
      rethrow;
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<List<VoiceMessage>> fetchForPatient(String patientId) async {
    final rows = await _client
        .from('voice_messages')
        .select('*, sender:profiles!sender_id(full_name)')
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map((row) => VoiceMessage.fromMap(row)).toList();
  }

  Future<String> signedUrl(String storagePath) async {
    return _client.storage.from(bucket).createSignedUrl(storagePath, 3600);
  }

  Future<void> markRead(String messageId) async {
    await _client.from('voice_messages').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', messageId);
  }

  void dispose() => _recorder.dispose();
}

class VoiceMessageException implements Exception {
  final String message;
  const VoiceMessageException(this.message);
  @override
  String toString() => message;
}
