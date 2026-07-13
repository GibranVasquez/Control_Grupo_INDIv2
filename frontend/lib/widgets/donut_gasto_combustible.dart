import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Orden e hue fijos por tipo de combustible — identidad, no ranking: nunca
/// se reordena ni se recicla aunque cambie el filtro (ver anti-patrones de
/// la guía de visualización: "el color sigue a la entidad, nunca a su rango").
const _colorPorCombustible = {
  TipoCombustible.magna: AppColors.primary,
  TipoCombustible.premium: AppColors.success,
  TipoCombustible.diesel: AppColors.warning,
};

/// Donut de gasto ($) por tipo de combustible — separado de la gráfica de
/// tendencia a propósito (ver GraficaGastos): mezclar proporción y tendencia
/// en un solo gráfico confunde más de lo que aclara.
class DonutGastoCombustible extends StatelessWidget {
  const DonutGastoCombustible({super.key, required this.cargas});

  final List<VistaConcentradoCargas> cargas;

  @override
  Widget build(BuildContext context) {
    final totalesPorTipo = <TipoCombustible, double>{};
    for (final carga in cargas) {
      totalesPorTipo.update(
        carga.tipoCombustible,
        (v) => v + carga.importe,
        ifAbsent: () => carga.importe,
      );
    }
    final totalGeneral = totalesPorTipo.values.fold<double>(0, (a, b) => a + b);
    final formatoMoneda = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 0,
    );

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
          const Text(
            'Gasto por tipo de combustible',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 16),
          if (totalGeneral <= 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'Sin gasto registrado en este periodo.',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 38,
                          sections: [
                            for (final tipo in TipoCombustible.values)
                              if ((totalesPorTipo[tipo] ?? 0) > 0)
                                PieChartSectionData(
                                  value: totalesPorTipo[tipo],
                                  color: _colorPorCombustible[tipo],
                                  radius: 26,
                                  showTitle: false,
                                ),
                          ],
                        ),
                      ),
                      Text(
                        formatoMoneda.format(totalGeneral),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.navy,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final tipo in TipoCombustible.values)
                        if ((totalesPorTipo[tipo] ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _colorPorCombustible[tipo],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tipo.etiqueta,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(((totalesPorTipo[tipo] ?? 0) / totalGeneral) * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatoMoneda.format(totalesPorTipo[tipo]),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
