import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

/// Granularidad de la gráfica de gastos — independiente del filtro de ventana
/// (Día/Semana/Mes/Año) que ya trae el segmentador: aquí siempre se agrupan
/// TODAS las cargas disponibles en cubetas de tiempo, para ver la tendencia.
enum GranularidadGasto { dia, semana, anio }

extension on GranularidadGasto {
  String get etiqueta => switch (this) {
    GranularidadGasto.dia => 'Por día',
    GranularidadGasto.semana => 'Por semana',
    GranularidadGasto.anio => 'Por mes (año)',
  };
}

class _Cubeta {
  _Cubeta(this.inicio, this.fin);

  final DateTime inicio;
  final DateTime fin;
  double total = 0;
  int cargas = 0;

  /// Horas exactas de cada carga en esta cubeta — para el detalle "con hora"
  /// que pide el control (ej. al pasar el mouse sobre la barra de un día).
  final List<DateTime> horasExactas = [];

  void agregar(double importe, DateTime fecha) {
    total += importe;
    cargas++;
    horasExactas.add(fecha);
  }
}

/// Gráfica de barras de gasto (importe) agrupado por día, semana o mes-del-año,
/// con fecha y hora exacta de cada carga disponible al pasar el cursor sobre
/// cada barra — para llevar control fino del gasto de combustible en el tiempo.
class GraficaGastos extends StatefulWidget {
  const GraficaGastos({
    super.key,
    required this.fechas,
    required this.importes,
  });

  /// Debe tener la misma longitud que [importes]; fechas[i] es el momento
  /// exacto (fecha + hora) de la carga cuyo importe es importes[i].
  final List<DateTime> fechas;
  final List<double> importes;

  @override
  State<GraficaGastos> createState() => _GraficaGastosState();
}

class _GraficaGastosState extends State<GraficaGastos> {
  GranularidadGasto _granularidad = GranularidadGasto.dia;

  List<_Cubeta> _construirCubetas() {
    if (widget.fechas.isEmpty) return [];
    final ahora = widget.fechas.reduce((a, b) => a.isAfter(b) ? a : b);

    DateTime inicioCubeta(DateTime f) => switch (_granularidad) {
      GranularidadGasto.dia => DateTime(f.year, f.month, f.day),
      GranularidadGasto.semana => () {
        final soloFecha = DateTime(f.year, f.month, f.day);
        return soloFecha.subtract(Duration(days: soloFecha.weekday - 1));
      }(),
      GranularidadGasto.anio => DateTime(f.year, f.month),
    };

    // Ventana de cubetas a mostrar: últimos 14 días / 8 semanas / 12 meses del
    // año más reciente — suficiente para ver tendencia sin saturar el eje X.
    final cantidad = switch (_granularidad) {
      GranularidadGasto.dia => 14,
      GranularidadGasto.semana => 8,
      GranularidadGasto.anio => 12,
    };
    Duration paso(int i) => switch (_granularidad) {
      GranularidadGasto.dia => Duration(days: i),
      GranularidadGasto.semana => Duration(days: i * 7),
      GranularidadGasto.anio => Duration.zero,
    };

    final inicioVentana = inicioCubeta(ahora);
    final cubetasPorInicio = <DateTime, _Cubeta>{};
    for (var i = cantidad - 1; i >= 0; i--) {
      final inicio = _granularidad == GranularidadGasto.anio
          ? DateTime(inicioVentana.year, inicioVentana.month - i)
          : inicioVentana.subtract(paso(i));
      final fin = switch (_granularidad) {
        GranularidadGasto.dia => inicio.add(const Duration(days: 1)),
        GranularidadGasto.semana => inicio.add(const Duration(days: 7)),
        GranularidadGasto.anio => DateTime(inicio.year, inicio.month + 1),
      };
      cubetasPorInicio[inicio] = _Cubeta(inicio, fin);
    }

    for (var i = 0; i < widget.fechas.length; i++) {
      final inicio = inicioCubeta(widget.fechas[i]);
      final cubeta = cubetasPorInicio[inicio];
      cubeta?.agregar(widget.importes[i], widget.fechas[i]);
    }

    final cubetas = cubetasPorInicio.values.toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
    return cubetas;
  }

  String _etiquetaEje(DateTime d) => switch (_granularidad) {
    GranularidadGasto.dia => DateFormat('d MMM', 'es_MX').format(d),
    GranularidadGasto.semana => DateFormat('d MMM', 'es_MX').format(d),
    GranularidadGasto.anio => DateFormat('MMM', 'es_MX').format(d),
  };

  @override
  Widget build(BuildContext context) {
    final cubetas = _construirCubetas();
    final formatoMoneda = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 0,
    );
    final formatoFechaHora = DateFormat("d MMM y, HH:mm", 'es_MX');
    final maxY = cubetas.isEmpty
        ? 100.0
        : (cubetas.map((c) => c.total).reduce((a, b) => a > b ? a : b)) * 1.2;

    return Container(
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
              const Expanded(
                child: Text(
                  'Gasto de combustible en el tiempo',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.navy,
                  ),
                ),
              ),
              DropdownButton<GranularidadGasto>(
                value: _granularidad,
                underline: const SizedBox.shrink(),
                items: [
                  for (final g in GranularidadGasto.values)
                    DropdownMenuItem(value: g, child: Text(g.etiqueta)),
                ],
                onChanged: (g) =>
                    setState(() => _granularidad = g ?? _granularidad),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Pasa el cursor sobre una barra para ver la fecha y hora exacta de cada carga.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (cubetas.isEmpty || cubetas.every((c) => c.cargas == 0))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Sin gasto registrado en este rango todavía.',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.borderSubtle,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        getTitlesWidget: (value, meta) => Text(
                          formatoMoneda.format(value),
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= cubetas.length)
                            return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _etiquetaEje(cubetas[i].inicio),
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 10.5,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.navy,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final cubeta = cubetas[group.x.toInt()];
                        final horas = cubeta.horasExactas.toList()..sort();
                        final detalle = horas
                            .take(4)
                            .map(formatoFechaHora.format)
                            .join('\n');
                        final extra = horas.length > 4
                            ? '\n… y ${horas.length - 4} más'
                            : '';
                        return BarTooltipItem(
                          '${formatoMoneda.format(cubeta.total)} · ${cubeta.cargas} carga${cubeta.cargas == 1 ? '' : 's'}\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                          children: [
                            TextSpan(
                              text: cubeta.cargas == 0
                                  ? 'Sin cargas'
                                  : detalle + extra,
                              style: AppTypography.mono(
                                color: Colors.white70,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < cubetas.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: cubetas[i].total,
                            color: cubetas[i].cargas == 0
                                ? AppColors.borderStrong
                                : AppColors.primary,
                            width: _granularidad == GranularidadGasto.dia
                                ? 14
                                : 22,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
