import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../models/dose_instance.dart';
import '../../models/reminder_policy.dart';

/// The on-device half of the Reminder Engine (see README §Architecture).
///
/// Schedules a short burst of local notifications around each dose's
/// `scheduled_at`: one at the exact time, then up to [ReminderPolicy.maxRepeats]
/// follow-ups spaced [ReminderPolicy.repeatIntervalMin] apart. These fire even
/// if the app is closed (Android exact alarms), which covers the common case.
///
/// The *reliable* fallback for when the phone is off, DND, or the alarm gets
/// killed by the OS is the server-side `escalation-check` Edge Function
/// (see supabase/functions/escalation-check), which independently marks
/// doses MISSED and alerts caregivers based on the database clock, not the
/// device's.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _channelId = 'dose_reminders';
  static const String _caregiverChannelId = 'caregiver_alerts';

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
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const caregiverChannel = AndroidNotificationChannel(
      _caregiverChannelId,
      'تنبيهات العائلة',
      description: 'تنبيه عند تفويت أحد أفراد العائلة لجرعة دواء',
      importance: Importance.high,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(caregiverChannel);

    _initialized = true;
  }

  /// Requests POST_NOTIFICATIONS (Android 13+) and exact-alarm (Android 12+)
  /// permissions. Call this from onboarding / settings, not silently on boot.
  Future<bool> requestPermissions() async {
    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final notifGranted = await androidImpl?.requestNotificationsPermission() ?? true;
    final exactAlarmGranted = await androidImpl?.requestExactAlarmsPermission() ?? true;
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

    final now = tz.TZDateTime.now(tz.local);
    final baseTime = tz.TZDateTime.from(dose.scheduledAt, tz.local);

    for (int i = 0; i <= policy.maxRepeats; i++) {
      final fireTime = baseTime.add(Duration(minutes: policy.repeatIntervalMin * i));
      if (fireTime.isBefore(now)) continue;

      await _plugin.zonedSchedule(
        _notificationId(dose.id, i),
        i == 0 ? 'حان موعد الدواء 💊' : 'تذكير: الجرعة لم تُؤكَّد بعد',
        '${dose.medicationName} — ${dose.doseAmount}',
        fireTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'تذكير الجرعات',
            channelDescription: 'إشعارات تذكير بمواعيد الأدوية',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
       androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
payload: dose.id,
      );
    }
  }

  Future<void> cancelDoseReminders(String doseId) async {
    // maxRepeats is capped at a small number app-side; 10 slots is generous
    // headroom so a lowered policy never leaves an orphaned notification.
    for (int i = 0; i <= 10; i++) {
      await _plugin.cancel(_notificationId(doseId, i));
    }
  }

  /// Shows a push alert that arrived via FCM (see PushRegistrationService)
  /// while the app is in the foreground — FCM only auto-displays
  /// notifications when the app is backgrounded/terminated, so foreground
  /// delivery has to be surfaced manually through the same local-notification
  /// plugin, on its own channel so it reads distinctly from dose reminders.
  Future<void> showCaregiverAlert({required String title, required String body}) async {
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
