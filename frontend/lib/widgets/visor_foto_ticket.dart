import 'package:flutter/material.dart';

import '../services/api/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

/// Abre en grande la foto de un ticket/evidencia de carga. [fotoUrl] llega
/// del backend como ruta relativa (`/uploads/tickets/<archivo>`, ver
/// backend/src/controllers/carga.controller.ts) — se resuelve contra
/// [apiBaseUrl] porque las fotos las sirve el mismo backend, no un CDN aparte.
Future<void> mostrarFotoTicket(
  BuildContext context, {
  required String? fotoUrl,
  required String etiqueta,
}) {
  if (fotoUrl == null) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sin evidencia todavía'),
        content: Text(
          '$etiqueta no tiene foto subida — puede seguir pendiente de sincronizar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  final urlCompleta = fotoUrl.startsWith('http')
      ? fotoUrl
      : '$apiBaseUrl$fotoUrl';

  return showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.cardLarge),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        etiqueta,
                        style: AppTypography.display(fontSize: 15),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(
                    urlCompleta,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Padding(
                        padding: EdgeInsets.all(60),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textTertiary,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No se pudo cargar la imagen.\n$urlCompleta',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
