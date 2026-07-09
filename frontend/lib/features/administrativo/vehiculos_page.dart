import 'package:flutter/material.dart';

import '../../dev/datos_demo.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';
import '../../widgets/widgets.dart';

/// Alta/edición de vehículos de la obra del administrativo (Fase 4).
class VehiculosPage extends StatefulWidget {
  const VehiculosPage({super.key});

  @override
  State<VehiculosPage> createState() => _VehiculosPageState();
}

class _VehiculosPageState extends State<VehiculosPage> {
  late List<Vehiculo> _vehiculos = List.of(DatosDemo.vehiculosObra);

  Future<void> _abrirFormulario({Vehiculo? existente}) async {
    final resultado = await showDialog<Vehiculo>(
      context: context,
      builder: (_) => _VehiculoFormDialog(existente: existente),
    );
    if (resultado == null) return;
    // TODO: VehiculoRepository.crear / actualizar según corresponda.
    setState(() {
      final indice = _vehiculos.indexWhere((v) => v.id == resultado.id);
      if (indice >= 0) {
        _vehiculos[indice] = resultado;
      } else {
        _vehiculos = [..._vehiculos, resultado];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Vehículos',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.navy)),
              ),
              ElevatedButton.icon(
                onPressed: () => _abrirFormulario(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar vehículo'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: _vehiculos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final vehiculo = _vehiculos[i];
                return _TarjetaVehiculo(
                  vehiculo: vehiculo,
                  onTap: () => _abrirFormulario(existente: vehiculo),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaVehiculo extends StatelessWidget {
  const _TarjetaVehiculo({required this.vehiculo, required this.onTap});

  final Vehiculo vehiculo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activo = vehiculo.estado == 'activo';

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(AppRadii.miniCard),
              ),
              child: const Icon(Icons.local_shipping_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehiculo.descripcion, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(
                    '${vehiculo.placa} · ${vehiculo.tipoCombustible.etiqueta} · ${vehiculo.anio ?? '—'}',
                    style: AppTypography.mono(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${vehiculo.topeLitrosSemanal.toStringAsFixed(0)} L/semana',
                    style: AppTypography.mono(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: activo ? AppColors.successBg : AppColors.errorBg,
                    borderRadius: BorderRadius.circular(AppRadii.badge),
                  ),
                  child: Text(
                    activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      color: activo ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VehiculoFormDialog extends StatefulWidget {
  const _VehiculoFormDialog({this.existente});

  final Vehiculo? existente;

  @override
  State<_VehiculoFormDialog> createState() => _VehiculoFormDialogState();
}

class _VehiculoFormDialogState extends State<_VehiculoFormDialog> {
  late final _placaCtrl = TextEditingController(text: widget.existente?.placa);
  late final _marcaCtrl = TextEditingController(text: widget.existente?.marca);
  late final _modeloCtrl = TextEditingController(text: widget.existente?.modelo);
  late final _anioCtrl = TextEditingController(text: widget.existente?.anio?.toString());
  late final _topeCtrl =
      TextEditingController(text: widget.existente?.topeLitrosSemanal.toStringAsFixed(0));
  late TipoCombustible _tipo = widget.existente?.tipoCombustible ?? TipoCombustible.magna;
  late bool _activo = (widget.existente?.estado ?? 'activo') == 'activo';

  @override
  void dispose() {
    _placaCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _topeCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    if (_placaCtrl.text.trim().isEmpty || _marcaCtrl.text.trim().isEmpty) return;

    final vehiculo = Vehiculo(
      id: widget.existente?.id ?? 'vehiculo-${DateTime.now().microsecondsSinceEpoch}',
      placa: _placaCtrl.text.trim(),
      marca: _marcaCtrl.text.trim(),
      modelo: _modeloCtrl.text.trim(),
      anio: int.tryParse(_anioCtrl.text),
      tipoCombustible: _tipo,
      topeLitrosSemanal: double.tryParse(_topeCtrl.text) ?? 0,
      obraId: widget.existente?.obraId ?? DatosDemo.obras.first.id,
      estado: _activo ? 'activo' : 'inactivo',
    );
    Navigator.of(context).pop(vehiculo);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existente == null ? 'Nuevo vehículo' : 'Editar vehículo'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: _placaCtrl, decoration: const InputDecoration(labelText: 'Placa')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: _marcaCtrl, decoration: const InputDecoration(labelText: 'Marca')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(controller: _modeloCtrl, decoration: const InputDecoration(labelText: 'Modelo')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _anioCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Año'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _topeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tope L/semana'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Combustible',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const SizedBox(height: 8),
              FuelTypeChipSelector(seleccionado: _tipo, onChanged: (t) => setState(() => _tipo = t)),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vehículo activo'),
                value: _activo,
                onChanged: (v) => setState(() => _activo = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
