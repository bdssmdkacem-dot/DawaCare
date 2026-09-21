import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class RoutineReminder {
  const RoutineReminder({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
  });

  final String id;
  final String title;
  final int hour;
  final int minute;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'hour': hour,
        'minute': minute,
      };

  factory RoutineReminder.fromJson(Map<String, dynamic> json) => RoutineReminder(
        id: json['id'] as String,
        title: json['title'] as String,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      );
}

class RoutineReminderService {
  RoutineReminderService._();
  static final instance = RoutineReminderService._();

  static const _storageKey = 'dawacare_routine_reminders';
  static const _channelId = 'routine_reminders';
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Casablanca'));
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Daily reminders',
        description: 'Personal reminders and routines',
        importance: Importance.high,
        enableVibration: true,
      ),
    );
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  Future<List<RoutineReminder>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) => RoutineReminder.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<RoutineReminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(reminders.map((e) => e.toJson()).toList()),
    );
    await _reschedule(reminders);
  }

  Future<void> _reschedule(List<RoutineReminder> reminders) async {
    await init();
    await _plugin.cancelAll();
    for (final reminder in reminders) {
      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        reminder.hour,
        reminder.minute,
      );
      if (!next.isAfter(now)) {
        next = next.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        _id(reminder.id),
        reminder.title,
        'Your scheduled reminder',
        next,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Daily reminders',
            channelDescription: 'Personal reminders and routines',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  int _id(String value) {
    var hash = 0;
    for (final code in value.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
