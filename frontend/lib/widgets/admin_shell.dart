import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'avatar_iniciales.dart';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Text(
              'INDI Combustible',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AvatarIniciales(nombre: nombreUsuario, diametro: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nombreUsuario,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemNav extends StatelessWidget {
  const _ItemNav({required this.item, required this.activo, required this.onTap});

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
                Icon(item.icono, size: 18, color: activo ? Colors.white : Colors.white60),
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
