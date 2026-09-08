import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

class RichPushNotificationService {
  RichPushNotificationService._();
  static final instance = RichPushNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const _channelId = 'caregiver_alerts_v2';

  Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _plugin.initialize(settings);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'تنبيهات العائلة',
      description: 'إشعارات الرسائل وطلبات المتابعة',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    ));
    _initialized = true;
  }

  Future<void> show({required String title, required String body, String? imageUrl, String? payload}) async {
    await init();
    String? localImage;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      localImage = await _downloadImage(imageUrl.trim());
    }
    final details = AndroidNotificationDetails(
      _channelId,
      'تنبيهات العائلة',
      channelDescription: 'إشعارات الرسائل وطلبات المتابعة',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      sound: null,
      largeIcon: localImage == null ? null : FilePathAndroidBitmap(localImage),
      styleInformation: localImage == null ? null : BigPictureStyleInformation(FilePathAndroidBitmap(localImage), hideExpandedLargeIcon: false, contentTitle: title, summaryText: body),
    );
    await _plugin.show(DateTime.now().millisecondsSinceEpoch.remainder(100000000), title, body, NotificationDetails(android: details), payload: payload);
  }

  Future<String?> _downloadImage(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/push_sender_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await response.pipe(file.openWrite());
      client.close(force: true);
      return await file.exists() ? file.path : null;
    } catch (_) {
      return null;
    }
  }
}