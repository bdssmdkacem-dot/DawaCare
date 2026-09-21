import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  String tr(String ar, String en, String fr) {
    return switch (locale.languageCode) {
      'en' => en,
      'fr' => fr,
      _ => ar,
    };
  }

  String get appName => tr('مخطط يومي', 'Daily Planner', 'Agenda quotidien');
  String get tagline => tr(
        'نظّم يومك وتذكيراتك بسهولة',
        'Organize your day and reminders',
        'Organisez votre journée et vos rappels',
      );
  String get chooseLanguage =>
      tr('اختر لغتك', 'Choose your language', 'Choisissez votre langue');
  String get continueLabel => tr('متابعة', 'Continue', 'Continuer');
  String get login => tr('تسجيل الدخول', 'Sign in', 'Se connecter');
  String get register => tr('إنشاء حساب', 'Create an account', 'Créer un compte');
  String get email => tr('البريد الإلكتروني', 'Email', 'E-mail');
  String get password => tr('كلمة المرور', 'Password', 'Mot de passe');
  String get fullName => tr('الاسم الكامل', 'Full name', 'Nom complet');
  String get newAccountQuestion => tr(
        'ماعندكش حساب؟ سجل الآن',
        'Don’t have an account? Create one',
        'Vous n’avez pas de compte ? Créez-en un',
      );
  String get invalidEmail => tr(
        'أدخل بريدًا إلكترونيًا صحيحًا',
        'Enter a valid email address',
        'Saisissez une adresse e-mail valide',
      );
  String get passwordMin => tr(
        '6 أحرف على الأقل',
        'At least 6 characters',
        '6 caractères minimum',
      );
  String get enterName =>
      tr('أدخل اسمك', 'Enter your name', 'Saisissez votre nom');
  String get accountCreated => tr(
        'تم إنشاء الحساب بنجاح!',
        'Account created successfully!',
        'Compte créé avec succès !',
      );
  String get unexpectedError => tr(
        'حدث خطأ غير متوقع. حاول مرة أخرى.',
        'Something went wrong. Please try again.',
        'Une erreur est survenue. Réessayez.',
      );
  String get reminders => tr('تذكيراتي', 'My reminders', 'Mes rappels');
  String get settings => tr('الإعدادات', 'Settings', 'Paramètres');
  String get enableReminderNotifications => tr(
        'تفعيل إشعارات التذكير',
        'Enable reminder notifications',
        'Activer les notifications de rappel',
      );
  String get reminderNotificationsRequired => tr(
        'مطلوب لتصلك التذكيرات المجدولة',
        'Required for scheduled reminders',
        'Nécessaire pour recevoir les rappels programmés',
      );
  String get notificationPermissionRequested => tr(
        'تم طلب أذونات الإشعارات',
        'Notification permission requested',
        'Autorisation des notifications demandée',
      );
  String get logout => tr('تسجيل الخروج', 'Sign out', 'Se déconnecter');
  String get language => tr('اللغة', 'Language', 'Langue');
  String get arabic => 'العربية';
  String get english => 'English';
  String get french => 'Français';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
