import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_controller.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String _selected = 'ar';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.read<LocaleController>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Image.asset('assets/icon/app_icon.png'),
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.appName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(l10n.tagline, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 52),
                  Text(l10n.chooseLanguage, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  _LanguageTile(code: 'AR', title: 'العربية', selected: _selected == 'ar', onTap: () => setState(() => _selected = 'ar')),
                  const SizedBox(height: 12),
                  _LanguageTile(code: 'EN', title: 'English', selected: _selected == 'en', onTap: () => setState(() => _selected = 'en')),
                  const SizedBox(height: 12),
                  _LanguageTile(code: 'FR', title: 'Français', selected: _selected == 'fr', onTap: () => setState(() => _selected = 'fr')),
                  const SizedBox(height: 32),
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => controller.setLanguage(_selected), child: Text(l10n.continueLabel))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.code, required this.title, required this.selected, required this.onTap});

  final String code;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.09) : scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? scheme.primary : scheme.outline.withValues(alpha: 0.25), width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              CircleAvatar(radius: 22, backgroundColor: scheme.primary.withValues(alpha: 0.10), child: Text(code, style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary))),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? scheme.primary : scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
