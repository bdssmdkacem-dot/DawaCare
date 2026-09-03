import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/localization/app_localizations.dart';
import '../core/localization/locale_controller.dart';
import '../core/notifications/push_notification_service.dart';
import '../core/widgets/loading_indicator.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/caregiver/presentation/pages/caregiver_home_page.dart';
import '../features/onboarding/presentation/pages/language_selection_page.dart';
import '../features/patient/presentation/pages/voice_messages_page.dart';
import '../shared/root_shell.dart';
import 'theme/app_theme.dart';

class DawaCareApp extends StatefulWidget {
  const DawaCareApp({super.key});
  @override
  State<DawaCareApp> createState() => _DawaCareAppState();
}

class _DawaCareAppState extends State<DawaCareApp> {
  static const _pendingEmailConfirmationKey = 'dawacare_pending_email_confirmation';
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<String>? _voiceSubscription;
  StreamSubscription<String>? _notificationSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  String? _pendingVoiceMessageId;
  String? _pendingCaregiverAlertId;
  String? _lastOpenedVoiceMessageId;
  String? _lastOpenedCaregiverAlertId;

  @override
  void initState() {
    super.initState();
    _pendingVoiceMessageId = PushNotificationService.instance.takePendingVoiceMessageId();
    _pendingCaregiverAlertId = PushNotificationService.instance.takePendingCaregiverAlertId();
    _voiceSubscription = PushNotificationService.instance.voiceMessageOpened.listen((id) {
      _pendingVoiceMessageId = id;
      _tryOpenVoiceMessage();
    });
    _notificationSubscription = PushNotificationService.instance.notificationOpened.listen((id) {
      _pendingCaregiverAlertId = id;
      _tryOpenCaregiverAlert();
    });
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((state) async {
      if (state.event != AuthChangeEvent.signedIn || state.session == null) return;
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getBool(_pendingEmailConfirmationKey) ?? false;
      if (!pending) return;
      await prefs.remove(_pendingEmailConfirmationKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('تم تأكيد البريد الإلكتروني بنجاح وإضافة حسابك في دواء كير.')),
        );
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryOpenVoiceMessage();
      _tryOpenCaregiverAlert();
    });
  }

  @override
  void dispose() {
    _voiceSubscription?.cancel();
    _notificationSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _tryOpenVoiceMessage() {
    if (!mounted || _pendingVoiceMessageId == null) return;
    final auth = context.read<AuthProvider>();
    if (auth.status != AuthStatus.signedIn || auth.profile == null) return;
    final messageId = _pendingVoiceMessageId!;
    if (_lastOpenedVoiceMessageId == messageId) {
      _pendingVoiceMessageId = null;
      return;
    }
    _lastOpenedVoiceMessageId = messageId;
    _pendingVoiceMessageId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => VoiceMessagesPage(initialMessageId: messageId)));
    });
  }

  void _tryOpenCaregiverAlert() {
    if (!mounted || _pendingCaregiverAlertId == null) return;
    final auth = context.read<AuthProvider>();
    if (auth.status != AuthStatus.signedIn || auth.profile == null) return;
    final alertId = _pendingCaregiverAlertId!;
    if (_lastOpenedCaregiverAlertId == alertId) {
      _pendingCaregiverAlertId = null;
      return;
    }
    _lastOpenedCaregiverAlertId = alertId;
    _pendingCaregiverAlertId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CaregiverHomePage(initialAlertId: alertId)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final localeController = context.watch<LocaleController>();
    final locale = Locale(localeController.languageCode ?? 'ar');
    return MaterialApp(
      title: 'DawaCare',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      builder: (context, child) {
        final direction = Localizations.localeOf(context).languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
        return Directionality(textDirection: direction, child: child!);
      },
      home: _AuthGate(onReady: () {
        _tryOpenVoiceMessage();
        _tryOpenCaregiverAlert();
      }),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.onReady});
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>();
    if (!locale.isLoaded) return const Scaffold(body: LoadingIndicator());
    if (locale.languageCode == null) return const LanguageSelectionPage();
    final auth = context.watch<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => onReady());
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: LoadingIndicator());
      case AuthStatus.signedOut:
        return const LoginPage();
      case AuthStatus.signedIn:
        if (auth.profile == null) return const Scaffold(body: LoadingIndicator());
        return const RootShell();
    }
  }
}
