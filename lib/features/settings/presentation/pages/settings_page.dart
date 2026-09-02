import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final localeController = context.watch<LocaleController>();
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          Card(child: ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l.language),
            subtitle: Text(switch (localeController.locale?.languageCode) { 'en' => l.english, 'fr' => l.french, _ => l.arabic }),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseLanguage(context),
          )),
          const SizedBox(height: 12),
          Card(child: ListTile(
            leading: const Icon(Icons.notifications_active_rounded),
            title: Text(l.enableReminderNotifications),
            subtitle: Text(l.reminderNotificationsRequired),
            onTap: () async {
              await NotificationService.instance.requestPermissions();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.notificationPermissionRequested)));
            },
          )),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<AuthProvider>().signOut(),
            icon: const Icon(Icons.logout_rounded), label: Text(l.logout),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseLanguage(BuildContext context) async {
    final controller = context.read<LocaleController>();
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: const Text('العربية'), onTap: () => Navigator.pop(ctx, 'ar')),
        ListTile(title: const Text('English'), onTap: () => Navigator.pop(ctx, 'en')),
        ListTile(title: const Text('Français'), onTap: () => Navigator.pop(ctx, 'fr')),
        const SizedBox(height: 8),
      ])),
    );
    if (selected != null) await controller.setLanguage(Locale(selected));
  }
}
