import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../state/session_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_typography.dart';
import '../../widgets/widgets.dart';

/// Tabla que se llena sola con cada comprobación de carga (reemplaza la hoja de Excel).
class ConcentradoCargasPage extends ConsumerStatefulWidget {
  const ConcentradoCargasPage({super.key});

  @override
  ConsumerState<ConcentradoCargasPage> createState() => _ConcentradoCargasPageState();
}

class _ConcentradoCargasPageState extends ConsumerState<ConcentradoCargasPage> {
  PeriodoFiltro _periodo = PeriodoFiltro.mes;

  @override
  Widget build(BuildContext context) {
    final obraId = ref.watch(sesionProvider)?.obraId;
    if (obraId == null) {
      return const Center(
        child: Text('Tu usuario no tiene una obra asignada.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final cargasAsync = ref.watch(concentradoCargasObraProvider(obraId));
    return cargasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('No se pudo cargar el concentrado: $error')),
      data: (todasLasCargas) => _Tabla(
        todasLasCargas: todasLasCargas,
        periodo: _periodo,
        onPeriodoChanged: (p) => setState(() => _periodo = p),
      ),
    );
  }
}

class _Tabla extends StatelessWidget {
  const _Tabla({
    required this.todasLasCargas,
    required this.periodo,
    required this.onPeriodoChanged,
  });

  final List<VistaConcentradoCargas> todasLasCargas;
  final PeriodoFiltro periodo;
  final ValueChanged<PeriodoFiltro> onPeriodoChanged;

  @override
  Widget build(BuildContext context) {
    final ahora = todasLasCargas.isEmpty
        ? DateTime.now()
        : todasLasCargas.map((f) => f.fecha).reduce((a, b) => a.isAfter(b) ? a : b);
    final filas = filtrarPorPeriodo(
      todasLasCargas,
      (f) => f.fecha,
      periodo,
      ahora,
    );
    final formatoFecha = DateFormat('d MMM', 'es_MX');
    final formatoMoneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 2);
    final totalLitros = filas.fold<double>(0, (acc, f) => acc + f.litros);
    final totalImporte = filas.fold<double>(0, (acc, f) => acc + f.importe);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Concentrado de cargas',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.navy)),
              ),
              SegmentadorPeriodo(
                seleccionado: periodo,
                onChanged: onPeriodoChanged,
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list_rounded, size: 16),
                label: const Text('Filtros'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Exportar Excel'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filas.isEmpty
                ? const EstadoVacio(
                    mensaje: 'No hay cargas registradas en este periodo.',
                    icono: Icons.local_gas_station_outlined,
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
                // 11 columnas: en móvil/tablet angosta se vuelve scroll horizontal en vez de
                // comprimirse hasta ilegible (ver mismo patrón en resumen_financiero_page.dart).
                minWidth: 1100,
                headingRowColor: WidgetStatePropertyAll(AppColors.navy),
                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                dataRowHeight: 44,
                columnSpacing: 20,
                columns: const [
                  DataColumn2(label: Text('FECHA'), size: ColumnSize.S),
                  DataColumn2(label: Text('RESPONSABLE'), size: ColumnSize.L),
                  DataColumn2(label: Text('VEHÍCULO'), size: ColumnSize.M),
                  DataColumn2(label: Text('PLACAS'), size: ColumnSize.S),
                  DataColumn2(label: Text('KM / HORAS'), numeric: true, size: ColumnSize.S),
                  DataColumn2(label: Text('LITROS'), numeric: true, size: ColumnSize.S),
                  DataColumn2(label: Text('KM/L'), numeric: true, size: ColumnSize.S),
                  DataColumn2(label: Text('\$/L'), numeric: true, size: ColumnSize.S),
                  DataColumn2(label: Text('COMB.'), size: ColumnSize.S),
                  DataColumn2(label: Text('IMPORTE'), numeric: true, size: ColumnSize.M),
                  DataColumn2(label: Text('TICKET'), size: ColumnSize.S),
                ],
                rows: [
                  for (final fila in filas)
                    DataRow2(
                      color: WidgetStatePropertyAll(
                        fila.alertaRendimiento == AlertaRendimiento.revisar
                            ? AppColors.errorBg
                            : fila.ticketPendiente
                                ? AppColors.warningBg
                                : null,
                      ),
                      cells: [
                        DataCell(Text(formatoFecha.format(fila.fecha), style: AppTypography.mono(fontSize: 12.5))),
                        DataCell(Text(fila.responsable)),
                        DataCell(Text(fila.vehiculoDescripcion)),
                        DataCell(Text(fila.placa, style: AppTypography.mono(fontSize: 12.5))),
                        DataCell(Text(
                          fila.esMaquinaria ? '${fila.horasActual ?? '—'} h' : '${fila.km ?? '—'}',
                          style: AppTypography.mono(fontSize: 12.5),
                        )),
                        DataCell(Text(fila.litros.toStringAsFixed(0), style: AppTypography.mono(fontSize: 12.5))),
                        DataCell(_CeldaRendimiento(fila: fila)),
                        DataCell(Text(
                          fila.ticketPendiente ? 'pend.' : formatoMoneda.format(fila.precioPorLitro),
                          style: AppTypography.mono(
                            fontSize: 12.5,
                            color: fila.ticketPendiente ? AppColors.warning : AppColors.navy,
                          ),
                        )),
                        DataCell(Text(fila.tipoCombustible.etiqueta)),
                        DataCell(Text(formatoMoneda.format(fila.importe), style: AppTypography.mono(fontSize: 12.5))),
                        DataCell(Icon(
                          fila.ticketPendiente ? Icons.access_time_rounded : Icons.check_circle_rounded,
                          size: 16,
                          color: fila.ticketPendiente ? AppColors.warning : AppColors.success,
                        )),
                      ],
                    ),
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
                Text('${totalLitros.toStringAsFixed(0)} L', style: AppTypography.mono(fontWeight: FontWeight.w600)),
                const SizedBox(width: 24),
                Text(formatoMoneda.format(totalImporte), style: AppTypography.mono(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _Leyenda(),
        ],
      ),
    );
  }
}

class _CeldaRendimiento extends StatelessWidget {
  const _CeldaRendimiento({required this.fila});

  final VistaConcentradoCargas fila;

  @override
  Widget build(BuildContext context) {
    final valor = fila.esMaquinaria ? fila.rendimientoLH : fila.rendimientoKmL;
    if (valor == null) return const Text('—');
    final anomalo = fila.alertaRendimiento == AlertaRendimiento.revisar;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valor.toStringAsFixed(1),
          style: AppTypography.mono(
            fontSize: 12.5,
            color: anomalo ? AppColors.error : AppColors.navy,
            fontWeight: anomalo ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        if (anomalo) ...[
          const SizedBox(width: 4),
          const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
        ],
      ],
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 8,
      children: const [
        _PuntoLeyenda(color: AppColors.errorBg, texto: 'Rendimiento anómalo'),
        _PuntoLeyenda(color: AppColors.warningBg, texto: 'Ticket pendiente'),
      ],
    );
  }
}

class _PuntoLeyenda extends StatelessWidget {
  const _PuntoLeyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
      ],
    );
  }
}
