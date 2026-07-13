import 'package:flutter/material.dart';

/// Centra el contenido y limita su ancho en tablet/escritorio (incluye Windows/web),
/// para que las pantallas pensadas para teléfono (login, registro, flujo de chofer)
/// no se estiren de borde a borde en pantallas grandes.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 480});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // SizedBox.expand fuerza una restricción de tamaño *tight* (no laxa)
    // antes de Align: sin esto, un hijo SingleChildScrollView (a diferencia
    // de CustomScrollView, que sí tolera las restricciones laxas que da
    // Align por sí solo) puede terminar dimensionado a alto cero — el
    // contenido queda construido y es interactivo (los taps le llegan) pero
    // no se pinta nada en pantalla. Visto en solicitar_litros_page.dart y
    // comprobar_carga_page.dart.
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
