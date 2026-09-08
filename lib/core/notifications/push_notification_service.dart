import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';
import 'rich_push_notification_service.dart';

/// Owns the complete Android FCM lifecycle for DawaCare.
///
/// There is deliberately one registration path. Auth and app startup both
/// call [ensureRegistered], but initialization is serialized so listeners
/// and device-token writes cannot be duplicated.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _client = Supabase.instance.client;
  Future<void>? _initFuture;
  bool _initialized = false;
  String? _latestToken;
  String? _pendingVoiceMessageId;
  String? _pendingCaregiverAlertId;
  StreamSubscription<String>? _localVoiceSubscription;
  StreamSubscription<String>? _localNotificationSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  final StreamController<String> _voiceMessageController = StreamController<String>.broadcast();
  final StreamController<String> _notificationController = StreamController<String>.broadcast();

  Stream<String> get voiceMessageOpened => _voiceMessageController.stream;
  Stream<String> get notificationOpened => _notificationController.stream;

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    if (_initialized) return;
    final running = _initFuture;
    if (running != null) return running;
    final future = _initialize();
    _initFuture = future;
    try {
      await future;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _initialize() async {
    await NotificationService.instance.init();
    await RichPushNotificationService.instance.init();
    await _messaging.setAutoInitEnabled(true);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('DawaCare FCM permission: ${settings.authorizationStatus}');

    _localVoiceSubscription = NotificationService.instance.voiceMessageOpened.listen(_queueVoiceMessageId);
    _localNotificationSubscription = NotificationService.instance.notificationOpened.listen(_queueCaregiverAlertId);

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) async {
      debugPrint('DawaCare FCM foreground received: id=${message.messageId} type=${message.data['type']}');
      final notification = message.notification;
      final type = message.data['type'];
      final messageId = message.data['voice_message_id'];
      final alertId = message.data['alert_id'];
      final requestId = message.data['request_id'];
      final senderAvatar = message.data['sender_avatar_url'];
      final payload = type == 'VOICE_MESSAGE' && messageId is String && messageId.isNotEmpty
          ? 'VOICE_MESSAGE:$messageId'
          : type == 'CAREGIVER_ALERT' && alertId is String && alertId.isNotEmpty
              ? 'CAREGIVER_ALERT:$alertId'
              : type is String && type.startsWith('FAMILY_LINK_') && requestId is String && requestId.isNotEmpty
                  ? 'FAMILY_LINK:$requestId'
                  : null;
      final isPushEvent = type == 'VOICE_MESSAGE' ||
          type == 'CAREGIVER_ALERT' ||
          (type is String && type.startsWith('FAMILY_LINK_'));
      if (isPushEvent) {
        await RichPushNotificationService.instance.show(
          title: notification?.title ?? 'DawaCare',
          body: notification?.body ?? 'لديك إشعار جديد.',
          imageUrl: senderAvatar is String && senderAvatar.isNotEmpty ? senderAvatar : null,
          payload: payload,
        );
      }
    });

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('DawaCare FCM notification opened: id=${message.messageId} type=${message.data['type']}');
      _queueOpenedMessage(message);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('DawaCare FCM initial message: id=${initialMessage.messageId} type=${initialMessage.data['type']}');
      _queueOpenedMessage(initialMessage);
    }

    _latestToken = await _messaging.getToken();
    debugPrint('DawaCare FCM token available: ${_latestToken == null ? 'NO' : 'YES'}');

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
      debugPrint('DawaCare FCM token refreshed');
      _latestToken = token;
      await _registerCurrentToken();
    });

    _authSubscription = _client.auth.onAuthStateChange.listen((_) async {
      await _registerCurrentToken();
    });

    _initialized = true;
    await _registerCurrentToken();
  }

  Future<void> ensureRegistered() async {
    await init();
    await _registerCurrentToken();
  }

  void _queueOpenedMessage(RemoteMessage message) {
    final type = message.data['type'];
    final messageId = message.data['voice_message_id'];
    final alertId = message.data['alert_id'];
    if (type == 'VOICE_MESSAGE' && messageId is String && messageId.isNotEmpty) {
      _queueVoiceMessageId(messageId);
    } else if (type == 'CAREGIVER_ALERT' && alertId is String && alertId.isNotEmpty) {
      _queueCaregiverAlertId(alertId);
    }
  }

  void _queueVoiceMessageId(String messageId) {
    _pendingVoiceMessageId = messageId;
    debugPrint('DawaCare FCM voice deep link: $messageId');
    if (!_voiceMessageController.isClosed) _voiceMessageController.add(messageId);
  }

  void _queueCaregiverAlertId(String alertId) {
    _pendingCaregiverAlertId = alertId;
    debugPrint('DawaCare caregiver alert deep link: $alertId');
    if (!_notificationController.isClosed) _notificationController.add(alertId);
  }

  String? takePendingVoiceMessageId() {
    final id = _pendingVoiceMessageId;
    _pendingVoiceMessageId = null;
    return id;
  }

  String? takePendingCaregiverAlertId() {
    final id = _pendingCaregiverAlertId;
    _pendingCaregiverAlertId = null;
    return id;
  }

  Future<void> _registerCurrentToken() async {
    final token = _latestToken;
    if (token == null || token.isEmpty) return;
    await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final existing = await _client
          .from('devices')
          .select('id')
          .eq('user_id', user.id)
          .eq('push_token', token)
          .maybeSingle();
      final values = {
        'user_id': user.id,
        'platform': 'android',
        'push_token': token,
        'timezone': 'Africa/Casablanca',
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      };
      if (existing != null) {
        await _client.from('devices').update(values).eq('id', existing['id']);
      } else {
        await _client.from('devices').insert(values);
      }
      debugPrint('DawaCare FCM token registered for user=${user.id}');
    } catch (e) {
      debugPrint('DawaCare FCM token registration failed: $e');
    }
  }

  Future<void> unregister(String userId) async {
    final token = _latestToken ?? await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    try {
      await _client.from('devices').delete().eq('user_id', userId).eq('push_token', token);
      debugPrint('DawaCare FCM token unregistered for user=$userId');
    } catch (e) {
      debugPrint('DawaCare FCM token unregister failed: $e');
    }
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
    await _localVoiceSubscription?.cancel();
    await _localNotificationSubscription?.cancel();
    await _voiceMessageController.close();
    await _notificationController.close();
    _foregroundSubscription = null;
    _openedSubscription = null;
    _tokenSubscription = null;
    _authSubscription = null;
    _localVoiceSubscription = null;
    _localNotificationSubscription = null;
    _initialized = false;
  }
}

@pragma('vm:entry-point')
Future<void> dawacareFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('DawaCare FCM background received: id=${message.messageId} type=${message.data['type']}');
}
