import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../state/session_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';
import '../../utils/errores_red.dart';
import '../../widgets/widgets.dart';

const _estadosVehiculo = ['activo', 'taller', 'baja'];

String _etiquetaEstado(String estado) => switch (estado) {
  'activo' => 'Activo',
  'taller' => 'Taller',
  'baja' => 'Baja',
  _ => estado,
};

/// Alta/edición de vehículos de la obra del administrativo.
class VehiculosPage extends ConsumerStatefulWidget {
  const VehiculosPage({super.key});

  @override
  ConsumerState<VehiculosPage> createState() => _VehiculosPageState();
}

enum _FiltroVehiculo { todos, vehiculos, maquinaria, taller }

extension on _FiltroVehiculo {
  String get etiqueta => switch (this) {
    _FiltroVehiculo.todos => 'Todos',
    _FiltroVehiculo.vehiculos => 'Vehículos',
    _FiltroVehiculo.maquinaria => 'Maquinaria',
    _FiltroVehiculo.taller => 'En mantenimiento',
  };

  bool aplicaA(Vehiculo v) => switch (this) {
    _FiltroVehiculo.todos => true,
    _FiltroVehiculo.vehiculos => v.tipoUnidad == TipoUnidad.vehiculo,
    _FiltroVehiculo.maquinaria => v.tipoUnidad == TipoUnidad.maquinaria,
    _FiltroVehiculo.taller => v.estado == 'taller',
  };
}

class _VehiculosPageState extends ConsumerState<VehiculosPage> {
  _FiltroVehiculo _filtro = _FiltroVehiculo.todos;

  Future<void> _abrirFormulario(String obraId, {Vehiculo? existente}) async {
    final resultado = await showDialog<Vehiculo>(
      context: context,
      builder: (_) => _VehiculoFormDialog(existente: existente, obraId: obraId),
    );
    if (resultado == null) return;
    try {
      if (existente == null) {
        await ref.read(vehiculoRepositoryProvider).crear(resultado);
      } else {
        await ref.read(vehiculoRepositoryProvider).actualizar(resultado);
      }
      ref.invalidate(vehiculosPorObraProvider(obraId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existente == null ? 'Vehículo agregado.' : 'Vehículo actualizado.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeErrorRed(e, accion: 'guardar el vehículo'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final obraId = ref.watch(sesionProvider)?.obraId;
    if (obraId == null) {
      return const Center(
        child: Text(
          'Tu usuario no tiene una obra asignada.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final vehiculosAsync = ref.watch(vehiculosPorObraProvider(obraId));
    final concentradoAsync = ref.watch(concentradoCargasObraProvider(obraId));

    // Gasto de esta semana (lunes a hoy) por placa — real, no decorativo:
    // mismo dato que ya se ve en Concentrado, aquí resumido por unidad.
    final gastoSemanalPorPlaca = <String, double>{};
    concentradoAsync.whenData((cargas) {
      final hoy = DateTime.now();
      final inicioSemana = DateTime(
        hoy.year,
        hoy.month,
        hoy.day,
      ).subtract(Duration(days: hoy.weekday - 1));
      for (final carga in cargas) {
        if (carga.fecha.isBefore(inicioSemana)) continue;
        gastoSemanalPorPlaca.update(
          carga.placa,
          (v) => v + carga.importe,
          ifAbsent: () => carga.importe,
        );
      }
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Vehículos y maquinaria',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    color: AppColors.navy,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _abrirFormulario(obraId),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar unidad'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final filtro in _FiltroVehiculo.values)
                ChoiceChip(
                  label: Text(filtro.etiqueta),
                  selected: _filtro == filtro,
                  onSelected: (_) => setState(() => _filtro = filtro),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: vehiculosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('No se pudieron cargar los vehículos: $error'),
              ),
              data: (todos) {
                final vehiculos = todos.where(_filtro.aplicaA).toList();
                if (vehiculos.isEmpty) {
                  return EstadoVacio(
                    mensaje: todos.isEmpty
                        ? 'No hay vehículos registrados en esta obra.'
                        : 'Ninguna unidad coincide con "${_filtro.etiqueta}".',
                    icono: Icons.local_shipping_outlined,
                  );
                }
                return ListView.separated(
                  itemCount: vehiculos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final vehiculo = vehiculos[i];
                    return _TarjetaVehiculo(
                      vehiculo: vehiculo,
                      gastoSemanal: gastoSemanalPorPlaca[vehiculo.placa] ?? 0,
                      onTap: () =>
                          _abrirFormulario(obraId, existente: vehiculo),
                    );
                  },
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
  const _TarjetaVehiculo({
    required this.vehiculo,
    required this.gastoSemanal,
    required this.onTap,
  });

  final Vehiculo vehiculo;

  /// Gasto real de combustible de esta unidad en la semana en curso (lunes a
  /// hoy) — mismo dato que Concentrado de cargas, resumido por unidad.
  final double gastoSemanal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorEstado = switch (vehiculo.estado) {
      'activo' => AppColors.success,
      'taller' => AppColors.warning,
      _ => AppColors.error,
    };
    final fondoEstado = switch (vehiculo.estado) {
      'activo' => AppColors.successBg,
      'taller' => AppColors.warningBg,
      _ => AppColors.errorBg,
    };
    final formatoMoneda = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 0,
    );

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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppGradients.budgetCard,
                borderRadius: BorderRadius.circular(AppRadii.miniCard),
              ),
              child: Icon(
                vehiculo.tipoUnidad == TipoUnidad.maquinaria
                    ? Icons.precision_manufacturing_rounded
                    : Icons.local_shipping_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehiculo.descripcion,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${vehiculo.placa} · ${vehiculo.tipoCombustible.etiqueta} · ${vehiculo.anio ?? '—'}',
                    style: AppTypography.mono(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppRadii.miniCard),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'GASTO ESTA SEMANA',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w800,
                      fontSize: 9.5,
                    ),
                  ),
                  Text(
                    formatoMoneda.format(gastoSemanal),
                    style: AppTypography.mono(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${vehiculo.topeLitrosSemanal.toStringAsFixed(0)} L/semana',
                  style: AppTypography.mono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: fondoEstado,
                    borderRadius: BorderRadius.circular(AppRadii.badge),
                  ),
                  child: Text(
                    _etiquetaEstado(vehiculo.estado),
                    style: TextStyle(
                      color: colorEstado,
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
  const _VehiculoFormDialog({this.existente, required this.obraId});

  final Vehiculo? existente;
  final String obraId;

  @override
  State<_VehiculoFormDialog> createState() => _VehiculoFormDialogState();
}

class _VehiculoFormDialogState extends State<_VehiculoFormDialog> {
  late final _placaCtrl = TextEditingController(text: widget.existente?.placa);
  late final _marcaCtrl = TextEditingController(text: widget.existente?.marca);
  late final _modeloCtrl = TextEditingController(
    text: widget.existente?.modelo,
  );
  late final _anioCtrl = TextEditingController(
    text: widget.existente?.anio?.toString(),
  );
  late final _topeCtrl = TextEditingController(
    text: widget.existente?.topeLitrosSemanal.toStringAsFixed(0),
  );
  late TipoCombustible _tipo =
      widget.existente?.tipoCombustible ?? TipoCombustible.magna;
  late TipoUnidad _tipoUnidad =
      widget.existente?.tipoUnidad ?? TipoUnidad.vehiculo;
  late String _estado = widget.existente?.estado ?? 'activo';
  String? _error;

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
    if (_placaCtrl.text.trim().isEmpty || _marcaCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Placa y marca son obligatorias.');
      return;
    }

    final vehiculo = Vehiculo(
      id: widget.existente?.id ?? '',
      placa: _placaCtrl.text.trim(),
      marca: _marcaCtrl.text.trim(),
      modelo: _modeloCtrl.text.trim(),
      anio: int.tryParse(_anioCtrl.text),
      tipoCombustible: _tipo,
      topeLitrosSemanal: double.tryParse(_topeCtrl.text) ?? 0,
      obraId: widget.obraId,
      estado: _estado,
      tipoUnidad: _tipoUnidad,
    );
    Navigator.of(context).pop(vehiculo);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existente == null ? 'Nuevo vehículo' : 'Editar vehículo',
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(AppRadii.miniCard),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _placaCtrl,
                decoration: const InputDecoration(labelText: 'Placa'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _marcaCtrl,
                      decoration: const InputDecoration(labelText: 'Marca'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _modeloCtrl,
                      decoration: const InputDecoration(labelText: 'Modelo'),
                    ),
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
                      decoration: const InputDecoration(
                        labelText: 'Tope L/semana',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Combustible',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FuelTypeChipSelector(
                seleccionado: _tipo,
                onChanged: (t) => setState(() => _tipo = t),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tipo de unidad',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<TipoUnidad>(
                segments: const [
                  ButtonSegment(
                    value: TipoUnidad.vehiculo,
                    label: Text('Vehículo (km)'),
                  ),
                  ButtonSegment(
                    value: TipoUnidad.maquinaria,
                    label: Text('Maquinaria (horas)'),
                  ),
                ],
                selected: {_tipoUnidad},
                onSelectionChanged: (s) =>
                    setState(() => _tipoUnidad = s.first),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Estado',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  for (final e in _estadosVehiculo)
                    ButtonSegment(value: e, label: Text(_etiquetaEstado(e))),
                ],
                selected: {_estado},
                onSelectionChanged: (s) => setState(() => _estado = s.first),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
