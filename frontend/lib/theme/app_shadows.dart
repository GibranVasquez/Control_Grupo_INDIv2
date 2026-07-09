import 'package:flutter/material.dart';

/// Sombras del diseño (design/README.md → "Sombras").
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> primaryButton = [
    BoxShadow(
      color: Color(0xA6_0165F9), // rgba(1,101,249,.65)
      blurRadius: 26,
      offset: Offset(0, 12),
      spreadRadius: -10,
    ),
  ];

  static const List<BoxShadow> mobileCard = [
    BoxShadow(
      color: Color(0x4D_0A1E44), // rgba(10,30,68,.3)
      blurRadius: 14,
      offset: Offset(0, 4),
      spreadRadius: -10,
    ),
  ];
}
