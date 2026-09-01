import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/widgets/loading_indicator.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../shared/root_shell.dart';
import 'theme/app_theme.dart';

class DawaCareApp extends StatelessWidget {
  const DawaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دواء كير',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const _AuthGate(),
    );
  }
}

/// Routes between the login flow and the main app shell based on
/// [AuthProvider.status], so every screen behind it can assume a signed-in
/// user with a loaded profile.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
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
        return const RootShell();
    }
  }
}
