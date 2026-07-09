import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Indicador de carga reutilizable para simular la espera de datos (no hay backend real aún).
class CargaSimulada extends StatelessWidget {
  const CargaSimulada({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
      ),
    );
  }
}

/// Envuelve [builder] con un retraso simulado de [duracion] antes de mostrarlo, mostrando
/// [CargaSimulada] mientras tanto. Útil para reflejar el estado de carga de pantallas
/// que hoy leen datos mock síncronos pero luego vendrán de un repositorio real.
class ConCargaSimulada extends StatelessWidget {
  const ConCargaSimulada({
    super.key,
    required this.builder,
    this.duracion = const Duration(milliseconds: 400),
  });

  final WidgetBuilder builder;
  final Duration duracion;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: Future.delayed(duracion),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CargaSimulada();
        }
        return builder(context);
      },
    );
  }
}
