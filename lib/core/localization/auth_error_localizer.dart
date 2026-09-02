import 'package:flutter/material.dart';

import 'app_localizations.dart';

String localizeAuthError(BuildContext context, String? message) {
  final l = AppLocalizations.of(context);
  if (message == null || message.trim().isEmpty) return l.unexpectedError;

  final value = message.trim().toLowerCase();
  final isAr = l.locale.languageCode == 'ar';
  final isFr = l.locale.languageCode == 'fr';

  if (value.contains('invalid login credentials')) {
    if (isAr) return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    if (isFr) return 'E-mail ou mot de passe incorrect';
    return 'Invalid email or password';
  }
  if (value.contains('email not confirmed')) {
    if (isAr) return 'يرجى تأكيد بريدك الإلكتروني أولًا';
    if (isFr) return 'Veuillez d’abord confirmer votre adresse e-mail';
    return 'Please confirm your email address first';
  }
  if (value.contains('user already registered') || value.contains('already registered')) {
    if (isAr) return 'هذا البريد الإلكتروني مسجل بالفعل';
    if (isFr) return 'Cette adresse e-mail est déjà enregistrée';
    return 'This email address is already registered';
  }
  if (value.contains('password should be at least') || value.contains('password must be at least')) {
    return l.passwordMin;
  }
  if (value.contains('rate limit')) {
    if (isAr) return 'محاولات كثيرة. حاول مرة أخرى بعد قليل';
    if (isFr) return 'Trop de tentatives. Réessayez dans quelques instants';
    return 'Too many attempts. Please try again shortly';
  }
  if (message == 'حدث خطأ غير متوقع. حاول مرة أخرى.') return l.unexpectedError;

  // Preserve useful backend messages when no safe translation is known.
  return message;
}
