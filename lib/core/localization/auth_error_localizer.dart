import 'package:flutter/material.dart';

import 'app_localizations.dart';

String localizeAuthError(BuildContext context, String? message) {
  final l = AppLocalizations.of(context);
  if (message == null || message.trim().isEmpty) return l.unexpectedError;

  final value = message.trim().toLowerCase();
  final isAr = l.locale.languageCode == 'ar';
  final isFr = l.locale.languageCode == 'fr';

  if (value == 'auth_rate_limited' ||
      value.contains('rate limit') ||
      value.contains('too many requests') ||
      value.contains('too many attempts') ||
      value.contains('over_request_rate_limit') ||
      value.contains('over_email_send_rate_limit')) {
    if (isAr) return 'محاولات كثيرة أو تم تجاوز حد إرسال البريد. انتظر قليلًا ثم حاول مرة أخرى';
    if (isFr) return 'Trop de tentatives ou limite d’envoi d’e-mails atteinte. Réessayez dans quelques instants';
    return 'Too many requests or email limit reached. Please try again shortly';
  }
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
  if (message == 'حدث خطأ غير متوقع. حاول مرة أخرى.') return l.unexpectedError;

  return message;
}
