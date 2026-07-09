import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';
import '../../widgets/widgets.dart';

/// Reemplaza la hoja de control financiero por responsable/semana.
/// La usan tanto administrativo (una obra) como finanzas (todas las obras, [consolidado]=true).
class ResumenFinancieroPage extends StatefulWidget {
  const ResumenFinancieroPage({
    super.key,
    required this.filas,
    required this.nombreProveedor,
    this.consolidado = false,
  });

  final List<VistaResumenFinancieroSemanal> filas;
  final String nombreProveedor;
  final bool consolidado;

  @override
  State<ResumenFinancieroPage> createState() => _ResumenFinancieroPageState();
}

class _ResumenFinancieroPageState extends State<ResumenFinancieroPage> {
  PeriodoFiltro _periodo = PeriodoFiltro.mes;

  @override
  Widget build(BuildContext context) {
    final formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 0);
    final formatoFecha = DateFormat('d MMM', 'es_MX');
    final todasLasFilas = widget.filas;
    final ahora = todasLasFilas.isEmpty
        ? DateTime(2026, 7, 6)
        : todasLasFilas.map((f) => f.periodoInicio).reduce((a, b) => a.isAfter(b) ? a : b);
    final filas = filtrarPorPeriodo(todasLasFilas, (f) => f.periodoInicio, _periodo, ahora);
    final totalDepositado = filas.fold<double>(0, (acc, f) => acc + f.deposito);
    final saldoDisponible = filas.isEmpty ? 0.0 : filas.last.saldoAFavor;
    final totalSolicitado = filas.fold<double>(0, (acc, f) => acc + f.solicitado);
    final totalConsumo = filas.fold<double>(0, (acc, f) => acc + f.consumo);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.consolidado ? 'Resumen financiero consolidado' : 'Resumen financiero',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.navy),
                    ),
                    Text(widget.nombreProveedor, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              SegmentadorPeriodo(
                seleccionado: _periodo,
                onChanged: (p) => setState(() => _periodo = p),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TarjetaKpi(
                  titulo: 'TOTAL DEPOSITADO',
                  valor: formatoMoneda.format(totalDepositado),
                  gradiente: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TarjetaKpi(
                  titulo: 'SALDO DISPONIBLE',
                  valor: formatoMoneda.format(saldoDisponible),
                  gradiente: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: filas.isEmpty
                ? const EstadoVacio(
                    mensaje: 'No hay movimientos financieros en este periodo.',
                    icono: Icons.account_balance_wallet_outlined,
                  )
                : ConCargaSimulada(
                    builder: (context) => Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: DataTable2(
                // minWidth fuerza scroll horizontal en vez de comprimir columnas hasta ilegibles
                // cuando la pantalla (móvil, o el Drawer angosto de AdminShell) es más chica que esto.
                minWidth: 780,
                headingRowColor: WidgetStatePropertyAll(AppColors.navy),
                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                dataRowHeight: 44,
                columnSpacing: 20,
                columns: const [
                  DataColumn2(label: Text('SEMANA'), size: ColumnSize.S),
                  DataColumn2(label: Text('PERIODO'), size: ColumnSize.M),
                  DataColumn2(label: Text('SOLICITADO'), numeric: true, size: ColumnSize.M),
                  DataColumn2(label: Text('CONSUMO'), numeric: true, size: ColumnSize.M),
                  DataColumn2(label: Text('DEPÓSITO'), numeric: true, size: ColumnSize.M),
                  DataColumn2(label: Text('SALDO A FAVOR'), numeric: true, size: ColumnSize.M),
                  DataColumn2(label: Text('ESTATUS'), size: ColumnSize.S),
                ],
                rows: [
                  for (final fila in filas)
                    DataRow2(cells: [
                      DataCell(Text('S${fila.numeroSemana}', style: AppTypography.mono(fontSize: 12.5))),
                      DataCell(Text(
                        '${formatoFecha.format(fila.periodoInicio)} – ${formatoFecha.format(fila.periodoFin)}',
                        style: AppTypography.mono(fontSize: 12.5),
                      )),
                      DataCell(Text(formatoMoneda.format(fila.solicitado), style: AppTypography.mono(fontSize: 12.5))),
                      DataCell(Text(formatoMoneda.format(fila.consumo), style: AppTypography.mono(fontSize: 12.5))),
                      DataCell(Text(formatoMoneda.format(fila.deposito), style: AppTypography.mono(fontSize: 12.5))),
                      DataCell(Text(formatoMoneda.format(fila.saldoAFavor), style: AppTypography.mono(fontSize: 12.5))),
                      DataCell(_BadgeEstatus(estatus: fila.estatus)),
                    ]),
                ],
              ),
            ),
                  ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(AppRadii.miniCard),
            ),
            child: Row(
              children: [
                const Text('TOTALES', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const Spacer(),
                Text('Solicitado ${formatoMoneda.format(totalSolicitado)}', style: AppTypography.mono(fontSize: 13)),
                const SizedBox(width: 20),
                Text('Consumo ${formatoMoneda.format(totalConsumo)}', style: AppTypography.mono(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _PieFirmas(),
        ],
      ),
    );
  }
}

class _TarjetaKpi extends StatelessWidget {
  const _TarjetaKpi({required this.titulo, required this.valor, required this.gradiente});

  final String titulo;
  final String valor;
  final bool gradiente;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: gradiente ? null : AppColors.navy,
        gradient: gradiente ? const LinearGradient(colors: [AppColors.primary, Color(0xFF0A3FB0)]) : null,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11)),
          const SizedBox(height: 8),
          Text(valor, style: AppTypography.mono(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BadgeEstatus extends StatelessWidget {
  const _BadgeEstatus({required this.estatus});

  final String estatus;

  @override
  Widget build(BuildContext context) {
    final pagado = estatus == 'pagado';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: pagado ? AppColors.successBg : AppColors.statusYellowBg,
        borderRadius: BorderRadius.circular(AppRadii.badge),
      ),
      child: Text(
        pagado ? 'PAGADO' : 'SOLICITADO',
        style: TextStyle(
          color: pagado ? AppColors.success : AppColors.statusYellowText,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PieFirmas extends StatelessWidget {
  const _PieFirmas();

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(color: AppColors.textTertiary, fontSize: 12.5);
    return const Row(
      children: [
        Expanded(child: Text('Elaboró', style: estilo, textAlign: TextAlign.center)),
        Expanded(child: Text('Revisó', style: estilo, textAlign: TextAlign.center)),
        Expanded(child: Text('Autorizó', style: estilo, textAlign: TextAlign.center)),
      ],
    );
  }
}
