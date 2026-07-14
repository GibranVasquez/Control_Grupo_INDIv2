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
import '../../utils/errores_red.dart';
import '../../utils/exportar_csv.dart';
import '../../widgets/widgets.dart';

/// Filtros aplicables al concentrado, además del periodo (Día/Semana/Mes/Año).
class FiltrosConcentrado {
  const FiltrosConcentrado({
    this.soloAnomalas = false,
    this.soloTicketPendiente = false,
    this.busqueda = '',
  });

  final bool soloAnomalas;
  final bool soloTicketPendiente;
  final String busqueda;

  bool get activos =>
      soloAnomalas || soloTicketPendiente || busqueda.trim().isNotEmpty;

  bool aplicaA(VistaConcentradoCargas fila) {
    if (soloAnomalas && fila.alertaRendimiento != AlertaRendimiento.revisar)
      return false;
    if (soloTicketPendiente && !fila.ticketPendiente) return false;
    final texto = busqueda.trim().toLowerCase();
    if (texto.isEmpty) return true;
    return fila.responsable.toLowerCase().contains(texto) ||
        fila.vehiculoDescripcion.toLowerCase().contains(texto) ||
        fila.placa.toLowerCase().contains(texto);
  }

  FiltrosConcentrado copyWith({
    bool? soloAnomalas,
    bool? soloTicketPendiente,
    String? busqueda,
  }) {
    return FiltrosConcentrado(
      soloAnomalas: soloAnomalas ?? this.soloAnomalas,
      soloTicketPendiente: soloTicketPendiente ?? this.soloTicketPendiente,
      busqueda: busqueda ?? this.busqueda,
    );
  }
}

/// Tabla que se llena sola con cada comprobación de carga (reemplaza la hoja de Excel).
class ConcentradoCargasPage extends ConsumerStatefulWidget {
  const ConcentradoCargasPage({super.key});

  @override
  ConsumerState<ConcentradoCargasPage> createState() =>
      _ConcentradoCargasPageState();
}

class _ConcentradoCargasPageState extends ConsumerState<ConcentradoCargasPage> {
  PeriodoFiltro _periodo = PeriodoFiltro.mes;
  FiltrosConcentrado _filtros = const FiltrosConcentrado();

  Future<void> _abrirFiltros() async {
    final resultado = await showDialog<FiltrosConcentrado>(
      context: context,
      builder: (_) => _FiltrosDialog(filtros: _filtros),
    );
    if (resultado != null) setState(() => _filtros = resultado);
  }

  Future<void> _exportar(List<VistaConcentradoCargas> filas) async {
    final messenger = ScaffoldMessenger.of(context);
    if (filas.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No hay filas para exportar en este periodo.'),
        ),
      );
      return;
    }

    try {
      final formatoFecha = DateFormat('yyyy-MM-dd');
      final archivo = await exportarCsv(
        nombreBase: 'concentrado_cargas',
        encabezados: const [
          'Fecha',
          'Responsable',
          'Vehiculo',
          'Placas',
          'Km/Horas',
          'Litros',
          'Rendimiento',
          'Precio por litro',
          'Combustible',
          'Importe',
          'Ticket',
        ],
        filas: [
          for (final fila in filas)
            [
              formatoFecha.format(fila.fecha),
              fila.responsable,
              fila.vehiculoDescripcion,
              fila.placa,
              fila.esMaquinaria ? fila.horasActual : fila.km,
              fila.litros,
              fila.esMaquinaria ? fila.rendimientoLH : fila.rendimientoKmL,
              fila.precioPorLitro,
              fila.tipoCombustible.etiqueta,
              fila.importe,
              fila.ticketPendiente ? 'Pendiente' : 'Entregado',
            ],
        ],
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Exportado a ${archivo.path}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(mensajeErrorRed(e, accion: 'exportar el archivo')),
        ),
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

    final cargasAsync = ref.watch(concentradoCargasObraProvider(obraId));
    return cargasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('No se pudo cargar el concentrado: $error')),
      data: (todasLasCargas) => _Tabla(
        todasLasCargas: todasLasCargas,
        periodo: _periodo,
        filtros: _filtros,
        onPeriodoChanged: (p) => setState(() => _periodo = p),
        onAbrirFiltros: _abrirFiltros,
        onExportar: _exportar,
      ),
    );
  }
}

class _FiltrosDialog extends StatefulWidget {
  const _FiltrosDialog({required this.filtros});

  final FiltrosConcentrado filtros;

  @override
  State<_FiltrosDialog> createState() => _FiltrosDialogState();
}

class _FiltrosDialogState extends State<_FiltrosDialog> {
  late bool _soloAnomalas = widget.filtros.soloAnomalas;
  late bool _soloTicketPendiente = widget.filtros.soloTicketPendiente;
  late final _busquedaCtrl = TextEditingController(
    text: widget.filtros.busqueda,
  );

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtros'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _busquedaCtrl,
              decoration: const InputDecoration(
                labelText: 'Buscar',
                hintText: 'Responsable, vehículo o placas',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _soloAnomalas,
              title: const Text('Solo rendimiento anómalo'),
              onChanged: (v) => setState(() => _soloAnomalas = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _soloTicketPendiente,
              title: const Text('Solo ticket pendiente'),
              onChanged: (v) =>
                  setState(() => _soloTicketPendiente = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const FiltrosConcentrado()),
          child: const Text('Limpiar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(
            FiltrosConcentrado(
              soloAnomalas: _soloAnomalas,
              soloTicketPendiente: _soloTicketPendiente,
              busqueda: _busquedaCtrl.text,
            ),
          ),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _Tabla extends StatelessWidget {
  const _Tabla({
    required this.todasLasCargas,
    required this.periodo,
    required this.filtros,
    required this.onPeriodoChanged,
    required this.onAbrirFiltros,
    required this.onExportar,
  });

  final List<VistaConcentradoCargas> todasLasCargas;
  final PeriodoFiltro periodo;
  final FiltrosConcentrado filtros;
  final ValueChanged<PeriodoFiltro> onPeriodoChanged;
  final VoidCallback onAbrirFiltros;
  final ValueChanged<List<VistaConcentradoCargas>> onExportar;

  @override
  Widget build(BuildContext context) {
    final ahora = todasLasCargas.isEmpty
        ? DateTime.now()
        : todasLasCargas
              .map((f) => f.fecha)
              .reduce((a, b) => a.isAfter(b) ? a : b);
    final filas = filtrarPorPeriodo(
      todasLasCargas,
      (f) => f.fecha,
      periodo,
      ahora,
    ).where(filtros.aplicaA).toList();
    final formatoFecha = DateFormat('d MMM', 'es_MX');
    final formatoMoneda = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 2,
    );
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
                child: Text(
                  'Concentrado de cargas',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    color: AppColors.navy,
                  ),
                ),
              ),
              SegmentadorPeriodo(
                seleccionado: periodo,
                onChanged: onPeriodoChanged,
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onAbrirFiltros,
                icon: Icon(
                  filtros.activos
                      ? Icons.filter_alt_rounded
                      : Icons.filter_list_rounded,
                  size: 16,
                  color: filtros.activos ? AppColors.primary : null,
                ),
                label: Text(filtros.activos ? 'Filtros (activos)' : 'Filtros'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => onExportar(filas),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Exportar Excel'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: GraficaGastos(
                    fechas: [for (final f in todasLasCargas) f.fecha],
                    importes: [for (final f in todasLasCargas) f.importe],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: DonutGastoCombustible(cargas: filas)),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                        headingTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        dataRowHeight: 44,
                        columnSpacing: 20,
                        columns: const [
                          DataColumn2(label: Text('FECHA'), size: ColumnSize.S),
                          DataColumn2(
                            label: Text('RESPONSABLE'),
                            size: ColumnSize.L,
                          ),
                          DataColumn2(
                            label: Text('VEHÍCULO'),
                            size: ColumnSize.M,
                          ),
                          DataColumn2(
                            label: Text('PLACAS'),
                            size: ColumnSize.S,
                          ),
                          DataColumn2(
                            label: Text('KM / HORAS'),
                            numeric: true,
                            size: ColumnSize.S,
                          ),
                          DataColumn2(
                            label: Text('LITROS'),
                            numeric: true,
                            size: ColumnSize.S,
                          ),
                          DataColumn2(
                            label: Text('KM/L'),
                            numeric: true,
                            size: ColumnSize.S,
                          ),
                          DataColumn2(
                            label: Text('\$/L'),
                            numeric: true,
                            size: ColumnSize.S,
                          ),
                          DataColumn2(label: Text('COMB.'), size: ColumnSize.S),
                          DataColumn2(
                            label: Text('IMPORTE'),
                            numeric: true,
                            size: ColumnSize.M,
                          ),
                          DataColumn2(
                            label: Text('TICKET'),
                            size: ColumnSize.S,
                          ),
                        ],
                        rows: [
                          for (final fila in filas)
                            DataRow2(
                              color: WidgetStatePropertyAll(
                                fila.alertaRendimiento ==
                                        AlertaRendimiento.revisar
                                    ? AppColors.errorBg
                                    : fila.ticketPendiente
                                    ? AppColors.warningBg
                                    : null,
                              ),
                              cells: [
                                DataCell(
                                  Text(
                                    formatoFecha.format(fila.fecha),
                                    style: AppTypography.mono(fontSize: 12.5),
                                  ),
                                ),
                                DataCell(Text(fila.responsable)),
                                DataCell(Text(fila.vehiculoDescripcion)),
                                DataCell(
                                  Text(
                                    fila.placa,
                                    style: AppTypography.mono(fontSize: 12.5),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    fila.esMaquinaria
                                        ? '${fila.horasActual ?? '—'} h'
                                        : '${fila.km ?? '—'}',
                                    style: AppTypography.mono(fontSize: 12.5),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    fila.litros.toStringAsFixed(0),
                                    style: AppTypography.mono(fontSize: 12.5),
                                  ),
                                ),
                                DataCell(_CeldaRendimiento(fila: fila)),
                                DataCell(
                                  Text(
                                    fila.ticketPendiente
                                        ? 'pend.'
                                        : formatoMoneda.format(
                                            fila.precioPorLitro,
                                          ),
                                    style: AppTypography.mono(
                                      fontSize: 12.5,
                                      color: fila.ticketPendiente
                                          ? AppColors.warning
                                          : AppColors.navy,
                                    ),
                                  ),
                                ),
                                DataCell(Text(fila.tipoCombustible.etiqueta)),
                                DataCell(
                                  Text(
                                    formatoMoneda.format(fila.importe),
                                    style: AppTypography.mono(fontSize: 12.5),
                                  ),
                                ),
                                DataCell(
                                  InkWell(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.miniCard,
                                    ),
                                    onTap: () => mostrarFotoTicket(
                                      context,
                                      fotoUrl: fila.fotoTicketUrl,
                                      etiqueta:
                                          'Ticket · ${fila.responsable} · ${formatoFecha.format(fila.fecha)}',
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                        horizontal: 4,
                                      ),
                                      child: Icon(
                                        fila.ticketPendiente
                                            ? Icons.access_time_rounded
                                            : Icons.image_search_rounded,
                                        size: 18,
                                        color: fila.ticketPendiente
                                            ? AppColors.warning
                                            : AppColors.secondary,
                                      ),
                                    ),
                                  ),
                                ),
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
                const Text(
                  'TOTALES',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '${totalLitros.toStringAsFixed(0)} L',
                  style: AppTypography.mono(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 24),
                Text(
                  formatoMoneda.format(totalImporte),
                  style: AppTypography.mono(fontWeight: FontWeight.w600),
                ),
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
          const Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: AppColors.error,
          ),
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
        Text(
          texto,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}
