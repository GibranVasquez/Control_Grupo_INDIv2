/// Fila de la vista `vista_resumen_financiero_semanal` — reemplaza la hoja de control financiero.
/// Columnas y nombres exactos pendientes de confirmar con backend en Fase 0.
class VistaResumenFinancieroSemanal {
  const VistaResumenFinancieroSemanal({
    required this.semanaId,
    required this.numeroSemana,
    required this.periodoInicio,
    required this.periodoFin,
    required this.solicitado,
    required this.consumo,
    required this.deposito,
    required this.saldoAFavor,
    required this.estatus,
  });

  final String semanaId;
  final int numeroSemana;
  final DateTime periodoInicio;
  final DateTime periodoFin;
  final double solicitado;
  final double consumo;
  final double deposito;
  final double saldoAFavor;

  /// "pagado" / "solicitado".
  final String estatus;

  factory VistaResumenFinancieroSemanal.fromJson(Map<String, dynamic> json) =>
      VistaResumenFinancieroSemanal(
        semanaId: json['semana_id'] as String,
        numeroSemana: json['numero_semana'] as int,
        periodoInicio: DateTime.parse(json['periodo_inicio'] as String),
        periodoFin: DateTime.parse(json['periodo_fin'] as String),
        solicitado: (json['solicitado'] as num).toDouble(),
        consumo: (json['consumo'] as num).toDouble(),
        deposito: (json['deposito'] as num).toDouble(),
        saldoAFavor: (json['saldo_a_favor'] as num).toDouble(),
        estatus: json['estatus'] as String,
      );
}
