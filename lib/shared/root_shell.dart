import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme/app_colors.dart';
import '../core/localization/app_localizations.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/caregiver/presentation/pages/caregiver_home_page.dart';
import '../features/caregiver/presentation/providers/caregiver_provider.dart';
import '../features/medications/presentation/pages/medication_list_page.dart';
import '../features/patient/presentation/pages/patient_home_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _pages = <Widget>[
    PatientHomePage(),
    MedicationListPage(),
    CaregiverHomePage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final caregiver = context.watch<CaregiverProvider>();
    final userId = context.read<AuthProvider>().profile?.id;
    final l10n = AppLocalizations.of(context);
    final unread = caregiver.unreadAlertCount + caregiver.pendingApprovalCount;

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 76,
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: AppColors.primary.withValues(alpha: .12),
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 2 && userId != null) {
            caregiver.load(userId);
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today_rounded),
            label: l10n.today,
          ),
          NavigationDestination(
            icon: const Icon(Icons.medication_outlined),
            selectedIcon: const Icon(Icons.medication_rounded),
            label: l10n.medicines,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.family_restroom_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.family_restroom_rounded),
            ),
            label: l10n.family,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
