import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_rounded),
              title: const Text('تفعيل إشعارات التذكير'),
              subtitle: const Text('مطلوب لتصلك تذكيرات موعد الدواء'),
              onTap: () async {
                await NotificationService.instance.requestPermissions();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم طلب أذونات الإشعارات')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<AuthProvider>().signOut(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
