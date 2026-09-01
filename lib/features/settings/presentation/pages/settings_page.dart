import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../../models/reminder_policy.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reminders/data/reminder_policy_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _policyRepo = ReminderPolicyRepository();
  ReminderPolicy? _policy;
  bool _loadingPolicy = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadingPolicy) {
  _loadPolicy();
}
  }

  Future<void> _loadPolicy() async {
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId == null) return;
    final policy = await _policyRepo.fetch(userId);
    if (mounted) {
  setState(() {
    _policy = policy;
    _loadingPolicy = false;
  });
}
  }

  Future<void> _savePolicy(ReminderPolicy policy) async {
    setState(() => _policy = policy);
    await _policyRepo.save(policy);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (profile != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        profile.fullName.isNotEmpty ? profile.fullName.substring(0, 1) : '؟',
                        style: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.fullName.isEmpty ? 'مستخدم' : profile.fullName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          Text(auth.profile != null ? (auth.profile!.phone ?? '') : ''),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code_rounded),
                title: const Text('رمز العائلة الخاص بك'),
                subtitle: Text('شاركه مع أفراد عائلتك ليتابعوا أدويتك'),
                trailing: TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: profile.familyCode));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرمز')));
                  },
                  child: Text(profile.familyCode, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إعدادات التذكير', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('يمكنك ضبط عدد مرات التذكير والفترة قبل تنبيه العائلة.',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  if (_policy != null) ..._policyControls(_policy!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_rounded),
              title: const Text('تفعيل إشعارات التذكير'),
              subtitle: const Text('مطلوب لتصلك تذكيرات موعد الدواء'),
              onTap: () async {
                final granted = await NotificationService.instance.requestPermissions();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(granted ? 'تم تفعيل الإشعارات' : 'لم يتم منح الإذن')),
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
          const SizedBox(height: 8),
          Center(
            child: Text('DawaCare v1.0.0', style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  List<Widget> _policyControls(ReminderPolicy policy) {
    return [
      _stepperRow(
        label: 'الفاصل بين التذكيرات (دقيقة)',
        value: policy.repeatIntervalMin,
        min: 5,
        max: 60,
        step: 5,
        onChanged: (v) => _savePolicy(policy.copyWith(repeatIntervalMin: v)),
      ),
      _stepperRow(
        label: 'عدد مرات إعادة التذكير',
        value: policy.maxRepeats,
        min: 0,
        max: 5,
        step: 1,
        onChanged: (v) => _savePolicy(policy.copyWith(maxRepeats: v)),
      ),
      _stepperRow(
        label: 'مهلة تنبيه العائلة (دقيقة)',
        value: policy.gracePeriodMin,
        min: 15,
        max: 240,
        step: 15,
        onChanged: (v) => _savePolicy(policy.copyWith(gracePeriodMin: v)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('تنبيه العائلة عند تفويت جرعة'),
        value: policy.caregiverEscalation,
        onChanged: (v) => _savePolicy(policy.copyWith(caregiverEscalation: v)),
      ),
    ];
  }

  Widget _stepperRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required int step,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min ? () => onChanged(value - step) : null,
          ),
          SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.center)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < max ? () => onChanged(value + step) : null,
          ),
        ],
      ),
    );
  }
}
