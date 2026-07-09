import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';

/// Pantalla que ve el chofer al abrir una solicitud ya resuelta:
/// autorizado (íntegro o ajustado a menos litros, con motivo) o rechazado.
class RespuestaAutorizacionPage extends StatelessWidget {
  const RespuestaAutorizacionPage({super.key, required this.solicitud});

  final SolicitudAutorizacion solicitud;

  @override
  Widget build(BuildContext context) {
    final autorizado = solicitud.estado == EstadoSolicitud.autorizado;
    final ajustado = autorizado &&
        solicitud.litrosAutorizados != null &&
        solicitud.litrosAutorizados != solicitud.litrosSolicitados;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: autorizado ? AppColors.successBg : AppColors.errorBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  autorizado ? Icons.check : Icons.close,
                  color: autorizado ? AppColors.success : AppColors.error,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                autorizado ? '¡Autorizado!' : 'Solicitud rechazada',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              if (solicitud.resueltoPor != null) ...[
                const SizedBox(height: 4),
                Text(
                  'por ${solicitud.resueltoPor}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.border),
                ),
                child: ajustado
                    ? Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'SOLICITASTE',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${solicitud.litrosSolicitados.toStringAsFixed(0)} L',
                                  style: AppTypography.mono(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textTertiary,
                                  ).copyWith(decoration: TextDecoration.lineThrough),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded, color: AppColors.textTertiary),
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'AUTORIZADO',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${solicitud.litrosAutorizados!.toStringAsFixed(0)} L',
                                  style: AppTypography.mono(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          const Text(
                            'SOLICITASTE',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${solicitud.litrosSolicitados.toStringAsFixed(0)} L',
                            style: AppTypography.mono(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: autorizado ? AppColors.success : AppColors.navy,
                            ),
                          ),
                        ],
                      ),
              ),
              if (solicitud.comentario != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    border: Border.all(color: AppColors.warningBorder),
                    borderRadius: BorderRadius.circular(AppRadii.miniCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MOTIVO',
                        style: TextStyle(
                          color: AppColors.warningTextStrong,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        solicitud.comentario!,
                        style: const TextStyle(color: AppColors.warningTextStrong),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (autorizado)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push(AppRoutes.comprobarCarga, extra: solicitud),
                    child: const Text('✓ Ya cargué · comprobar'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
