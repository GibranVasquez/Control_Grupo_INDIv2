import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AvatarIniciales extends StatelessWidget {
  const AvatarIniciales({
    super.key,
    required this.nombre,
    this.diametro = 44,
    this.background,
    this.foreground = Colors.white,
  });

  final String nombre;
  final double diametro;
  final Color? background;
  final Color foreground;

  String get _iniciales {
    final palabras = nombre.trim().split(RegExp(r'\s+'));
    if (palabras.isEmpty || palabras.first.isEmpty) return '?';
    final primera = palabras.first[0];
    final segunda = palabras.length > 1 ? palabras[1][0] : '';
    return '$primera$segunda'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diametro,
      height: diametro,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background ?? AppColors.primary.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Text(
        _iniciales,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: diametro * 0.38,
        ),
      ),
    );
  }
}
