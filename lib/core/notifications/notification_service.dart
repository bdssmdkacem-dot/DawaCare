import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/doses/data/dose_repository.dart';
import '../../models/dose_instance.dart';
import '../../models/reminder_policy.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final SupabaseClient _client = Supabase.instance.client;
  final StreamController<String> _voiceMessageController = StreamController<String>.broadcast();
  final StreamController<String> _notificationController = StreamController<String>.broadcast();
  bool _initialized = false;

  static const String _channelId = 'dose_reminders';
  static const String _caregiverChannelId = 'caregiver_alerts';
  static const String _imageBucket = 'medication-images';
  static const String _voicePayloadPrefix = 'VOICE_MESSAGE:';
  static const String _caregiverAlertPayloadPrefix = 'CAREGIVER_ALERT:';
  static const String _actionTaken = 'DOSE_TAKEN';
  static const String _actionSnooze = 'DOSE_SNOOZE';

  Stream<String> get voiceMessageOpened => _voiceMessageController.stream;
  Stream<String> get notificationOpened => _notificationController.stream;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final String tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
      debugPrint('DawaCare timezone initialized: $tzName');
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('Africa/Casablanca'));
      debugPrint('DawaCare timezone fallback: Africa/Casablanca ($e)');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      'تذكير الجرعات',
      description: 'إشعارات تذكير بمواعيد الأدوية',
      importance: Importance.max,
      enableVibration: true,
    );
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);

    const caregiverChannel = AndroidNotificationChannel(
      _caregiverChannelId,
      'تنبيهات العائلة',
      description: 'تنبيه عند تفويت أحد أفراد العائلة لجرعة دواء',
      importance: Importance.high,
      enableVibration: true,
    );
    await android?.createNotificationChannel(caregiverChannel);

    _initialized = true;
    await logDiagnostics('init');
  }

  Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    try {
      final notificationsGranted = await android.requestNotificationsPermission();
      debugPrint('DawaCare notifications permission: $notificationsGranted');
    } catch (e) {
      debugPrint('DawaCare notification permission request failed: $e');
    }

    try {
      final exactAlarmGranted = await android.requestExactAlarmsPermission();
      debugPrint('DawaCare exact alarm permission request: $exactAlarmGranted');
    } catch (e) {
      debugPrint('DawaCare exact alarm permission unavailable: $e');
    }

    await logDiagnostics('requestPermissions');
  }

  Future<bool> _canScheduleExactAlarms() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _schedule(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
    NotificationDetails details, {
    String? payload,
  }) async {
    final exactAllowed = await _canScheduleExactAlarms();
    final mode = exactAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    debugPrint(
      'DawaCare scheduling: id=$id at=$scheduledDate timezone=${tz.local.name} '
      'mode=$mode exactAllowed=$exactAllowed payload=$payload',
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('DawaCare notification scheduled successfully: id=$id');
    } catch (e) {
      if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
        try {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
          debugPrint('DawaCare notification scheduled with fallback inexact alarm: id=$id');
          return;
        } catch (fallbackError) {
          debugPrint('DawaCare notification fallback scheduling failed: $fallbackError');
        }
      } else {
        debugPrint('DawaCare notification scheduling failed: $e');
      }
      rethrow;
    }

    await logDiagnostics('schedule id=$id');
  }

  /// Returns the notifications Android currently has queued for DawaCare.
  /// This is the decisive diagnostic for distinguishing Flutter scheduling
  /// failures from Android delivery/battery/ROM restrictions.
  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('DawaCare pending notifications: count=${pending.length}');
    for (final item in pending) {
      debugPrint(
        'DawaCare pending notification: id=${item.id} title=${item.title} '
        'body=${item.body} payload=${item.payload}',
      );
    }
    return pending;
  }

  Future<void> logDiagnostics([String reason = 'manual']) async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      debugPrint('DawaCare notification diagnostics [$reason]: Android implementation unavailable');
      return;
    }

    bool? notificationsEnabled;
    bool? exactAlarmEnabled;
    try {
      notificationsEnabled = await android.areNotificationsEnabled();
    } catch (e) {
      debugPrint('DawaCare notification permission status failed: $e');
    }
    try {
      exactAlarmEnabled = await android.canScheduleExactNotifications();
    } catch (e) {
      debugPrint('DawaCare exact alarm status failed: $e');
    }

    debugPrint(
      'DawaCare notification diagnostics [$reason]: '
      'initialized=$_initialized, notificationsEnabled=$notificationsEnabled, '
      'exactAlarmEnabled=$exactAlarmEnabled, timezone=${tz.local.name}',
    );

    await pendingNotifications();
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    if (payload.startsWith(_voicePayloadPrefix)) {
      final messageId = payload.substring(_voicePayloadPrefix.length);
      if (messageId.isNotEmpty && !_voiceMessageController.isClosed) {
        _voiceMessageController.add(messageId);
      }
      return;
    }

    if (payload.startsWith(_caregiverAlertPayloadPrefix)) {
      final alertId = payload.substring(_caregiverAlertPayloadPrefix.length);
      if (alertId.isNotEmpty && !_notificationController.isClosed) {
        _notificationController.add(alertId);
      }
      return;
    }

    final doseId = payload;
    final action = response.actionId;
    if (action == _actionTaken) {
      await _handleDoseAction(doseId, DoseStatus.taken);
    } else if (action == _actionSnooze) {
      await _handleSnooze(doseId);
    }
  }

  Future<void> _handleDoseAction(String doseId, DoseStatus status) async {
    try {
      final rows = await _client.from('dose_instances').select('*, medications(name)').eq('id', doseId).maybeSingle();
      if (rows == null) return;
      final dose = DoseInstance.fromMap(rows);
      await DoseRepository().updateStatus(dose, status, source: 'NOTIFICATION');
      await cancelDoseReminders(doseId);
    } catch (e) {
      debugPrint('DawaCare notification action failed: $e');
    }
  }

  Future<void> _handleSnooze(String doseId) async {
    try {
      final rows = await _client.from('dose_instances').select('*, medications(name)').eq('id', doseId).maybeSingle();
      if (rows == null) return;
      final dose = DoseInstance.fromMap(rows);
      await DoseRepository().updateStatus(dose, DoseStatus.snoozed, source: 'NOTIFICATION');
      await cancelDoseReminders(doseId);
      final snoozeTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));
      final imagePath = await _prepareMedicationImage(dose);
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        'تذكير الجرعات',
        channelDescription: 'إشعارات تذكير بمواعيد الأدوية',
        importance: Importance.max,
        priority: Priority.high,
        largeIcon: imagePath == null ? null : FilePathAndroidBitmap(imagePath),
        styleInformation: imagePath == null ? null : BigPictureStyleInformation(FilePathAndroidBitmap(imagePath), hideExpandedLargeIcon: false, contentTitle: dose.medicationName, summaryText: dose.doseAmount),
        actions: const [
          AndroidNotificationAction(_actionTaken, 'تم أخذ الدواء', showsUserInterface: false, cancelNotification: true),
          AndroidNotificationAction(_actionSnooze, 'تأجيل 10 دقائق', showsUserInterface: false, cancelNotification: true),
        ],
      );
      await _schedule(
        _notificationId(dose.id, 99),
        'تذكير: حان وقت الدواء 💊',
        '${dose.medicationName} — ${dose.doseAmount}',
        snoozeTime,
        NotificationDetails(android: androidDetails),
        payload: dose.id,
      );
    } catch (e) {
      debugPrint('DawaCare snooze scheduling failed: $e');
    }
  }

  Future<void> scheduleDoseReminders({required DoseInstance dose, required ReminderPolicy policy}) async {
    await cancelDoseReminders(dose.id);
    if (dose.status == DoseStatus.taken || dose.status == DoseStatus.skipped || dose.status == DoseStatus.cancelled) return;
    final imagePath = await _prepareMedicationImage(dose);
    final now = tz.TZDateTime.now(tz.local);
    final baseTime = tz.TZDateTime.from(dose.scheduledAt, tz.local);

    debugPrint(
      'DawaCare dose reminder: doseId=${dose.id} medication=${dose.medicationName} '
      'scheduledAt=${dose.scheduledAt} localBase=$baseTime now=$now policyRepeats=${policy.maxRepeats} '
      'intervalMin=${policy.repeatIntervalMin}',
    );

    for (int i = 0; i <= policy.maxRepeats; i++) {
      final fireTime = baseTime.add(Duration(minutes: policy.repeatIntervalMin * i));
      if (fireTime.isBefore(now)) continue;

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        'تذكير الجرعات',
        channelDescription: 'إشعارات تذكير بمواعيد الأدوية',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        largeIcon: imagePath == null ? null : FilePathAndroidBitmap(imagePath),
        styleInformation: imagePath == null ? null : BigPictureStyleInformation(FilePathAndroidBitmap(imagePath), hideExpandedLargeIcon: false, contentTitle: dose.medicationName, summaryText: dose.doseAmount),
        actions: const [
          AndroidNotificationAction(_actionTaken, 'تم أخذ الدواء', showsUserInterface: false, cancelNotification: true),
          AndroidNotificationAction(_actionSnooze, 'تأجيل 10 دقائق', showsUserInterface: false, cancelNotification: true),
        ],
      );

      await _schedule(
        _notificationId(dose.id, i),
        i == 0 ? 'حان موعد الدواء 💊' : 'تذكير: الجرعة لم تُؤكَّد بعد',
        '${dose.medicationName} — ${dose.doseAmount}',
        fireTime,
        NotificationDetails(android: androidDetails),
        payload: dose.id,
      );
    }
  }

  Future<String?> _prepareMedicationImage(DoseInstance dose) async {
    try {
      final row = await _client.from('medications').select('image_url').eq('id', dose.medicationId).maybeSingle();
      final storagePath = row?['image_url'] as String?;
      if (storagePath == null || storagePath.isEmpty) return null;
      final signedUrl = storagePath.startsWith('http://') || storagePath.startsWith('https://') ? storagePath : await _client.storage.from(_imageBucket).createSignedUrl(storagePath, 3600);
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
    for (int i = 0; i <= 110; i++) {
      await _plugin.cancel(_notificationId(doseId, i));
    }
  }

  Future<void> showCaregiverAlert({required String title, required String body, String? payload}) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(android: AndroidNotificationDetails(_caregiverChannelId, 'تنبيهات العائلة', channelDescription: 'تنبيه عند تفويت أحد أفراد العائلة لجرعة دواء', importance: Importance.high, priority: Priority.high)),
      payload: payload,
    );
  }

  int _notificationId(String doseId, int index) {
    final hex = doseId.replaceAll('-', '');
    final seed = hex.length >= 8 ? int.tryParse(hex.substring(0, 8), radix: 16) ?? doseId.hashCode.abs() : doseId.hashCode.abs();
    return ((seed & 0x01ffffff) * 100 + index).clamp(0, 2147483647);
  }
}
