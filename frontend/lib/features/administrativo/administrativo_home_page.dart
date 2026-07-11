import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/session_provider.dart';
import '../../widgets/widgets.dart';
import '../reportes/resumen_financiero_page.dart';
import 'bandeja_autorizaciones_page.dart';
import 'choferes_page.dart';
import 'concentrado_cargas_page.dart';
import 'vehiculos_page.dart';

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
    AdminNavItem(icono: Icons.attach_money_rounded, etiqueta: 'Finanzas'),
    AdminNavItem(icono: Icons.local_shipping_rounded, etiqueta: 'Vehículos'),
    AdminNavItem(icono: Icons.people_rounded, etiqueta: 'Choferes'),
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
        2 => _FinanzasTab(obraId: perfil?.obraId),
        3 => const VehiculosPage(),
        _ => const ChoferesPage(),
      },
    );
  }
}

class _FinanzasTab extends ConsumerWidget {
  const _FinanzasTab({required this.obraId});

  final String? obraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obraId = this.obraId;
    if (obraId == null) {
      return const Center(
        child: Text('Tu usuario no tiene una obra asignada.'),
      );
    }

    final resumenAsync = ref.watch(resumenFinancieroSemanalProvider(obraId));
    final obraAsync = ref.watch(obraPorIdProvider(obraId));

    if (resumenAsync.isLoading || obraAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = resumenAsync.error ?? obraAsync.error;
    if (error != null) {
      return Center(child: Text('No se pudo cargar el resumen financiero: $error'));
    }

    return ResumenFinancieroPage(
      filas: resumenAsync.requireValue,
      nombreProveedor: obraAsync.requireValue.nombre,
    );
  }
}
