import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('ar'), Locale('en'), Locale('fr')];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) => Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  bool get isArabic => locale.languageCode == 'ar';

  String get appName => switch (locale.languageCode) {
        'en' => 'DawaCare',
        'fr' => 'DawaCare',
        _ => 'دواء كير',
      };

  String get tagline => switch (locale.languageCode) {
        'en' => 'Never miss your medicine',
        'fr' => 'N’oubliez plus vos médicaments',
        _ => 'ما تنساش دوا حتى مرة',
      };

  String get chooseLanguage => switch (locale.languageCode) {
        'en' => 'Choose your language',
        'fr' => 'Choisissez votre langue',
        _ => 'اختر لغتك',
      };

  String get continueLabel => switch (locale.languageCode) {
        'en' => 'Continue',
        'fr' => 'Continuer',
        _ => 'متابعة',
      };

  String get login => switch (locale.languageCode) {
        'en' => 'Sign in',
        'fr' => 'Se connecter',
        _ => 'تسجيل الدخول',
      };

  String get register => switch (locale.languageCode) {
        'en' => 'Create an account',
        'fr' => 'Créer un compte',
        _ => 'إنشاء حساب',
      };

  String get email => switch (locale.languageCode) {
        'en' => 'Email',
        'fr' => 'E-mail',
        _ => 'البريد الإلكتروني',
      };

  String get password => switch (locale.languageCode) {
        'en' => 'Password',
        'fr' => 'Mot de passe',
        _ => 'كلمة المرور',
      };

  String get fullName => switch (locale.languageCode) {
        'en' => 'Full name',
        'fr' => 'Nom complet',
        _ => 'الاسم الكامل',
      };

  String get newAccountQuestion => switch (locale.languageCode) {
        'en' => 'Don’t have an account? Create one',
        'fr' => 'Vous n’avez pas de compte ? Créez-en un',
        _ => 'ماعندكش حساب؟ سجل الآن',
      };

  String get today => switch (locale.languageCode) {
        'en' => 'Today',
        'fr' => 'Aujourd’hui',
        _ => 'اليوم',
      };

  String get medicines => switch (locale.languageCode) {
        'en' => 'My medicines',
        'fr' => 'Mes médicaments',
        _ => 'أدويتي',
      };

  String get family => switch (locale.languageCode) {
        'en' => 'Family',
        'fr' => 'Famille',
        _ => 'العائلة',
      };

  String get settings => switch (locale.languageCode) {
        'en' => 'Settings',
        'fr' => 'Paramètres',
        _ => 'الإعدادات',
      };

  String get invalidEmail => switch (locale.languageCode) {
        'en' => 'Enter a valid email address',
        'fr' => 'Saisissez une adresse e-mail valide',
        _ => 'أدخل بريدًا إلكترونيًا صحيحًا',
      };

  String get passwordMin => switch (locale.languageCode) {
        'en' => 'At least 6 characters',
        'fr' => '6 caractères minimum',
        _ => '6 أحرف على الأقل',
      };

  String get enterName => switch (locale.languageCode) {
        'en' => 'Enter your name',
        'fr' => 'Saisissez votre nom',
        _ => 'أدخل اسمك',
      };

  String get accountCreated => switch (locale.languageCode) {
        'en' => 'Account created successfully!',
        'fr' => 'Compte créé avec succès !',
        _ => 'تم إنشاء الحساب بنجاح!',
      };

  String get unexpectedError => switch (locale.languageCode) {
        'en' => 'Something went wrong. Please try again.',
        'fr' => 'Une erreur est survenue. Réessayez.',
        _ => 'حدث خطأ غير متوقع. حاول مرة أخرى.',
      };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
