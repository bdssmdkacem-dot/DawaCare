import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../models/dose_instance.dart';
import '../../models/reminder_policy.dart';

/// The on-device half of the Reminder Engine (see README §Architecture).
///
/// Schedules local notifications around each dose's scheduled_at. Medication
/// images are downloaded into the app cache and used only as notification
/// assets; failure to load an image never prevents a medication reminder.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final SupabaseClient _client = Supabase.instance.client;
  bool _initialized = false;

  static const String _channelId = 'dose_reminders';
  static const String _caregiverChannelId = 'caregiver_alerts';
  static const String _imageBucket = 'medication-images';

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final String tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Casablanca'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      'تذكير الجرعات',
      description: 'إشعارات تذكير بمواعيد الأدوية',
      importance: Importance.max,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const caregiverChannel = AndroidNotificationChannel(
      _caregiverChannelId,
      'تنبيهات العائلة',
      description: 'تنبيه عند تفويت أحد أفراد العائلة لجرعة دواء',
      importance: Importance.high,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(caregiverChannel);

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notifGranted =
        await androidImpl?.requestNotificationsPermission() ?? true;
    final exactAlarmGranted =
        await androidImpl?.requestExactAlarmsPermission() ?? true;
    return notifGranted && exactAlarmGranted;
  }

  Future<void> scheduleDoseReminders({
    required DoseInstance dose,
    required ReminderPolicy policy,
  }) async {
    await cancelDoseReminders(dose.id);
    if (dose.status == DoseStatus.taken ||
        dose.status == DoseStatus.skipped ||
        dose.status == DoseStatus.cancelled) {
      return;
    }

    // Best effort only. A missing/expired/private image must never block a
    // medication reminder.
    final imagePath = await _prepareMedicationImage(dose);

    final now = tz.TZDateTime.now(tz.local);
    final baseTime = tz.TZDateTime.from(dose.scheduledAt, tz.local);

    for (int i = 0; i <= policy.maxRepeats; i++) {
      final fireTime =
          baseTime.add(Duration(minutes: policy.repeatIntervalMin * i));
      if (fireTime.isBefore(now)) continue;

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        'تذكير الجرعات',
        channelDescription: 'إشعارات تذكير بمواعيد الأدوية',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        largeIcon:
            imagePath == null ? null : FilePathAndroidBitmap(imagePath),
        styleInformation: imagePath == null
            ? null
            : BigPictureStyleInformation(
                FilePathAndroidBitmap(imagePath),
                hideExpandedLargeIcon: false,
                contentTitle: dose.medicationName,
                summaryText: dose.doseAmount,
              ),
      );

      await _plugin.zonedSchedule(
        _notificationId(dose.id, i),
        i == 0 ? 'حان موعد الدواء 💊' : 'تذكير: الجرعة لم تُؤكَّد بعد',
        '${dose.medicationName} — ${dose.doseAmount}',
        fireTime,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: dose.id,
      );
    }
  }

  Future<String?> _prepareMedicationImage(DoseInstance dose) async {
    try {
      final row = await _client
          .from('medications')
          .select('image_url')
          .eq('id', dose.medicationId)
          .maybeSingle();
      final storagePath = row?['image_url'] as String?;
      if (storagePath == null || storagePath.isEmpty) return null;

      final signedUrl = storagePath.startsWith('http://') ||
              storagePath.startsWith('https://')
          ? storagePath
          : await _client.storage
              .from(_imageBucket)
              .createSignedUrl(storagePath, 3600);

      final uri = Uri.tryParse(signedUrl);
      if (uri == null) return null;

      final directory = await getTemporaryDirectory();
      final safeId = dose.medicationId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${directory.path}/medication_$safeId.jpg');

      final request = await HttpClient().getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      await response.pipe(file.openWrite());

      return await file.exists() ? file.path : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> cancelDoseReminders(String doseId) async {
    for (int i = 0; i <= 10; i++) {
      await _plugin.cancel(_notificationId(doseId, i));
    }
  }

  Future<void> showCaregiverAlert({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _caregiverChannelId,
          'تنبيهات العائلة',
          channelDescription: 'تنبيه عند تفويت أحد أفراد العائلة لجرعة دواء',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  int _notificationId(String doseId, int index) {
    return ((doseId.hashCode & 0x7fffffff) ~/ 100) * 100 + index;
  }
}
