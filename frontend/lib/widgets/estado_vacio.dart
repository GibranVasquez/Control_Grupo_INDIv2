import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Estado vacío reutilizable — se usa cuando una lista o tabla no tiene datos que mostrar
/// (p.ej. sin solicitudes, o un periodo del segmentador sin registros).
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.mensaje,
    this.icono = Icons.inbox_rounded,
  });

  final String mensaje;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 40, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
