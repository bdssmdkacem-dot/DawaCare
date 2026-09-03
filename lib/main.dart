import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'core/localization/locale_controller.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/caregiver/presentation/providers/caregiver_provider.dart';
import 'features/doses/presentation/providers/dose_provider.dart';
import 'features/medications/presentation/providers/medication_provider.dart';
import 'features/sync/sync_engine.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // These two SDKs are required by the application/providers during the
  // first widget build, so they must be initialized before runApp().
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(
    dawacareFirebaseMessagingBackgroundHandler,
  );

  final localeController = LocaleController();

  // Keep non-critical startup work after the first Flutter frame so the
  // branded Android splash is replaced by the app UI as quickly as possible.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeController),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DoseProvider()),
        ChangeNotifierProvider(create: (_) => MedicationProvider()),
        ChangeNotifierProvider(create: (_) => CaregiverProvider()),
      ],
      child: const DawaCareApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeServices(localeController);
  });
}

Future<void> _initializeServices(LocaleController localeController) async {
  try {
    await localeController.load();
  } catch (e) {
    debugPrint('DawaCare startup: locale initialization failed: $e');
  }

  try {
    await NotificationService.instance.init();
    await NotificationService.instance.requestPermissions();
  } catch (e) {
    debugPrint('DawaCare startup: notification initialization failed: $e');
  }

  try {
    await PushNotificationService.instance.init();
  } catch (e) {
    debugPrint('DawaCare startup: push notification initialization failed: $e');
  }

  try {
    SyncEngine.instance.start();
  } catch (e) {
    debugPrint('DawaCare startup: sync engine failed to start: $e');
  }
}
