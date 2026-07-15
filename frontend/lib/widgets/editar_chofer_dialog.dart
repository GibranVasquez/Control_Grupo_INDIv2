import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../utils/errores_red.dart';

/// Edición parcial de un chofer ya registrado (`PUT /perfiles/:id`, ver
/// perfil_repository.dart). Compartido entre `usuarios_page.dart` (finanzas,
/// ve todas las obras) y `choferes_page.dart` (administrativo, solo su
/// propia obra — si intenta reasignar a otra obra, el backend lo rechaza con
/// 403 vía asegurarAccesoObra, no hace falta duplicar esa restricción aquí).
///
/// obra_id es obligatorio en cada request aunque solo se edite otro campo —
/// por eso el dropdown de obra siempre viene prellenado con el valor actual
/// del chofer, nunca vacío.
class EditarChoferDialog extends ConsumerStatefulWidget {
  const EditarChoferDialog({super.key, required this.chofer});

  final Perfil chofer;

  @override
  ConsumerState<EditarChoferDialog> createState() => _EditarChoferDialogState();
}

class _EditarChoferDialogState extends ConsumerState<EditarChoferDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nombreCtrl = TextEditingController(text: widget.chofer.nombreCompleto);
  late final _correoCtrl = TextEditingController(text: widget.chofer.correo ?? '');
  late final _edadCtrl = TextEditingController(text: widget.chofer.edad?.toString() ?? '');
  late final _areaCtrl = TextEditingController(text: widget.chofer.area ?? '');

  late String? _obraId = widget.chofer.obraId;
  late String? _vehiculoId = widget.chofer.vehiculoId;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _edadCtrl.dispose();
    _areaCtrl.dispose();
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
      await ref.read(perfilRepositoryProvider).actualizar(
            perfilId: widget.chofer.id,
            obraId: _obraId!,
            nombreCompleto: _nombreCtrl.text.trim(),
            correo: _correoCtrl.text.trim().isEmpty ? null : _correoCtrl.text.trim(),
            edad: int.tryParse(_edadCtrl.text.trim()),
            area: _areaCtrl.text.trim().isEmpty ? null : _areaCtrl.text.trim(),
            vehiculoId: _vehiculoId,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _guardando = false;
        _error = mensajeErrorRed(e, accion: 'guardar los cambios');
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
            _EncabezadoDialogo(subtitulo: widget.chofer.usuario),
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
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _correoCtrl,
                        decoration: const InputDecoration(labelText: 'Correo'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _edadCtrl,
                        decoration: const InputDecoration(labelText: 'Edad'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _areaCtrl,
                        decoration: const InputDecoration(labelText: 'Área'),
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
                        error: (e, _) => Text(mensajeErrorRed(e, accion: 'cargar el catálogo de obras')),
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
                              error: (e, _) => Text(mensajeErrorRed(e, accion: 'cargar el catálogo de vehículos')),
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
                            : const Text('Guardar cambios'),
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
  const _EncabezadoDialogo({required this.subtitulo});

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
            child: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Editar chofer',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
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
