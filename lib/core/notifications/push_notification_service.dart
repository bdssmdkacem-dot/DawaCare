import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';
import 'rich_push_notification_service.dart';

class PushNotificationService {
  PushNotificationService._(); static final instance=PushNotificationService._();
  final _messaging=FirebaseMessaging.instance; final _client=Supabase.instance.client; Future<void>? _initFuture; bool _initialized=false; String? _latestToken; String? _pendingVoiceMessageId,_pendingCaregiverAlertId,_pendingChatMessageId;
  StreamSubscription<String>? _localVoiceSubscription,_localNotificationSubscription,_localChatSubscription; StreamSubscription<RemoteMessage>? _foregroundSubscription,_openedSubscription; StreamSubscription<String>? _tokenSubscription; StreamSubscription<AuthState>? _authSubscription;
  final _voiceMessageController=StreamController<String>.broadcast(),_notificationController=StreamController<String>.broadcast(),_chatController=StreamController<String>.broadcast();
  Stream<String> get voiceMessageOpened=>_voiceMessageController.stream; Stream<String> get notificationOpened=>_notificationController.stream; Stream<String> get chatMessageOpened=>_chatController.stream;
  Future<void> init() async {if(!Platform.isAndroid)return;if(_initialized)return;final running=_initFuture;if(running!=null)return running;final future=_initialize();_initFuture=future;try{await future;}finally{_initFuture=null;}}
  Future<void> _initialize() async {
    await NotificationService.instance.init(); await RichPushNotificationService.instance.init(); await _messaging.setAutoInitEnabled(true);
    final settings=await _messaging.requestPermission(alert:true,badge:true,sound:true,provisional:false); debugPrint('DawaCare FCM permission: ${settings.authorizationStatus}');
    _localVoiceSubscription=NotificationService.instance.voiceMessageOpened.listen(_queueVoiceMessageId);
    _localNotificationSubscription=NotificationService.instance.notificationOpened.listen(_queueCaregiverAlertId);
    _localChatSubscription=RichPushNotificationService.instance.messageOpened.listen(_queueChatMessageId);
    _foregroundSubscription=FirebaseMessaging.onMessage.listen((message) async {
      final type=message.data['type']; final id=message.data['voice_message_id']??message.data['alert_id']??message.data['message_id'];
      final isPush=type=='VOICE_MESSAGE'||type=='CAREGIVER_ALERT'||type=='CHAT_MESSAGE'||(type is String&&type.startsWith('FAMILY_LINK_'));
      if(!isPush)return;
      String? payload;
      if(type=='VOICE_MESSAGE'&&id is String)payload='VOICE_MESSAGE:$id';
      else if(type=='CAREGIVER_ALERT'&&id is String)payload='CAREGIVER_ALERT:$id';
      else if(type=='CHAT_MESSAGE'&&id is String)payload='CHAT_MESSAGE:$id';
      else if(type is String&&type.startsWith('FAMILY_LINK_')&&message.data['request_id'] is String)payload='FAMILY_LINK:${message.data['request_id']}';
      await RichPushNotificationService.instance.show(title:message.notification?.title??'DawaCare',body:message.notification?.body??'لديك إشعار جديد.',payload:payload);
    });
    _openedSubscription=FirebaseMessaging.onMessageOpenedApp.listen(_queueOpenedMessage);
    final initial=await _messaging.getInitialMessage(); if(initial!=null)_queueOpenedMessage(initial);
    _latestToken=await _messaging.getToken(); _tokenSubscription=_messaging.onTokenRefresh.listen((t)async{_latestToken=t;await _registerCurrentToken();});
    _authSubscription=_client.auth.onAuthStateChange.listen((_)async=>_registerCurrentToken()); _initialized=true; await _registerCurrentToken();
  }
  Future<void> ensureRegistered() async{await init();await _registerCurrentToken();}
  void _queueOpenedMessage(RemoteMessage m){final type=m.data['type'];if(type=='VOICE_MESSAGE'&&m.data['voice_message_id'] is String)_queueVoiceMessageId(m.data['voice_message_id'] as String);else if(type=='CAREGIVER_ALERT'&&m.data['alert_id'] is String)_queueCaregiverAlertId(m.data['alert_id'] as String);else if(type=='CHAT_MESSAGE'&&m.data['message_id'] is String)_queueChatMessageId(m.data['message_id'] as String);}
  void _queueVoiceMessageId(String id){_pendingVoiceMessageId=id;if(!_voiceMessageController.isClosed)_voiceMessageController.add(id);}
  void _queueCaregiverAlertId(String id){_pendingCaregiverAlertId=id;if(!_notificationController.isClosed)_notificationController.add(id);}
  void _queueChatMessageId(String id){_pendingChatMessageId=id;if(!_chatController.isClosed)_chatController.add(id);}
  String? takePendingVoiceMessageId(){final id=_pendingVoiceMessageId;_pendingVoiceMessageId=null;return id;}
  String? takePendingCaregiverAlertId(){final id=_pendingCaregiverAlertId;_pendingCaregiverAlertId=null;return id;}
  String? takePendingChatMessageId(){final id=_pendingChatMessageId;_pendingChatMessageId=null;return id;}
  Future<void> _registerCurrentToken()async{final t=_latestToken;if(t==null||t.isEmpty)return;await _registerToken(t);}
  Future<void> _registerToken(String token)async{final user=_client.auth.currentUser;if(user==null)return;try{final existing=await _client.from('devices').select('id').eq('user_id',user.id).eq('push_token',token).maybeSingle();final values={'user_id':user.id,'platform':'android','push_token':token,'timezone':'Africa/Casablanca','last_seen':DateTime.now().toUtc().toIso8601String()};if(existing!=null)await _client.from('devices').update(values).eq('id',existing['id']);else await _client.from('devices').insert(values);}catch(e){debugPrint('DawaCare FCM token registration failed: $e');}}
  Future<void> unregister(String userId)async{final token=_latestToken??await _messaging.getToken();if(token==null||token.isEmpty)return;try{await _client.from('devices').delete().eq('user_id',userId).eq('push_token',token);}catch(e){debugPrint('DawaCare FCM token unregister failed: $e');}}
  Future<void> dispose()async{await _foregroundSubscription?.cancel();await _openedSubscription?.cancel();await _tokenSubscription?.cancel();await _authSubscription?.cancel();await _localVoiceSubscription?.cancel();await _localNotificationSubscription?.cancel();await _localChatSubscription?.cancel();await _voiceMessageController.close();await _notificationController.close();await _chatController.close();_initialized=false;}
}
@pragma('vm:entry-point') Future<void> dawacareFirebaseMessagingBackgroundHandler(RemoteMessage message)async{await Firebase.initializeApp();debugPrint('DawaCare FCM background received: ${message.data['type']}');}
