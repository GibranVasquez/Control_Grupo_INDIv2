import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_colors.dart';
import 'avatar_iniciales.dart';
import 'cerrar_sesion_button.dart';

class AdminNavItem {
  const AdminNavItem({required this.icono, required this.etiqueta});

  final IconData icono;
  final String etiqueta;
}

/// Layout compartido del panel web: sidebar navy fija + contenido central.
/// Lo usan tanto administrativo (bandeja/concentrado/vehículos, filtrado por obra)
/// como finanzas (reportes consolidados, sin filtro de obra).
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.items,
    required this.indiceSeleccionado,
    required this.onSeleccionar,
    required this.nombreUsuario,
    required this.child,
  });

  final List<AdminNavItem> items;
  final int indiceSeleccionado;
  final ValueChanged<int> onSeleccionar;
  final String nombreUsuario;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.esMovil) {
      // Antes: Drawer oculto tras un ícono de hamburguesa (un toque extra y
      // menos descubrible). Una barra de navegación inferior siempre visible
      // es el patrón estándar de apps móviles para 4-5 destinos de primer
      // nivel: cambiar de sección es un solo toque y se ve de inmediato en
      // qué sección se está, sin abrir nada.
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(items[indiceSeleccionado].etiqueta),
          actions: [
            AvatarIniciales(nombre: nombreUsuario, diametro: 32),
            const SizedBox(width: 8),
            const CerrarSesionButton(color: Colors.white),
            const SizedBox(width: 4),
          ],
        ),
        body: child,
        bottomNavigationBar: _BarraInferior(
          items: items,
          indiceSeleccionado: indiceSeleccionado,
          onSeleccionar: onSeleccionar,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _Sidebar(
            items: items,
            indiceSeleccionado: indiceSeleccionado,
            onSeleccionar: onSeleccionar,
            nombreUsuario: nombreUsuario,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.indiceSeleccionado,
    required this.onSeleccionar,
    required this.nombreUsuario,
  });

  final List<AdminNavItem> items;
  final int indiceSeleccionado;
  final ValueChanged<int> onSeleccionar;
  final String nombreUsuario;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      color: AppColors.navy,
      child: _SidebarContenido(
        items: items,
        indiceSeleccionado: indiceSeleccionado,
        onSeleccionar: onSeleccionar,
        nombreUsuario: nombreUsuario,
      ),
    );
  }
}

/// Contenido de la sidebar sin ancho fijo: lo usa tanto `_Sidebar` (escritorio,
/// ancho fijo de 210) como el `Drawer` de móvil (ancho lo controla el propio Drawer).
class _SidebarContenido extends StatelessWidget {
  const _SidebarContenido({
    required this.items,
    required this.indiceSeleccionado,
    required this.onSeleccionar,
    required this.nombreUsuario,
  });

  final List<AdminNavItem> items;
  final int indiceSeleccionado;
  final ValueChanged<int> onSeleccionar;
  final String nombreUsuario;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Text(
            'INDI Combustible',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        for (var i = 0; i < items.length; i++)
          _ItemNav(
            item: items[i],
            activo: i == indiceSeleccionado,
            onTap: () => onSeleccionar(i),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              AvatarIniciales(nombre: nombreUsuario, diametro: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nombreUsuario,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: CerrarSesionButton(color: Colors.white70, conEtiqueta: true),
        ),
      ],
    );
  }
}

/// Barra de navegación inferior para móvil (ver comentario en [AdminShell]).
/// `type: fixed` explícito: con 4-5 items Flutter usaría "shifting" por
/// defecto (íconos que cambian de tamaño/color de forma menos predecible),
/// que no es lo que se busca aquí.
class _BarraInferior extends StatelessWidget {
  const _BarraInferior({
    required this.items,
    required this.indiceSeleccionado,
    required this.onSeleccionar,
  });

  final List<AdminNavItem> items;
  final int indiceSeleccionado;
  final ValueChanged<int> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: indiceSeleccionado,
      onTap: onSeleccionar,
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textTertiary,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
      unselectedLabelStyle: const TextStyle(fontSize: 11.5),
      items: [
        for (final item in items)
          BottomNavigationBarItem(icon: Icon(item.icono), label: item.etiqueta),
      ],
    );
  }
}

class _ItemNav extends StatelessWidget {
  const _ItemNav({
    required this.item,
    required this.activo,
    required this.onTap,
  });

  final AdminNavItem item;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: activo ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  item.icono,
                  size: 18,
                  color: activo ? Colors.white : Colors.white60,
                ),
                const SizedBox(width: 12),
                Text(
                  item.etiqueta,
                  style: TextStyle(
                    color: activo ? Colors.white : Colors.white60,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
