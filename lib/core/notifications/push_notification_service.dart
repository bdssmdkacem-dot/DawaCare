import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

/// Registers this device for FCM so the server can notify caregivers when a
/// linked patient misses a medication dose.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _client = Supabase.instance.client;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || !Platform.isAndroid) return;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;

      await NotificationService.instance.showCaregiverAlert(
        title: notification.title ?? 'دواء كير — تنبيه',
        body: notification.body ?? 'لديك تنبيه جديد من أحد أفراد العائلة.',
      );
    });

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerToken(token);
    }

    _messaging.onTokenRefresh.listen((token) async {
      await _registerToken(token);
    });

    _initialized = true;
  }

  Future<void> _registerToken(String token) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

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
  }
}

@pragma('vm:entry-point')
Future<void> dawacareFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();
}
