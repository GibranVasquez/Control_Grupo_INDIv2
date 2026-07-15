import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/session_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../finanzas/cierre_semanal_page.dart';
import '../finanzas/precios_combustible_page.dart';
import '../finanzas/usuarios_page.dart';
import '../reportes/resumen_financiero_page.dart';
import 'bandeja_autorizaciones_page.dart';
import 'choferes_page.dart';
import 'concentrado_cargas_page.dart';
import 'vehiculos_page.dart';

/// Home único de administrador: fusiona lo que antes eran las pantallas
/// separadas de "administrativo" (Autorizaciones/Concentrado/Vehículos/
/// Choferes, restringido a su propia obra) y "finanzas" (Reportes/Cierre
/// semanal/Precios/Usuarios, todas las obras) — ahora un solo rol
/// `administrativo` sin restricción de obra (ver accesoObra.ts).
class AdministrativoHomePage extends ConsumerStatefulWidget {
  const AdministrativoHomePage({super.key});

  @override
  ConsumerState<AdministrativoHomePage> createState() => _AdministrativoHomePageState();
}

class _AdministrativoHomePageState extends ConsumerState<AdministrativoHomePage> {
  int _seleccion = 0;

  static const _items = [
    AdminNavItem(icono: Icons.notifications_rounded, etiqueta: 'Autorizaciones'),
    AdminNavItem(icono: Icons.assignment_rounded, etiqueta: 'Concentrado'),
    AdminNavItem(icono: Icons.bar_chart_rounded, etiqueta: 'Reportes'),
    AdminNavItem(icono: Icons.event_available_rounded, etiqueta: 'Cierre semanal'),
    AdminNavItem(icono: Icons.local_gas_station_rounded, etiqueta: 'Precios'),
    AdminNavItem(icono: Icons.local_shipping_rounded, etiqueta: 'Vehículos'),
    AdminNavItem(icono: Icons.people_rounded, etiqueta: 'Choferes'),
    AdminNavItem(icono: Icons.manage_accounts_rounded, etiqueta: 'Usuarios'),
  ];

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(sesionProvider);
    return AdminShell(
      items: _items,
      indiceSeleccionado: _seleccion,
      onSeleccionar: (i) => setState(() => _seleccion = i),
      nombreUsuario: perfil?.nombreCompleto ?? '',
      child: switch (_seleccion) {
        0 => const BandejaAutorizacionesPage(),
        1 => const ConcentradoCargasPage(),
        2 => const _ReportesConsolidadoTab(),
        3 => const CierreSemanalPage(),
        4 => const PreciosCombustiblePage(),
        5 => const VehiculosPage(),
        6 => const ChoferesPage(),
        _ => const UsuariosPage(),
      },
    );
  }
}

/// Resumen financiero de todas las obras — antes exclusivo de finanzas
/// (`_ReportesConsolidadoTab` en finanzas_home_page.dart, eliminado).
class _ReportesConsolidadoTab extends ConsumerWidget {
  const _ReportesConsolidadoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumenAsync = ref.watch(resumenFinancieroConsolidadoProvider);

    return resumenAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'No se pudo cargar el resumen financiero: $error',
          style: const TextStyle(color: AppColors.error),
        ),
      ),
      data: (filas) => ResumenFinancieroPage(
        filas: filas,
        nombreProveedor: 'Todas las obras',
        consolidado: true,
      ),
    );
  }
}
