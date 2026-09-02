import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'core/notifications/notification_service.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/caregiver/presentation/providers/caregiver_provider.dart';
import 'features/doses/presentation/providers/dose_provider.dart';
import 'features/medications/presentation/providers/medication_provider.dart';
import 'features/sync/sync_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  SyncEngine.instance.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DoseProvider()),
        ChangeNotifierProvider(create: (_) => MedicationProvider()),
        ChangeNotifierProvider(create: (_) => CaregiverProvider()),
      ],
      child: const DawaCareApp(),
    ),
  );
}
