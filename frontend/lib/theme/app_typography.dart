import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Manrope para UI, IBM Plex Mono para números y datos (placas, litros, montos).
class AppTypography {
  AppTypography._();

  static TextStyle mono({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextTheme get textTheme => TextTheme(
        // Saludo del header ("Buen día, Germán Hernández").
        headlineSmall: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800),
        // Título de pantalla móvil / título de sección web.
        titleLarge: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800),
        titleMedium: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800),
        bodyLarge: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w400),
        // Labels de campos ("NÚMERO DE EMPLEADO"), uppercase se aplica en el widget.
        labelLarge: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800),
        labelMedium: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w700),
        labelSmall: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w500),
      );
}
