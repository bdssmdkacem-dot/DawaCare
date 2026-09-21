import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/ads/ad_service.dart';
import 'core/config/supabase_config.dart';
import 'core/localization/locale_controller.dart';
import 'core/notifications/routine_reminder_service.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  final localeController = LocaleController();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeController),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
    await AdService.instance.initialize();
  } catch (e) {
    debugPrint('DawaCare startup: ads initialization failed: $e');
  }

  try {
    await RoutineReminderService.instance.init();
  } catch (e) {
    debugPrint('DawaCare startup: reminder initialization failed: $e');
  }
}
