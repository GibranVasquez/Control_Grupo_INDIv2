import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_typography.dart';
import '../../widgets/widgets.dart';

/// Alta y activar/desactivar de usuarios (Fase 5). Solo se puede dar de alta
/// choferes desde aquí: administrativo/finanzas ya tienen su usuario y
/// contraseña propios (ver backend/src/services/perfil.service.ts).
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
        RolUsuario.finanzas => 'Finanzas',
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

  Future<void> _nuevoChofer() async {
    final creado = await showDialog<bool>(
      context: context,
      builder: (_) => const _NuevoChoferDialog(),
    );
    if (creado ?? false) {
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
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _nuevoChofer,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Nuevo chofer'),
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
                          minWidth: 640,
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
                          ],
                          rows: [
                            for (final usuario in filas)
                              DataRow2(cells: [
                                DataCell(
                                    Text(usuario.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w700))),
                                DataCell(Text(usuario.numeroEmpleado)),
                                DataCell(_BadgeRol(rol: usuario.rol, etiqueta: _etiquetaRol(usuario.rol))),
                                DataCell(Text(nombreObra(usuario.obraId))),
                                DataCell(Switch(
                                  value: usuario.activo,
                                  onChanged: (_) => _alternarActivo(usuario),
                                )),
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

class _NuevoChoferDialog extends ConsumerStatefulWidget {
  const _NuevoChoferDialog();

  @override
  ConsumerState<_NuevoChoferDialog> createState() => _NuevoChoferDialogState();
}

class _NuevoChoferDialogState extends ConsumerState<_NuevoChoferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _numeroEmpleadoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String? _obraId;
  String? _vehiculoId;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _numeroEmpleadoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_obraId == null) {
      setState(() => _error = 'Selecciona una obra.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(perfilRepositoryProvider).crear(
            nombreCompleto: _nombreCtrl.text.trim(),
            numeroEmpleado: _numeroEmpleadoCtrl.text.trim(),
            password: _passwordCtrl.text,
            obraId: _obraId!,
            vehiculoId: _vehiculoId,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _guardando = false;
        _error = 'No se pudo crear el usuario: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasTodasProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 460,
        constraints: const BoxConstraints(maxHeight: 640),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.cardLarge),
          boxShadow: AppShadows.mobileCard,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EncabezadoDialogo(
              icono: Icons.person_add_alt_1_rounded,
              titulo: 'Nuevo chofer',
              subtitulo: 'Da de alta el acceso de un chofer con su usuario y contraseña temporal',
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Etiqueta('DATOS PERSONALES'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nombreCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre completo'),
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 24),
                      const _Etiqueta('ACCESO (LOGIN)'),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _numeroEmpleadoCtrl,
                        decoration: const InputDecoration(labelText: 'Usuario', hintText: 'antonio.ponce'),
                        style: AppTypography.mono(fontSize: 15, color: AppColors.navy),
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordCtrl,
                        decoration: const InputDecoration(labelText: 'Contraseña temporal'),
                        validator: (v) => (v?.length ?? 0) < 4 ? 'Mínimo 4 caracteres' : null,
                      ),
                      const SizedBox(height: 24),
                      const _Etiqueta('OBRA Y VEHÍCULO'),
                      const SizedBox(height: 12),
                      obrasAsync.when(
                        data: (obras) => DropdownButtonFormField<String>(
                          initialValue: _obraId,
                          decoration: const InputDecoration(labelText: 'Obra donde trabaja'),
                          items: obras.map((o) => DropdownMenuItem(value: o.id, child: Text(o.nombre))).toList(),
                          onChanged: (v) => setState(() {
                            _obraId = v;
                            _vehiculoId = null;
                          }),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('No se pudo cargar el catálogo de obras: $e'),
                      ),
                      if (_obraId != null) ...[
                        const SizedBox(height: 14),
                        Consumer(
                          builder: (context, ref, _) {
                            final vehiculosAsync = ref.watch(vehiculosPorObraProvider(_obraId!));
                            return vehiculosAsync.when(
                              data: (vehiculos) => DropdownButtonFormField<String?>(
                                initialValue: _vehiculoId,
                                decoration: const InputDecoration(labelText: 'Vehículo asignado (opcional)'),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Sin asignar por ahora')),
                                  for (final vehiculo in vehiculos)
                                    DropdownMenuItem(
                                        value: vehiculo.id, child: Text('${vehiculo.descripcion} · ${vehiculo.placa}')),
                                ],
                                onChanged: (v) => setState(() => _vehiculoId = v),
                              ),
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text('No se pudo cargar el catálogo de vehículos: $e'),
                            );
                          },
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorBg,
                            borderRadius: BorderRadius.circular(AppRadii.miniCard),
                            border: Border.all(color: AppColors.errorBorder),
                          ),
                          child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.card - 1),
                        boxShadow: AppShadows.primaryButton,
                      ),
                      child: ElevatedButton(
                        onPressed: _guardando ? null : _guardar,
                        child: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Crear usuario'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EncabezadoDialogo extends StatelessWidget {
  const _EncabezadoDialogo({required this.icono, required this.titulo, required this.subtitulo});

  final IconData icono;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: const BoxDecoration(gradient: AppGradients.brand),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadii.badge),
            ),
            child: Icon(icono, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 2),
                Text(subtitulo,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 0.3,
      ),
    );
  }
}
