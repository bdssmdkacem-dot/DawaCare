import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../core/ads/ad_banner.dart';
import '../core/ads/ad_service.dart';
import '../core/localization/app_localizations.dart';
import '../features/routines/presentation/pages/routine_reminder_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  String? get _bannerAdUnitId =>
      _index == 0 ? AdService.homeBannerId : null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bannerId = _bannerAdUnitId;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          RoutineReminderPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bannerId != null)
            DawaCareBanner(
              key: ValueKey(bannerId),
              productionAdUnitId: bannerId,
            ),
          NavigationBar(
            selectedIndex: _index,
            height: 76,
            backgroundColor: Theme.of(context).colorScheme.surface,
            indicatorColor: AppColors.primary.withValues(alpha: .12),
            onDestinationSelected: (i) {
              if (i == _index) return;
              setState(() => _index = i);
              AdService.instance.showNavigationInterstitial();
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.event_note_outlined),
                selectedIcon: const Icon(Icons.event_note_rounded),
                label: l10n.reminders,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: l10n.settings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
