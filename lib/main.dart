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

  // Supabase must be ready before the Flutter tree is created because the
  // auth gate subscribes to Supabase immediately during app startup.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  final localeController = LocaleController();

  // Render the Flutter UI immediately. Android keeps the native DawaCare
  // launch screen until Flutter draws its first frame, so no long-running
  // service initialization should block runApp().
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

  // Continue non-critical startup work after the first Flutter frame.
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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(
      dawacareFirebaseMessagingBackgroundHandler,
    );
    await PushNotificationService.instance.init();
  } catch (e) {
    debugPrint('DawaCare startup: Firebase initialization failed: $e');
  }

  try {
    SyncEngine.instance.start();
  } catch (e) {
    debugPrint('DawaCare startup: sync engine failed to start: $e');
  }
}
