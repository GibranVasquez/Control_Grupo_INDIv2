import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Pill de estado en las tarjetas de "Mis solicitudes" y en la bandeja de autorizaciones.
/// Colores tal cual el handoff: AUTORIZADO verde, EN ESPERA (pendiente) ámbar, CARGADO azul.
class EstadoSolicitudBadge extends StatelessWidget {
  const EstadoSolicitudBadge({super.key, required this.estado});

  final EstadoSolicitud estado;

  ({String etiqueta, Color texto, Color fondo}) get _estilo => switch (estado) {
        EstadoSolicitud.pendiente => (
            etiqueta: 'EN ESPERA',
            texto: AppColors.warning,
            fondo: AppColors.warningBg,
          ),
        EstadoSolicitud.autorizado => (
            etiqueta: 'AUTORIZADO',
            texto: AppColors.success,
            fondo: AppColors.successBg,
          ),
        EstadoSolicitud.rechazado => (
            etiqueta: 'RECHAZADO',
            texto: AppColors.error,
            fondo: AppColors.errorBg,
          ),
        EstadoSolicitud.cargado => (
            etiqueta: 'CARGADO',
            texto: AppColors.info,
            fondo: AppColors.infoBg,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final estilo = _estilo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: estilo.fondo,
        borderRadius: BorderRadius.circular(AppRadii.badge),
      ),
      child: Text(
        estilo.etiqueta,
        style: TextStyle(
          color: estilo.texto,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
