/// Fila de `fondo_semanal` (tabla real capturada por finanzas) — expone el
/// presupuesto/fondo de la semana, incluida la semana abierta actual (no solo
/// el histórico de semanas cerradas que cubre `vista_resumen_financiero_semanal`).
class FondoSemanal {
  const FondoSemanal({
    required this.id,
    this.obraId,
    required this.numeroSemana,
    required this.periodoInicio,
    required this.periodoFin,
    required this.montoSolicitado,
    required this.montoDepositado,
    required this.saldoAFavorAnterior,
    required this.consumo,
    required this.saldoAFavor,
    required this.estatus,
  });

  final String id;
  final String? obraId;
  final int numeroSemana;
  final DateTime periodoInicio;
  final DateTime periodoFin;
  final double montoSolicitado;
  final double montoDepositado;
  final double saldoAFavorAnterior;

  /// Consumo real de la semana (suma de `cargas.monto_total` de la obra).
  final double consumo;
  final double saldoAFavor;

  /// "solicitado" / "pagado".
  final String estatus;

  factory FondoSemanal.fromJson(Map<String, dynamic> json) => FondoSemanal(
        id: json['id'] as String,
        obraId: json['obra_id'] as String?,
        numeroSemana: json['numero_semana'] as int,
        periodoInicio: DateTime.parse(json['periodo_inicio'] as String),
        periodoFin: DateTime.parse(json['periodo_fin'] as String),
        montoSolicitado: (json['monto_solicitado'] as num).toDouble(),
        montoDepositado: (json['monto_depositado'] as num).toDouble(),
        saldoAFavorAnterior: (json['saldo_a_favor_anterior'] as num).toDouble(),
        consumo: (json['consumo'] as num).toDouble(),
        saldoAFavor: (json['saldo_a_favor'] as num).toDouble(),
        estatus: json['estatus'] as String,
      );
}
