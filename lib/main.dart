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

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(
    dawacareFirebaseMessagingBackgroundHandler,
  );
  await PushNotificationService.instance.init();

  SyncEngine.instance.start();

  final localeController = LocaleController();
  await localeController.load();

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
}
