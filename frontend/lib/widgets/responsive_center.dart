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
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
