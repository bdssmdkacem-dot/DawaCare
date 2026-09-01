import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../models/dose_instance.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../doses/presentation/providers/dose_provider.dart';
import '../widgets/dose_card.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      final userId = context.read<AuthProvider>().profile?.id;
      if (userId != null) context.read<DoseProvider>().load(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final doseProvider = context.watch<DoseProvider>();
    final userId = auth.profile?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('اليوم')),
      body: RefreshIndicator(
        onRefresh: () async {
          if (userId != null) await context.read<DoseProvider>().load(userId);
        },
        child: _buildBody(doseProvider),
      ),
    );
  }

  Widget _buildBody(DoseProvider provider) {
    if (provider.isLoading && provider.all.isEmpty) return const LoadingIndicator();

    if (provider.error != null && provider.all.isEmpty) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: provider.error!,
        subtitle: 'اسحب للأسفل للمحاولة مرة أخرى',
      );
    }

    final today = provider.todayDoses;

    if (today.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'لا توجد أدوية مجدولة اليوم',
        subtitle: 'أضف دواءك الأول من تبويب "أدويتي"',
      );
    }

    final now = DateTime.now();
    final next = today.firstWhere(
      (d) => d.status == DoseStatus.pending || d.status == DoseStatus.reminderSent || d.status == DoseStatus.snoozed,
      orElse: () => today.first,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(DateTimeUtils.relativeDayLabel(now), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...today.map(
          (dose) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DoseCard(
              dose: dose,
              compact: dose.id != next.id &&
                  !(dose.status == DoseStatus.pending ||
                      dose.status == DoseStatus.reminderSent ||
                      dose.status == DoseStatus.snoozed),
              onConfirm: () => context.read<DoseProvider>().confirm(dose),
              onSnooze: () => context.read<DoseProvider>().snooze(dose),
              onSkip: () => _confirmSkip(dose),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _confirmSkip(DoseInstance dose) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تخطي هذه الجرعة؟'),
        content: Text('سيتم تسجيل ${dose.medicationName} كـ"متخطاة" لهذه المرة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تخطي')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<DoseProvider>().skip(dose);
    }
  }
}
