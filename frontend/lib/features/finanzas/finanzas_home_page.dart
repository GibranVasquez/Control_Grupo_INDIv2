import 'package:flutter/material.dart';

import '../../dev/datos_demo.dart';
import '../../widgets/widgets.dart';
import '../reportes/resumen_financiero_page.dart';
import 'cierre_semanal_page.dart';
import 'precios_combustible_page.dart';
import 'usuarios_page.dart';

class FinanzasHomePage extends StatefulWidget {
  const FinanzasHomePage({super.key});

  @override
  State<FinanzasHomePage> createState() => _FinanzasHomePageState();
}

class _FinanzasHomePageState extends State<FinanzasHomePage> {
  int _seleccion = 0;

  static const _items = [
    AdminNavItem(icono: Icons.bar_chart_rounded, etiqueta: 'Reportes'),
    AdminNavItem(icono: Icons.event_available_rounded, etiqueta: 'Cierre semanal'),
    AdminNavItem(icono: Icons.local_gas_station_rounded, etiqueta: 'Precios'),
    AdminNavItem(icono: Icons.people_rounded, etiqueta: 'Usuarios'),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      items: _items,
      indiceSeleccionado: _seleccion,
      onSeleccionar: (i) => setState(() => _seleccion = i),
      nombreUsuario: 'Lic. Fernando Aguilar',
      child: switch (_seleccion) {
        0 => ResumenFinancieroPage(
            filas: DatosDemo.resumenFinancieroObra,
            nombreProveedor: 'Todas las obras',
            consolidado: true,
          ),
        1 => const CierreSemanalPage(),
        2 => const PreciosCombustiblePage(),
        _ => const UsuariosPage(),
      },
    );
  }
}
