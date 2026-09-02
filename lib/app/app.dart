import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/notifications/push_notification_service.dart';
import '../core/widgets/loading_indicator.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/patient/presentation/pages/voice_messages_page.dart';
import '../shared/root_shell.dart';
import 'theme/app_theme.dart';

class DawaCareApp extends StatefulWidget {
  const DawaCareApp({super.key});

  @override
  State<DawaCareApp> createState() => _DawaCareAppState();
}

class _DawaCareAppState extends State<DawaCareApp> {
  StreamSubscription<String>? _voiceSubscription;
  String? _pendingVoiceMessageId;
  String? _lastOpenedVoiceMessageId;

  @override
  void initState() {
    super.initState();
    _pendingVoiceMessageId = PushNotificationService.instance.takePendingVoiceMessageId();
    _voiceSubscription = PushNotificationService.instance.voiceMessageOpened.listen((id) {
      _pendingVoiceMessageId = id;
      _tryOpenVoiceMessage();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryOpenVoiceMessage());
  }

  @override
  void dispose() {
    _voiceSubscription?.cancel();
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
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VoiceMessagesPage(initialMessageId: messageId),
      ));
    });
  }

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
      home: _AuthGate(onReady: _tryOpenVoiceMessage),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.onReady});
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
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
