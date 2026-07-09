import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../dev/datos_demo.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

/// Alta/baja de usuarios de todas las obras (Fase 5) — perfiles.activo.
/// La creación de un usuario nuevo implica invitarlo en Supabase Auth, por eso aquí
/// solo se activa/desactiva; dar de alta uno nuevo queda pendiente de que backend
/// defina el flujo (invitación por correo vs. alta directa).
class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  late List<Perfil> _usuarios = List.of(DatosDemo.perfilesTodos);
  RolUsuario? _filtroRol;

  String _nombreObra(String? obraId) {
    if (obraId == null) return '—';
    return DatosDemo.obras.firstWhere((o) => o.id == obraId).nombre;
  }

  String _etiquetaRol(RolUsuario rol) => switch (rol) {
        RolUsuario.chofer => 'Chofer',
        RolUsuario.administrativo => 'Administrativo',
        RolUsuario.finanzas => 'Finanzas',
      };

  void _alternarActivo(Perfil perfil) {
    // TODO: PerfilRepository.actualizarActivo(perfil.id, !perfil.activo).
    setState(() {
      _usuarios = [
        for (final u in _usuarios)
          if (u.id == perfil.id)
            Perfil(
              id: u.id,
              authUserId: u.authUserId,
              numeroEmpleado: u.numeroEmpleado,
              nombreCompleto: u.nombreCompleto,
              rol: u.rol,
              obraId: u.obraId,
              activo: !u.activo,
            )
          else
            u,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final filas = _filtroRol == null
        ? _usuarios
        : _usuarios.where((u) => u.rol == _filtroRol).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Usuarios',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.navy)),
              ),
              DropdownButton<RolUsuario?>(
                value: _filtroRol,
                hint: const Text('Todos los roles'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los roles')),
                  for (final rol in RolUsuario.values)
                    DropdownMenuItem(value: rol, child: Text(_etiquetaRol(rol))),
                ],
                onChanged: (rol) => setState(() => _filtroRol = rol),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: DataTable2(
                headingRowColor: const WidgetStatePropertyAll(AppColors.navy),
                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                dataRowHeight: 52,
                columnSpacing: 20,
                columns: const [
                  DataColumn2(label: Text('NOMBRE'), size: ColumnSize.L),
                  DataColumn2(label: Text('Nº EMPLEADO'), size: ColumnSize.M),
                  DataColumn2(label: Text('ROL'), size: ColumnSize.M),
                  DataColumn2(label: Text('OBRA'), size: ColumnSize.M),
                  DataColumn2(label: Text('ACTIVO'), size: ColumnSize.S),
                ],
                rows: [
                  for (final usuario in filas)
                    DataRow2(cells: [
                      DataCell(Text(usuario.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataCell(Text(usuario.numeroEmpleado)),
                      DataCell(_BadgeRol(rol: usuario.rol, etiqueta: _etiquetaRol(usuario.rol))),
                      DataCell(Text(_nombreObra(usuario.obraId))),
                      DataCell(Switch(
                        value: usuario.activo,
                        onChanged: (_) => _alternarActivo(usuario),
                      )),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeRol extends StatelessWidget {
  const _BadgeRol({required this.rol, required this.etiqueta});

  final RolUsuario rol;
  final String etiqueta;

  Color get _color => switch (rol) {
        RolUsuario.chofer => AppColors.info,
        RolUsuario.administrativo => AppColors.warning,
        RolUsuario.finanzas => AppColors.success,
      };

  Color get _fondo => switch (rol) {
        RolUsuario.chofer => AppColors.infoBg,
        RolUsuario.administrativo => AppColors.warningBg,
        RolUsuario.finanzas => AppColors.successBg,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: _fondo, borderRadius: BorderRadius.circular(AppRadii.badge)),
      child: Text(etiqueta, style: TextStyle(color: _color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
