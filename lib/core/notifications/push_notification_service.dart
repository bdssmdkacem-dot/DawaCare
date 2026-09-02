import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

/// Registers this device for FCM so the server can notify users/caregivers.
/// Supabase remains the source of truth for users and device records.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _client = Supabase.instance.client;
  bool _initialized = false;
  String? _latestToken;

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

    _latestToken = await _messaging.getToken();
    await _registerCurrentToken();

    _messaging.onTokenRefresh.listen((token) async {
      _latestToken = token;
      await _registerCurrentToken();
    });

    // init() can run before AuthProvider has restored the Supabase session.
    // Re-register the same FCM token whenever authentication changes.
    _client.auth.onAuthStateChange.listen((_) async {
      await _registerCurrentToken();
    });

    _initialized = true;
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
    } catch (_) {
      // Device registration must never prevent DawaCare from starting or
      // break local medication reminders when Supabase/RLS is temporarily
      // unavailable. The next auth/token event retries registration.
    }
  }
}

@pragma('vm:entry-point')
Future<void> dawacareFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();
}
