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
    if (!await _recorder.hasPermission()) throw const VoiceMessageException('لا يمكن التسجيل بدون إذن الميكروفون.');
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/dawacare_${_uuid.v4()}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, numChannels: 1, bitRate: 64000), path: path);
  }

  Future<String?> stopRecording() => _recorder.stop();
  Future<void> cancelRecording() => _recorder.cancel();
  Future<bool> isRecording() => _recorder.isRecording();

  Future<VoiceMessage> sendRecording({required String patientId, String? doseId, required String localPath, required int durationMs}) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) throw const VoiceMessageException('يجب تسجيل الدخول أولاً.');
    if (durationMs <= 0) throw const VoiceMessageException('التسجيل فارغ.');
    if (durationMs > maxDuration.inMilliseconds) throw const VoiceMessageException('الرسالة الصوتية يجب ألا تتجاوز دقيقة واحدة.');
    final file = File(localPath);
    if (!await file.exists()) throw const VoiceMessageException('ملف التسجيل غير موجود.');

    final messageId = _uuid.v4();
    final storagePath = '$patientId/$senderId/$messageId.m4a';
    try {
      await _client.storage.from(bucket).upload(storagePath, file, fileOptions: const FileOptions(contentType: 'audio/mp4', upsert: false));
      final row = await _client.from('voice_messages').insert({'id': messageId, 'sender_id': senderId, 'patient_id': patientId, 'dose_id': doseId, 'storage_path': storagePath, 'duration_ms': durationMs}).select('*, sender:profiles!sender_id(full_name, avatar_url)').single();

      // FCM delivery is intentionally retried: the message itself is already
      // safely stored, so a transient network/function failure must not make
      // the user lose the notification.
      var notified = false;
      Object? lastError;
      for (var attempt = 1; attempt <= 3 && !notified; attempt++) {
        try {
          final response = await _client.functions.invoke(
            'voice-message-notify',
            body: {'voice_message_id': messageId},
          );
          debugPrint('DawaCare FCM notify attempt=$attempt status=${response.status} data=${response.data}');
          notified = response.status >= 200 && response.status < 300 &&
              response.data is Map && ((response.data as Map)['sent'] ?? 0) is num &&
              (((response.data as Map)['sent'] as num) > 0);
          if (!notified && attempt < 3) {
            await Future<void>.delayed(Duration(seconds: attempt));
          }
        } catch (error, stackTrace) {
          lastError = error;
          debugPrint('DawaCare FCM notify attempt=$attempt failed: $error');
          if (attempt < 3) await Future<void>.delayed(Duration(seconds: attempt));
          if (attempt == 3) debugPrintStack(stackTrace: stackTrace);
        }
      }
      if (!notified) {
        debugPrint('DawaCare FCM notify exhausted retries for voice_message_id=$messageId error=$lastError');
      }
      return VoiceMessage.fromMap(row);
    } catch (_) {
      try { await _client.storage.from(bucket).remove([storagePath]); } catch (_) {}
      rethrow;
    } finally {
      try { await file.delete(); } catch (_) {}
    }
  }

  Future<List<VoiceMessage>> fetchForPatient(String patientId) async {
    final rows = await _client.from('voice_messages').select('*, sender:profiles!sender_id(full_name, avatar_url)').eq('patient_id', patientId).order('created_at', ascending: false).limit(50);
    return rows.map((row) => VoiceMessage.fromMap(row)).toList();
  }

  Future<VoiceMessage?> fetchById(String messageId) async {
    final row = await _client.from('voice_messages').select('*, sender:profiles!sender_id(full_name, avatar_url)').eq('id', messageId).maybeSingle();
    return row == null ? null : VoiceMessage.fromMap(row);
  }

  Future<Map<String, dynamic>?> fetchDoseContext(String doseId) async {
    final dose = await _client.from('dose_instances').select('id, medication_id, dose_amount, scheduled_at').eq('id', doseId).maybeSingle();
    if (dose == null) return null;
    final medication = await _client.from('medications').select('id, name, generic_name, strength, dosage_form, image_url').eq('id', dose['medication_id']).maybeSingle();
    return {'dose': dose, 'medication': medication};
  }

  Future<String> signedUrl(String storagePath) async => _client.storage.from(bucket).createSignedUrl(storagePath, 3600);

  Future<void> markRead(String messageId) async => _client.from('voice_messages').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', messageId);

  Future<ListenCompletionResult> completeListen(String messageId) async {
    final response = await _client.rpc('complete_voice_message_listen', params: {'p_message_id': messageId});
    final row = response is List && response.isNotEmpty ? response.first as Map<String, dynamic> : null;
    if (row == null) throw const VoiceMessageException('تعذّر تسجيل اكتمال الاستماع.');
    final count = (row['completed_listens'] as num).toInt();
    return ListenCompletionResult(completedListens: count, deleted: row['deleted'] == true, storagePath: row['storage_path'] as String);
  }

  Future<void> deleteStorageFile(String storagePath) async => _client.storage.from(bucket).remove([storagePath]);
  void dispose() => _recorder.dispose();
}

class ListenCompletionResult {
  final int completedListens;
  final bool deleted;
  final String storagePath;
  const ListenCompletionResult({required this.completedListens, required this.deleted, required this.storagePath});
}

class VoiceMessageException implements Exception {
  final String message;
  const VoiceMessageException(this.message);
  @override String toString() => message;
}
