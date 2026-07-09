import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../dev/datos_demo.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';

/// Cierre de la semana operativa (Fase 5). El backend valida que no se pueda
/// reabrir ni volver a cerrar; aquí solo se dispara la llamada y se refleja el estado.
class CierreSemanalPage extends StatefulWidget {
  const CierreSemanalPage({super.key});

  @override
  State<CierreSemanalPage> createState() => _CierreSemanalPageState();
}

class _CierreSemanalPageState extends State<CierreSemanalPage> {
  late SemanaOperativa _semana = DatosDemo.semanaActual;

  Future<void> _confirmarCierre() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar semana'),
        content: Text(
          'Al cerrar la semana ${_rangoTexto(_semana)} ya no se podrán registrar nuevas cargas '
          'ni solicitudes contra este periodo. ¿Confirmas el cierre?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cerrar semana')),
        ],
      ),
    );
    if (confirmar != true) return;

    // TODO: SemanaOperativaRepository.cerrar(_semana.id).
    setState(() {
      _semana = SemanaOperativa(
        id: _semana.id,
        periodoInicio: _semana.periodoInicio,
        periodoFin: _semana.periodoFin,
        estado: 'cerrada',
      );
    });
  }

  String _rangoTexto(SemanaOperativa semana) {
    final formato = DateFormat('d MMM', 'es_MX');
    return '${formato.format(semana.periodoInicio)} – ${formato.format(semana.periodoFin)}';
  }

  @override
  Widget build(BuildContext context) {
    final resumenSemana = DatosDemo.resumenFinancieroObra.last;
    final formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
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
                          Text(_rangoTexto(_semana),
                              style: AppTypography.mono(fontSize: 18, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    _BadgeEstadoSemana(cerrada: _semana.cerrada),
                  ],
                ),
                const SizedBox(height: 20),
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
          if (_semana.cerrada)
            const Text(
              'Esta semana ya está cerrada. No se pueden registrar más movimientos contra este periodo.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ElevatedButton(
              onPressed: _confirmarCierre,
              child: const Text('Cerrar semana'),
            ),
        ],
      ),
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
