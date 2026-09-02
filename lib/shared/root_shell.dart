import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/localization/app_localizations.dart';
import '../features/caregiver/presentation/pages/caregiver_home_page.dart';
import '../features/caregiver/presentation/providers/caregiver_provider.dart';
import '../features/medications/presentation/pages/medication_list_page.dart';
import '../features/patient/presentation/pages/patient_home_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _pages = [
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

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          if (i == 2 && userId != null) caregiver.load(userId);
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.today_rounded), label: l10n.today),
          BottomNavigationBarItem(icon: const Icon(Icons.medication_rounded), label: l10n.medicines),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: (caregiver.unreadAlertCount + caregiver.pendingApprovalCount) > 0,
              label: Text('${caregiver.unreadAlertCount + caregiver.pendingApprovalCount}'),
              child: const Icon(Icons.family_restroom_rounded),
            ),
            label: l10n.family,
          ),
          BottomNavigationBarItem(icon: const Icon(Icons.settings_rounded), label: l10n.settings),
        ],
      ),
    );
  }
}
