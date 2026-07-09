import 'package:flutter/material.dart';

/// Umbrales de ancho de pantalla. Referencia: Material 3 (compact/medium/expanded),
/// ajustado a los layouts de esta app (sidebar de AdminShell, formularios de auth/chofer).
class AppBreakpoints {
  AppBreakpoints._();

  /// Por debajo de esto: teléfono. AdminShell colapsa la sidebar en un Drawer.
  static const double tablet = 700;

  /// Por debajo de esto: teléfono o tablet. Formularios y tarjetas limitan su ancho máximo.
  static const double desktop = 1000;
}

enum TipoPantalla { movil, tablet, escritorio }

extension ResponsiveContext on BuildContext {
  double get anchoPantalla => MediaQuery.sizeOf(this).width;

  TipoPantalla get tipoPantalla {
    final ancho = anchoPantalla;
    if (ancho < AppBreakpoints.tablet) return TipoPantalla.movil;
    if (ancho < AppBreakpoints.desktop) return TipoPantalla.tablet;
    return TipoPantalla.escritorio;
  }

  bool get esMovil => tipoPantalla == TipoPantalla.movil;
  bool get esTablet => tipoPantalla == TipoPantalla.tablet;
  bool get esEscritorio => tipoPantalla == TipoPantalla.escritorio;
}
