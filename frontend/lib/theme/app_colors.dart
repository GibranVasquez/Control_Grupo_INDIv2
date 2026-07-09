import 'package:flutter/material.dart';

/// Design tokens de color — fuente: design/README.md (handoff INDI Combustible).
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0165F9);
  static const Color primaryDark = Color(0xFF0148C0);

  static const Color navy = Color(0xFF0A1E44);
  static const Color ink = Color(0xFF0E1526);

  static const Color textPrimary = navy;
  static const Color textSecondary = Color(0xFF5A6B86);
  static const Color textSecondaryAlt = Color(0xFF64708A);
  static const Color textTertiary = Color(0xFF9AA4B4);
  static const Color textPlaceholder = Color(0xFF8A94A6);

  static const Color background = Color(0xFFE7ECF4);
  static const Color surfaceLight = Color(0xFFF4F6FA);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color borderStrong = Color(0xFFDCE3EE);
  static const Color border = Color(0xFFE4E9F2);
  static const Color borderInput = Color(0xFFE2E7F0);
  static const Color borderSubtle = Color(0xFFEEF1F6);

  static const Color success = Color(0xFF0E9F6E);
  static const Color successBg = Color(0xFFE7F6F0);

  static const Color warning = Color(0xFFC77C0A);
  static const Color warningBg = Color(0xFFFEF3E0);
  static const Color warningBorder = Color(0xFFF5D9A8);
  static const Color warningTextStrong = Color(0xFF7A5410);

  static const Color error = Color(0xFFE11D48);
  static const Color errorBg = Color(0xFFFEECF0);
  static const Color errorBorder = Color(0xFFF5B8C6);

  static const Color info = Color(0xFF0165F9);
  static const Color infoBg = Color(0xFFEAF1FF);

  static const Color statusYellowText = Color(0xFFA16207);
  static const Color statusYellowBg = Color(0xFFFEF9C3);

  // Estados de SyncStatusBadge (offline-first).
  static const Color syncPending = warning;
  static const Color syncPendingBg = warningBg;
  static const Color syncSynced = success;
  static const Color syncSyncedBg = successBg;

  static const Color divider = borderSubtle;
}

class AppGradients {
  AppGradients._();

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.primary, Color(0xFF0A3FB0)],
  );

  static const LinearGradient budgetCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, Color(0xFF0A3FB0)],
  );
}
