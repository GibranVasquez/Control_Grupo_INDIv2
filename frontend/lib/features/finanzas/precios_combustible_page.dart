import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';

/// Gestión de precios vigentes por tipo de combustible (Fase 5).
/// Dar de alta un precio nuevo no borra el histórico — solo agrega una fila más vigente.
class PreciosCombustiblePage extends ConsumerStatefulWidget {
  const PreciosCombustiblePage({super.key});

  @override
  ConsumerState<PreciosCombustiblePage> createState() => _PreciosCombustiblePageState();
}

class _PreciosCombustiblePageState extends ConsumerState<PreciosCombustiblePage> {
  TipoCombustible _tipoHistorico = TipoCombustible.magna;

  Future<void> _nuevoPrecio() async {
    final resultado = await showDialog<PrecioCombustible>(
      context: context,
      builder: (_) => const _NuevoPrecioDialog(),
    );
    if (resultado == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(precioCombustibleRepositoryProvider).crear(resultado);
      for (final tipo in TipoCombustible.values) {
        ref.invalidate(precioVigenteProvider(tipo));
        ref.invalidate(precioHistoricoProvider(tipo));
      }
      messenger.showSnackBar(const SnackBar(content: Text('Precio actualizado.')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text('No se pudo guardar el precio: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final historicoAsync = ref.watch(precioHistoricoProvider(_tipoHistorico));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Precios de combustible',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.navy)),
              ),
              ElevatedButton.icon(
                onPressed: _nuevoPrecio,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nuevo precio'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final tipo in TipoCombustible.values) ...[
                Expanded(child: _TarjetaPrecioVigente(tipo: tipo)),
                if (tipo != TipoCombustible.values.last) const SizedBox(width: 16),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('HISTÓRICO',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
              const Spacer(),
              DropdownButton<TipoCombustible>(
                value: _tipoHistorico,
                items: TipoCombustible.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.etiqueta)))
                    .toList(),
                onChanged: (t) => setState(() => _tipoHistorico = t ?? _tipoHistorico),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: historicoAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('No se pudo cargar el histórico: $error')),
              data: (precios) {
                if (precios.isEmpty) {
                  return const Center(
                    child: Text('Sin histórico registrado para este combustible.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                final formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
                return ListView.separated(
                  itemCount: precios.length,
                  separatorBuilder: (_, _) => const Divider(color: AppColors.divider, height: 1),
                  itemBuilder: (context, i) {
                    final precio = precios[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Vigente desde ${DateFormat('d MMM y', 'es_MX').format(precio.vigenteDesde)}',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          Text(formatoMoneda.format(precio.precioPorLitro),
                              style: AppTypography.mono(fontWeight: FontWeight.w600)),
                        ],
                      ),
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

class _TarjetaPrecioVigente extends ConsumerWidget {
  const _TarjetaPrecioVigente({required this.tipo});

  final TipoCombustible tipo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final precioAsync = ref.watch(precioVigenteProvider(tipo));
    final formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tipo.etiqueta.toUpperCase(),
              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 11)),
          const SizedBox(height: 6),
          precioAsync.when(
            data: (precio) => Text(formatoMoneda.format(precio.precioPorLitro),
                style: AppTypography.mono(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.primary)),
            loading: () => const SizedBox(
              height: 26,
              width: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, _) => const Text('Sin precio vigente',
                style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          const Text('por litro', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _NuevoPrecioDialog extends StatefulWidget {
  const _NuevoPrecioDialog();

  @override
  State<_NuevoPrecioDialog> createState() => _NuevoPrecioDialogState();
}

class _NuevoPrecioDialogState extends State<_NuevoPrecioDialog> {
  TipoCombustible _tipo = TipoCombustible.magna;
  final _precioCtrl = TextEditingController();

  @override
  void dispose() {
    _precioCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    final precio = double.tryParse(_precioCtrl.text);
    if (precio == null || precio <= 0) return;
    Navigator.of(context).pop(
      PrecioCombustible(
        id: 'precio-nuevo',
        tipoCombustible: _tipo,
        precioPorLitro: precio,
        vigenteDesde: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo precio vigente'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<TipoCombustible>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Combustible'),
              items: [
                for (final tipo in TipoCombustible.values)
                  DropdownMenuItem(value: tipo, child: Text(tipo.etiqueta)),
              ],
              onChanged: (t) => setState(() => _tipo = t ?? _tipo),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _precioCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Precio por litro', prefixText: r'$ '),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
