import 'package:flutter/material.dart';

/// DawaCare palette — a calm clinical teal paired with a warm amber for the
/// primary "I took it" action, so the one button that matters most on the
/// screen never blends into the background.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0D6E6E);
  static const Color primaryLight = Color(0xFF14A3A3);
  static const Color primaryDark = Color(0xFF08484A);

  static const Color accent = Color(0xFFF2A65A); // "took it" CTA
  static const Color accentDark = Color(0xFFD98A3D);

  static const Color success = Color(0xFF3FAE6B); // TAKEN
  static const Color warning = Color(0xFFF2B138); // SNOOZED / REMINDER_SENT
  static const Color danger = Color(0xFFE0574C); // MISSED
  static const Color neutral = Color(0xFF9AA5A3); // SKIPPED / CANCELLED

  static const Color backgroundLight = Color(0xFFF6FAF9);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFF16302D);
  static const Color textMutedLight = Color(0xFF5C726E);

  static const Color backgroundDark = Color(0xFF0B1F1E);
  static const Color surfaceDark = Color(0xFF12302E);
  static const Color textDark = Color(0xFFE7F3F1);
  static const Color textMutedDark = Color(0xFFA9C2BE);

  static Color statusColor(String status) {
    switch (status) {
      case 'TAKEN':
        return success;
      case 'SNOOZED':
      case 'REMINDER_SENT':
        return warning;
      case 'MISSED':
        return danger;
      case 'SKIPPED':
      case 'CANCELLED':
        return neutral;
      default:
        return primary; // PENDING
    }
  }
}
