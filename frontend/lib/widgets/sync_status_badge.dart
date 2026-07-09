import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

enum SyncStatus { pendiente, sincronizado }

/// Badge que acompaña cada carga/solicitud/foto capturada offline.
/// El estado depende únicamente de si el registro ya llegó al servidor
/// (`creado_offline` en false o `sincronizado_en` con fecha), nunca de si hay red en este momento.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final pendiente = status == SyncStatus.pendiente;
    final foreground = pendiente ? AppColors.syncPending : AppColors.syncSynced;
    final background = pendiente ? AppColors.syncPendingBg : AppColors.syncSyncedBg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.badge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            pendiente ? Icons.access_time_rounded : Icons.check_circle_rounded,
            size: 13,
            color: foreground,
          ),
          const SizedBox(width: 5),
          Text(
            pendiente ? 'Pendiente de sincronizar' : 'Sincronizado',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
