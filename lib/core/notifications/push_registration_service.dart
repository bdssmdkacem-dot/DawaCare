import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

/// Registers this device's FCM token into the `devices` table so the
/// `escalation-check` Edge Function can push a "missed dose" alert straight
/// to a caregiver's phone (see supabase/README.md §5).
///
/// This is intentionally best-effort: if Firebase isn't configured yet (no
/// `android/app/google-services.json`, plugin not applied — see README), the
/// call to [Firebase.initializeApp] throws and [initAndRegister] just
/// returns silently. Everything else in the app — local dose reminders
/// included — works fully without this ever succeeding; push is additive,
/// not required.
class PushRegistrationService {
  PushRegistrationService._();
  static final PushRegistrationService instance = PushRegistrationService._();

  FirebaseMessaging? _messaging;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  bool _ready = false;

  Future<void> initAndRegister(String userId) async {
    if (!_ready) {
      try {
        await Firebase.initializeApp();
        _messaging = FirebaseMessaging.instance;
        _ready = true;
      } catch (_) {
        // Firebase not configured — push stays inactive, nothing else to do.
        return;
      }
    }

    final messaging = _messaging;
    if (messaging == null) return;

    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) await _registerToken(userId, token);

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) => _registerToken(userId, newToken));

      await _foregroundMessageSub?.cancel();
      _foregroundMessageSub = FirebaseMessaging.onMessage.listen(_showForegroundAlert);
    } catch (_) {
      // Network hiccup or permission denial — silent no-op, matches the
      // best-effort nature of push described above.
    }
  }

  Future<void> _registerToken(String userId, String token) async {
    try {
      await Supabase.instance.client.from('devices').upsert(
        {
          'user_id': userId,
          'platform': 'android',
          'push_token': token,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,push_token',
      );
    } catch (_) {
      // Will simply retry on next app open / token refresh.
    }
  }

  Future<void> _showForegroundAlert(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await NotificationService.instance.showCaregiverAlert(
      title: notification.title ?? 'دواء كير',
      body: notification.body ?? '',
    );
  }

  /// Best-effort cleanup on sign-out so a shared/reused device doesn't keep
  /// receiving another account's caregiver alerts.
  Future<void> unregister(String userId) async {
    await _tokenRefreshSub?.cancel();
    await _foregroundMessageSub?.cancel();
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await Supabase.instance.client
            .from('devices')
            .delete()
            .eq('user_id', userId)
            .eq('push_token', token);
      }
    } catch (_) {}
  }
}
