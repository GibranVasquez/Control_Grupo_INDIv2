import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Manrope para UI, IBM Plex Mono para números y datos (placas, litros, montos),
/// Sora para titulares/marca (pantallas, encabezado de login) — un tercer
/// registro deliberadamente distinto de Manrope: geometría más angulosa, para
/// que un título se sienta "titular" y no solo texto de cuerpo en negritas.
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

  /// Titulares de marca y de pantalla — usar en el título de cada página
  /// admin/finanzas y en textos de marca (nunca en botones ni en tablas).
  static TextStyle display({
    double fontSize = 19,
    FontWeight fontWeight = FontWeight.w800,
    Color color = AppColors.navy,
  }) {
    return GoogleFonts.sora(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextTheme get textTheme => TextTheme(
    // Saludo del header ("Buen día, Germán Hernández").
    headlineSmall: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w800),
    // Título de pantalla móvil / título de sección web.
    titleLarge: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800),
    titleMedium: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800),
    bodyLarge: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w400),
    // Labels de campos ("NÚMERO DE EMPLEADO"), uppercase se aplica en el widget.
    labelLarge: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800),
    labelMedium: GoogleFonts.manrope(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
    ),
    labelSmall: GoogleFonts.manrope(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
    ),
  );
}
