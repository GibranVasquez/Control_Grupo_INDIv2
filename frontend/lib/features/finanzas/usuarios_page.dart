import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/widgets.dart';

/// Edición y activar/desactivar de usuarios. El alta de choferes ya no ocurre
/// aquí: el chofer se autoregistra (`POST /auth/registro-chofer`, ver
/// registro_chofer_page.dart) y administrativo solo completa o corrige sus
/// datos (obra, vehículo, correo, edad) desde esta pantalla. administrativo
/// ya tiene su propio usuario y contraseña (ver
/// backend/src/services/perfil.service.ts) y no se edita por aquí.
class UsuariosPage extends ConsumerStatefulWidget {
  const UsuariosPage({super.key});

  @override
  ConsumerState<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends ConsumerState<UsuariosPage> {
  RolUsuario? _filtroRol;

  String _etiquetaRol(RolUsuario rol) => switch (rol) {
        RolUsuario.chofer => 'Chofer',
        RolUsuario.administrativo => 'Administrativo',
      };

  Future<void> _alternarActivo(Perfil perfil) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(perfilRepositoryProvider).actualizarActivo(perfil.id, !perfil.activo);
      ref.invalidate(perfilesTodosProvider);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('No se pudo actualizar el estado del usuario.'),
        ),
      );
    }
  }

  Future<void> _editarChofer(Perfil chofer) async {
    final editado = await showDialog<bool>(
      context: context,
      builder: (_) => EditarChoferDialog(chofer: chofer),
    );
    if (editado ?? false) {
      ref.invalidate(perfilesTodosProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfilesAsync = ref.watch(perfilesTodosProvider);
    final obrasAsync = ref.watch(obrasTodasProvider);

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
            child: perfilesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('No se pudieron cargar los usuarios: $error')),
              data: (usuarios) {
                final filas = _filtroRol == null
                    ? usuarios
                    : usuarios.where((u) => u.rol == _filtroRol).toList();
                final obras = obrasAsync.value ?? const <Obra>[];

                String nombreObra(String? obraId) {
                  if (obraId == null) return '—';
                  return obras.where((o) => o.id == obraId).firstOrNull?.nombre ?? '—';
                }

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: filas.isEmpty
                      ? const EstadoVacio(
                          mensaje: 'No hay usuarios registrados.',
                          icono: Icons.people_outline_rounded,
                        )
                      : DataTable2(
                          minWidth: 700,
                          headingRowColor: const WidgetStatePropertyAll(AppColors.navy),
                          headingTextStyle:
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                          dataRowHeight: 52,
                          columnSpacing: 20,
                          columns: const [
                            DataColumn2(label: Text('NOMBRE'), size: ColumnSize.L),
                            DataColumn2(label: Text('USUARIO'), size: ColumnSize.M),
                            DataColumn2(label: Text('ROL'), size: ColumnSize.M),
                            DataColumn2(label: Text('OBRA'), size: ColumnSize.M),
                            DataColumn2(label: Text('ACTIVO'), size: ColumnSize.S),
                            DataColumn2(label: Text(''), size: ColumnSize.S),
                          ],
                          rows: [
                            for (final usuario in filas)
                              DataRow2(cells: [
                                DataCell(
                                    Text(usuario.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w700))),
                                DataCell(Text(usuario.usuario)),
                                DataCell(_BadgeRol(rol: usuario.rol, etiqueta: _etiquetaRol(usuario.rol))),
                                DataCell(Text(nombreObra(usuario.obraId))),
                                DataCell(Switch(
                                  value: usuario.activo,
                                  onChanged: (_) => _alternarActivo(usuario),
                                )),
                                DataCell(
                                  usuario.rol == RolUsuario.chofer
                                      ? IconButton(
                                          tooltip: 'Editar',
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          onPressed: () => _editarChofer(usuario),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ]),
                          ],
                        ),
                );
              },
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
      };

  Color get _fondo => switch (rol) {
        RolUsuario.chofer => AppColors.infoBg,
        RolUsuario.administrativo => AppColors.warningBg,
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
