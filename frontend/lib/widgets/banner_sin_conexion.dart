import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_colors.dart';

/// Banner persistente en la parte superior de la app cuando PowerSync pierde
/// la conexión con su servicio de sync. Se muestra encima de cualquier
/// pantalla (ver MainApp en main.dart) sin que cada feature tenga que
/// preocuparse por esto.
///
/// No se muestra mientras el estado de conectividad es desconocido (primer
/// frame, antes de que statusStream emita) para no parpadear "sin conexión"
/// en cada arranque de la app.
class BannerSinConexion extends ConsumerWidget {
  const BannerSinConexion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conectividad = ref.watch(conectividadProvider);
    final sinConexion = conectividad.maybeWhen(
      data: (conectado) => !conectado,
      orElse: () => false,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: sinConexion
          ? Container(
              width: double.infinity,
              color: AppColors.error,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 8,
                left: 16,
                right: 16,
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sin conexión. Los cambios se guardan y se sincronizan solos al volver la señal.',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
