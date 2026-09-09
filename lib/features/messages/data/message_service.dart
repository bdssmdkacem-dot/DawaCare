import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id, patientId, senderId, recipientId, type;
  final String? body, storagePath, mimeType;
  final int? durationMs;
  final DateTime createdAt;
  final DateTime? readAt, expiresAt;
  final String senderName;
  const ChatMessage({required this.id,required this.patientId,required this.senderId,required this.recipientId,required this.type,this.body,this.storagePath,this.mimeType,this.durationMs,required this.createdAt,this.readAt,this.expiresAt,required this.senderName});
  factory ChatMessage.fromMap(Map<String,dynamic> m)=>ChatMessage(id:m['id'] as String,patientId:m['patient_id'] as String,senderId:m['sender_id'] as String,recipientId:m['recipient_id'] as String,type:m['message_type'] as String,body:m['body'] as String?,storagePath:m['storage_path'] as String?,mimeType:m['mime_type'] as String?,durationMs:(m['duration_ms'] as num?)?.toInt(),createdAt:DateTime.parse(m['created_at'] as String).toLocal(),readAt:m['read_at']==null?null:DateTime.parse(m['read_at'] as String).toLocal(),expiresAt:m['expires_at']==null?null:DateTime.parse(m['expires_at'] as String).toLocal(),senderName:(m['sender'] as Map?)?['full_name'] as String? ?? 'مستخدم');
}
class MessageService {
  MessageService._(); static final instance=MessageService._();
  final _client=Supabase.instance.client; final _uuid=const Uuid(); final _recorder=AudioRecorder(); final _picker=ImagePicker();
  Future<List<ChatMessage>> fetch(String patientId) async {final rows=await _client.from('messages').select('*, sender:profiles!sender_id(full_name)').eq('patient_id',patientId).order('created_at');return rows.map((r)=>ChatMessage.fromMap(Map<String,dynamic>.from(r))).toList();}
  Future<ChatMessage?> fetchById(String id) async {final r=await _client.from('messages').select('*, sender:profiles!sender_id(full_name)').eq('id',id).maybeSingle();return r==null?null:ChatMessage.fromMap(Map<String,dynamic>.from(r));}
  Future<void> markRead(String id) async {await _client.rpc('mark_message_read',params:{'p_message_id':id});}
  Future<ChatMessage> sendText({required String patientId,required String recipientId,required String text}) async {final sender=_client.auth.currentUser?.id;if(sender==null)throw StateError('AUTH_REQUIRED');final value=text.trim();if(value.isEmpty)throw StateError('EMPTY_MESSAGE');return _insert(patientId:patientId,recipientId:recipientId,type:'text',body:value);}
  Future<ChatMessage> sendImage({required String patientId,required String recipientId,required XFile image}) async {final sender=_client.auth.currentUser?.id;if(sender==null)throw StateError('AUTH_REQUIRED');final id=_uuid.v4();final ext=image.name.contains('.')?image.name.split('.').last.toLowerCase():'jpg';final path='messages/$sender/$id.$ext';await _client.storage.from('message-attachments').upload(path,File(image.path),fileOptions:FileOptions(contentType:image.mimeType??'image/jpeg',upsert:false));try{return await _insert(patientId:patientId,recipientId:recipientId,type:'image',storagePath:path,mimeType:image.mimeType??'image/jpeg');}catch(e){await _client.storage.from('message-attachments').remove([path]);rethrow;}}
  Future<ChatMessage> sendVoice({required String patientId,required String recipientId,required String localPath,required int durationMs}) async {final sender=_client.auth.currentUser?.id;if(sender==null)throw StateError('AUTH_REQUIRED');if(durationMs<=0||durationMs>60000)throw StateError('INVALID_VOICE_DURATION');final id=_uuid.v4();final path='messages/$sender/$id.m4a';await _client.storage.from('message-attachments').upload(path,File(localPath),fileOptions:const FileOptions(contentType:'audio/mp4',upsert:false));try{return await _insert(patientId:patientId,recipientId:recipientId,type:'voice',storagePath:path,mimeType:'audio/mp4',durationMs:durationMs);}catch(e){await _client.storage.from('message-attachments').remove([path]);rethrow;}finally{try{await File(localPath).delete();}catch(_){}}}
  Future<ChatMessage> _insert({required String patientId,required String recipientId,required String type,String? body,String? storagePath,String? mimeType,int? durationMs}) async {final row=await _client.from('messages').insert({'id':_uuid.v4(),'patient_id':patientId,'sender_id':_client.auth.currentUser!.id,'recipient_id':recipientId,'message_type':type,'body':body,'storage_path':storagePath,'mime_type':mimeType,'duration_ms':durationMs}).select('*, sender:profiles!sender_id(full_name)').single();final message=ChatMessage.fromMap(Map<String,dynamic>.from(row));try{final r=await _client.functions.invoke('message-notify',body:{'message_id':message.id});debugPrint('message-notify status=${r.status} data=${r.data}');}catch(e){debugPrint('message-notify failed: $e');}return message;}
  Future<String> signedUrl(String path)=>_client.storage.from('message-attachments').createSignedUrl(path,3600);
  Future<String> startVoiceRecording() async {if(!await _recorder.hasPermission())throw StateError('MIC_PERMISSION_DENIED');final dir=await getTemporaryDirectory();final path='${dir.path}/dawacare_chat_${_uuid.v4()}.m4a';await _recorder.start(const RecordConfig(encoder:AudioEncoder.aacLc,sampleRate:44100,numChannels:1,bitRate:64000),path:path);return path;}
  Future<String?> stopVoiceRecording()=>_recorder.stop(); Future<void> cancelVoiceRecording()=>_recorder.cancel(); Future<XFile?> pickImage()=>_picker.pickImage(source:ImageSource.gallery,imageQuality:85,maxWidth:1920); Future<bool> isRecording()=>_recorder.isRecording(); void dispose()=>_recorder.dispose();
}
