import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';
import '../../utils/errores_red.dart';

/// Cierre de la semana operativa (Fase 5). El backend valida que no se pueda
/// reabrir ni volver a cerrar; aquí solo se dispara la llamada y se refleja el estado.
class CierreSemanalPage extends ConsumerStatefulWidget {
  const CierreSemanalPage({super.key});

  @override
  ConsumerState<CierreSemanalPage> createState() => _CierreSemanalPageState();
}

class _CierreSemanalPageState extends ConsumerState<CierreSemanalPage> {
  bool _cerrando = false;

  Future<void> _confirmarCierre(String obraId, SemanaOperativa semana) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar semana'),
        content: Text(
          'Al cerrar la semana ${_rangoTexto(semana)} ya no se podrán registrar nuevas cargas '
          'ni solicitudes contra este periodo. ¿Confirmas el cierre?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cerrar semana')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _cerrando = true);
    try {
      await ref.read(semanaOperativaRepositoryProvider).cerrar(semana.id);
      ref.invalidate(semanaActualProvider(obraId));
      ref.invalidate(resumenFinancieroSemanalProvider(obraId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('No se pudo cerrar la semana. Intenta de nuevo.'),
        ));
    } finally {
      if (mounted) setState(() => _cerrando = false);
    }
  }

  String _rangoTexto(SemanaOperativa semana) {
    final formato = DateFormat('d MMM', 'es_MX');
    return '${formato.format(semana.periodoInicio)} – ${formato.format(semana.periodoFin)}';
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasTodasProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: obrasAsync.when(
        data: (obras) {
          if (obras.isEmpty) {
            return const Text('No hay obras registradas todavía.');
          }
          // TODO: agregar selector de obra si finanzas llega a manejar más de una.
          final obraId = obras.first.id;
          return _CuerpoCierre(
            obraId: obraId,
            cerrando: _cerrando,
            onCerrar: (semana) => _confirmarCierre(obraId, semana),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(mensajeErrorRed(e, accion: 'cargar el catálogo de obras')),
      ),
    );
  }
}

class _CuerpoCierre extends ConsumerWidget {
  const _CuerpoCierre({
    required this.obraId,
    required this.cerrando,
    required this.onCerrar,
  });

  final String obraId;
  final bool cerrando;
  final void Function(SemanaOperativa semana) onCerrar;

  String _rangoTexto(SemanaOperativa semana) {
    final formato = DateFormat('d MMM', 'es_MX');
    return '${formato.format(semana.periodoInicio)} – ${formato.format(semana.periodoFin)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semanaAsync = ref.watch(semanaActualProvider(obraId));
    final resumenAsync = ref.watch(resumenFinancieroSemanalProvider(obraId));
    final formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 0);

    return semanaAsync.when(
      data: (semana) {
        final resumenSemana = resumenAsync.value?.lastOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cierre semanal',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.navy)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SEMANA EN CURSO',
                                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(_rangoTexto(semana),
                                style: AppTypography.mono(fontSize: 18, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      _BadgeEstadoSemana(cerrada: semana.cerrada),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (resumenSemana == null)
                    const Text('Sin resumen financiero para esta semana todavía.',
                        style: TextStyle(color: AppColors.textSecondary))
                  else
                    Row(
                      children: [
                        _Dato(label: 'Solicitado', valor: formatoMoneda.format(resumenSemana.solicitado)),
                        _Dato(label: 'Consumo', valor: formatoMoneda.format(resumenSemana.consumo)),
                        _Dato(label: 'Saldo a favor', valor: formatoMoneda.format(resumenSemana.saldoAFavor)),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (semana.cerrada)
              const Text(
                'Esta semana ya está cerrada. No se pueden registrar más movimientos contra este periodo.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ElevatedButton(
                onPressed: cerrando ? null : () => onCerrar(semana),
                child: cerrando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Cerrar semana'),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(mensajeErrorRed(e, accion: 'cargar la semana operativa')),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text(valor, style: AppTypography.mono(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BadgeEstadoSemana extends StatelessWidget {
  const _BadgeEstadoSemana({required this.cerrada});

  final bool cerrada;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cerrada ? AppColors.infoBg : AppColors.successBg,
        borderRadius: BorderRadius.circular(AppRadii.badge),
      ),
      child: Text(
        cerrada ? 'CERRADA' : 'ABIERTA',
        style: TextStyle(
          color: cerrada ? AppColors.info : AppColors.success,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
