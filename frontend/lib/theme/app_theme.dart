import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        error: AppColors.error,
        surface: AppColors.surface,
      ),
      textTheme: textTheme,
      dividerColor: AppColors.divider,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled))
              return AppColors.borderStrong;
            if (states.contains(WidgetState.pressed))
              return AppColors.primaryDark;
            return AppColors.primary;
          }),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          overlayColor: const WidgetStatePropertyAll(Colors.white24),
          // Elevación sutil que crece al pasar el cursor — sensación "física"
          // sin caer en la sombra dura por defecto de Material.
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return 0;
            if (states.contains(WidgetState.hovered)) return 6;
            return 2;
          }),
          shadowColor: const WidgetStatePropertyAll(Color(0x550165F9)),
          minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.titleMedium?.copyWith(
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card - 1),
            ),
          ),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed))
              return AppColors.secondaryDark;
            return AppColors.navy;
          }),
          overlayColor: const WidgetStatePropertyAll(AppColors.secondaryBg),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return const BorderSide(color: AppColors.secondary, width: 1.5);
            }
            return const BorderSide(color: AppColors.borderStrong, width: 1.5);
          }),
          minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.titleMedium?.copyWith(color: AppColors.navy),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card - 1),
            ),
          ),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(AppColors.primary),
          overlayColor: const WidgetStatePropertyAll(AppColors.infoBg),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.miniCard),
            ),
          ),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(
            color: AppColors.borderInput,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(
            color: AppColors.borderInput,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
