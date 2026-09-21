import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/localization/app_localizations.dart';
import '../core/localization/locale_controller.dart';
import '../core/widgets/loading_indicator.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/onboarding/presentation/pages/language_selection_page.dart';
import '../shared/root_shell.dart';
import 'theme/app_theme.dart';

class DawaCareApp extends StatefulWidget {
  const DawaCareApp({super.key});

  @override
  State<DawaCareApp> createState() => _DawaCareAppState();
}

class _DawaCareAppState extends State<DawaCareApp> {
  static const _pendingEmailConfirmationKey =
      'dawacare_pending_email_confirmation';
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((state) async {
      if (state.event != AuthChangeEvent.signedIn || state.session == null) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_pendingEmailConfirmationKey) != true) return;
      await prefs.remove(_pendingEmailConfirmationKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _messengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('تم تأكيد البريد الإلكتروني بنجاح.'),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lc = context.watch<LocaleController>();
    final locale = Locale(lc.languageCode ?? 'ar');

    return MaterialApp(
      title: 'DawaCare',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final direction =
            Localizations.localeOf(context).languageCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr;
        return Directionality(
          textDirection: direction,
          child: child!,
        );
      },
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>();
    if (!locale.isLoaded) {
      return const Scaffold(body: LoadingIndicator());
    }
    if (locale.languageCode == null) {
      return const LanguageSelectionPage();
    }

    final auth = context.watch<AuthProvider>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: LoadingIndicator());
      case AuthStatus.signedOut:
        return const LoginPage();
      case AuthStatus.signedIn:
        if (auth.profile == null) {
          return const Scaffold(body: LoadingIndicator());
        }
        if (locale.languageCode != auth.profile!.language) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context
                .read<LocaleController>()
                .syncFromProfile(auth.profile!.language);
          });
        }
        return const RootShell();
    }
  }
}
