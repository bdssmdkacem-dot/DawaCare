import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

/// Registers this device for FCM and routes notification taps to the app.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _client = Supabase.instance.client;
  bool _initialized = false;
  String? _latestToken;
  String? _pendingVoiceMessageId;
  String? _pendingCaregiverAlertId;
  StreamSubscription<String>? _localVoiceSubscription;
  StreamSubscription<String>? _localNotificationSubscription;
  final StreamController<String> _voiceMessageController = StreamController<String>.broadcast();
  final StreamController<String> _notificationController = StreamController<String>.broadcast();

  Stream<String> get voiceMessageOpened => _voiceMessageController.stream;
  Stream<String> get notificationOpened => _notificationController.stream;

  Future<void> init() async {
    if (_initialized || !Platform.isAndroid) return;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    _localVoiceSubscription = NotificationService.instance.voiceMessageOpened.listen(_queueVoiceMessageId);
    _localNotificationSubscription = NotificationService.instance.notificationOpened.listen(_queueCaregiverAlertId);

    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;
      final type = message.data['type'];
      final messageId = message.data['voice_message_id'];
      final alertId = message.data['alert_id'];
      final payload = type == 'VOICE_MESSAGE' && messageId is String && messageId.isNotEmpty
          ? 'VOICE_MESSAGE:$messageId'
          : type == 'CAREGIVER_ALERT' && alertId is String && alertId.isNotEmpty
              ? 'CAREGIVER_ALERT:$alertId'
              : null;
      await NotificationService.instance.showCaregiverAlert(
        title: notification.title ?? 'دواء كير — تنبيه',
        body: notification.body ?? 'لديك تنبيه جديد من أحد أفراد العائلة.',
        payload: payload,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _queueOpenedMessage(initialMessage);

    _latestToken = await _messaging.getToken();
    await _registerCurrentToken();
    _messaging.onTokenRefresh.listen((token) async {
      _latestToken = token;
      await _registerCurrentToken();
    });
    _client.auth.onAuthStateChange.listen((_) async => _registerCurrentToken());
    _initialized = true;
  }

  void _handleOpenedMessage(RemoteMessage message) => _queueOpenedMessage(message);

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
      final existing = await _client.from('devices').select('id').eq('user_id', user.id).eq('push_token', token).maybeSingle();
      final values = {'user_id': user.id, 'platform': 'android', 'push_token': token, 'timezone': 'Africa/Casablanca', 'last_seen': DateTime.now().toUtc().toIso8601String()};
      if (existing != null) {
        await _client.from('devices').update(values).eq('id', existing['id']);
      } else {
        await _client.from('devices').insert(values);
      }
    } catch (_) {}
  }

  void dispose() {
    _localVoiceSubscription?.cancel();
    _localNotificationSubscription?.cancel();
    _localVoiceSubscription = null;
    _localNotificationSubscription = null;
  }
}

@pragma('vm:entry-point')
Future<void> dawacareFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
