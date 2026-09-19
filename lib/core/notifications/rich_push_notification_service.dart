import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RichPushNotificationService {
  RichPushNotificationService._();
  static final instance = RichPushNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final _messageController = StreamController<String>.broadcast();

  Stream<String> get messageOpened => _messageController.stream;

  static const channelId = 'caregiver_alerts_v2';
  Future<String> _channelName() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString('dawacare_locale')) {
      'en' => 'Family alerts',
      'fr' => 'Alertes familiales',
      _ => 'تنبيهات العائلة',
    };
  }

  Future<String> _channelDescription() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString('dawacare_locale')) {
      'en' => 'Message and follow-up request notifications',
      'fr' => 'Notifications de messages et demandes de suivi',
      _ => 'إشعارات الرسائل وطلبات المتابعة',
    };
  }

  Future<void> init() async {
    if (_initialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.startsWith('CHAT_MESSAGE:')) {
          _messageController.add(payload.substring('CHAT_MESSAGE:'.length));
        }
      },
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final channelName = await _channelName();
    final channelDescription = await _channelDescription();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
    );

    _initialized = true;
  }

  Future<void> show({
    required String title,
    required String body,
    String? imageUrl,
    String? payload,
  }) async {
    await init();

    String? localImage;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      localImage = await _downloadImage(imageUrl.trim());
    }

    final details = AndroidNotificationDetails(
      channelId,
      await _channelName(),
      channelDescription: await _channelDescription(),
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      largeIcon: localImage == null ? null : FilePathAndroidBitmap(localImage),
      styleInformation: localImage == null
          ? null
          : BigPictureStyleInformation(
              FilePathAndroidBitmap(localImage),
              hideExpandedLargeIcon: false,
              contentTitle: title,
              summaryText: body,
            ),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000000),
      title,
      body,
      NotificationDetails(android: details),
      payload: payload,
    );
  }

  Future<String?> _downloadImage(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return null;
      }
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/push_sender_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await response.pipe(file.openWrite());
      client.close(force: true);
      return await file.exists() ? file.path : null;
    } catch (_) {
      return null;
    }
  }
}
