import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Periodo con el que se filtran tablas/reportes en pantallas web (admin/finanzas).
enum PeriodoFiltro { dia, semana, mes, anio }

extension PeriodoFiltroEtiqueta on PeriodoFiltro {
  String get etiqueta => switch (this) {
        PeriodoFiltro.dia => 'Día',
        PeriodoFiltro.semana => 'Semana',
        PeriodoFiltro.mes => 'Mes',
        PeriodoFiltro.anio => 'Año',
      };
}

/// Segmentador Día/Semana/Mes/Año reutilizable — filtra listas de datos mock por fecha.
class SegmentadorPeriodo extends StatelessWidget {
  const SegmentadorPeriodo({
    super.key,
    required this.seleccionado,
    required this.onChanged,
  });

  final PeriodoFiltro seleccionado;
  final ValueChanged<PeriodoFiltro> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final periodo in PeriodoFiltro.values)
            _Opcion(
              texto: periodo.etiqueta,
              activo: periodo == seleccionado,
              onTap: () => onChanged(periodo),
            ),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.texto, required this.activo, required this.onTap});

  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.input - 2),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.input - 2),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: activo ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Devuelve solo los elementos de [items] cuya fecha (vía [fechaDe]) cae en el mismo
/// periodo que [ahora], según [periodo]. "Ahora" se simula como la fecha más reciente
/// de los datos mock, para que el filtro tenga sentido con fechas fijas.
List<T> filtrarPorPeriodo<T>(
  List<T> items,
  DateTime Function(T) fechaDe,
  PeriodoFiltro periodo,
  DateTime ahora,
) {
  bool mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime inicioSemana(DateTime d) {
    final soloFecha = DateTime(d.year, d.month, d.day);
    return soloFecha.subtract(Duration(days: soloFecha.weekday - 1));
  }

  bool mismaSemana(DateTime a, DateTime b) => inicioSemana(a) == inicioSemana(b);

  bool mismoMes(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  bool mismoAnio(DateTime a, DateTime b) => a.year == b.year;

  return items.where((item) {
    final fecha = fechaDe(item);
    return switch (periodo) {
      PeriodoFiltro.dia => mismoDia(fecha, ahora),
      PeriodoFiltro.semana => mismaSemana(fecha, ahora),
      PeriodoFiltro.mes => mismoMes(fecha, ahora),
      PeriodoFiltro.anio => mismoAnio(fecha, ahora),
    };
  }).toList();
}
